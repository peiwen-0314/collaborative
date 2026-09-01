import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/api_config.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import '../services/destination_photo_service.dart';
import '../services/transit_hop_finder.dart';
import '../widgets/location_row.dart';
import '../widgets/trip_widgets.dart';
import 'navigation_page.dart';

/// The itinerary's timeline rows, plus a synthetic "Change here" row
/// wherever two real transit legs sit back-to-back with nothing between
/// them. HERE usually returns a walking/interchange leg for a transfer
/// (see HereTransitService), but not always - e.g. a same-stop or
/// same-platform change - so without this the itinerary can jump
/// straight from one vehicle to the next with no visible "you change
/// here" marker at all, even though [RideOption.transferCount] (see its
/// doc comment) still correctly counts it as a transfer.
List<Widget> _timelineItems(
  List<TripLeg> legs, {
  required LocationPoint from,
  bool editing = false,
  Set<int> editableLegIndices = const {},
  void Function(int legIndex)? onLegTap,
}) {
  final items = <Widget>[];

  bool isRealTransitLeg(TripLeg leg) =>
      !leg.isTransfer && leg.mode != TransportMode.walk;

  // Same area lookup HereTransitService/MockTransportRepository already
  // do once per search (see estimateFareRm/isPenangArea's doc comments)
  // - computed once here rather than per leg since it only depends on
  // where the whole trip starts.
  final searchIsPenang = isPenangArea(from);

  // A real per-leg fare (not just the trip's total Est. Cost) - shares
  // legFareRm with withLegReplaced's total recompute (see its doc
  // comment) so a trip's header total and its own rows can never
  // disagree. Null for a walk/transfer leg (free, not its own fare) or
  // one with no known real distance (the offline/mock generator - see
  // TripLeg.distanceKm's doc comment), which simply show no fare chip.
  String? fareLabel(TripLeg leg) {
    final fare = legFareRm(leg, isPenangArea: searchIsPenang);
    return fare == null ? null : 'RM ${fare.toStringAsFixed(2)}';
  }

  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    // editableLegIndices already only contains legs HERE gave more than
    // one real alternative for (see TripDetailsPage._editableLegIndices)
    // - a leg with nothing else to swap to isn't worth showing as
    // tappable at all, even in Edit mode.
    final editable = editing && editableLegIndices.contains(i);
    items.add(
      TimelineItem(
        start: formatClockTime(leg.start),
        end: formatClockTime(leg.end),
        title: leg.title,
        subtitle: leg.subtitle,
        duration: formatDuration(leg.duration),
        fareLabel: fareLabel(leg),
        mode: leg.isTransfer ? null : leg.mode,
        transfer: leg.isTransfer,
        onTap: editable ? () => onLegTap?.call(i) : null,
      ),
    );

    final next = i + 1 < legs.length ? legs[i + 1] : null;
    if (next != null && isRealTransitLeg(leg) && isRealTransitLeg(next)) {
      items.add(
        TimelineItem(
          start: formatClockTime(leg.end),
          end: formatClockTime(leg.end),
          title: '${leg.title} -> ${next.title}',
          subtitle: '\u21c4  Transfer',
          duration: formatDuration(Duration.zero),
          transfer: true,
        ),
      );
    }
  }

  return items;
}

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
    this.allowTimeChange = false,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  /// True only when this page was opened from the Saved List - a saved
  /// trip (e.g. "Home -> Office") is usually reused on different days at
  /// different times, so unlike a trip just opened from a fresh search
  /// (whose time was already chosen a moment ago on the search page),
  /// its departure time is worth letting the person change again right
  /// here rather than being frozen at whatever it was first saved with.
  /// See SavedListPage._openTrip/_changeDepartureTime.
  final bool allowTimeChange;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final TransportController _controller = TransportController();

  bool _saved = false;
  bool _editing = false;

  // True while a re-plan for a newly-picked departure time is in
  // flight (see _changeDepartureTime) - only ever reachable when
  // widget.allowTimeChange is true.
  bool _changingTime = false;

  // True once at least one leg has actually been swapped during the
  // current Edit session - drives the "you changed this trip, save it?"
  // prompt on Done (see _edit). Reset back to false once that prompt has
  // been answered either way, so leaving Edit mode without touching
  // anything never asks, and answering once doesn't ask again for the
  // same set of changes.
  bool _hasPendingEdits = false;

  // Real HERE alternatives for each editable leg of the CURRENT _option,
  // keyed by that leg's index - fetched once up front when Edit mode is
  // entered (and again after each edit, since an edit shifts every leg
  // index after it) rather than only when a leg is actually tapped, so
  // whether a leg is even worth tapping is already known before the
  // pencil icon is decided (see _editableLegIndices/_timelineItems
  // below): a leg with 0 or only 1 real alternative has nothing to
  // choose between, so it shouldn't look tappable at all.
  Map<int, List<RideOption>> _legAlternatives = {};
  bool _loadingLegAlternatives = false;

  Set<int> get _editableLegIndices => {
    for (final entry in _legAlternatives.entries)
      if (entry.value.length > 1) entry.key,
  };

  // The itinerary actually shown/saved/navigated from - starts as
  // whatever was passed in, but can diverge from widget.option once a
  // leg is edited (see _editLeg/withLegReplaced). Kept as page-level
  // state (not re-derived from widget.option each build) so an edit
  // survives rebuilds and is what Save/Start Navigation act on.
  late RideOption _option = widget.option;

  // What _option/_saved were right before the current Edit session
  // started - see _edit's "Revert" path, which puts these back if the
  // person declines to save whatever they changed. Only meaningful
  // while _editing is true (or while the save/revert prompt is up).
  RideOption? _optionBeforeEditing;
  bool _savedBeforeEditing = false;

  SavedTrip get _asSavedTrip => SavedTrip(
    from: widget.from,
    to: widget.to,
    option: _option,
    savedAt: DateTime.now(),
  );

  /// A classic mobile "toast" - a small dark rounded pill sized to its
  /// own text (not a bar stretching the full screen width), centred low
  /// on the screen, that just fades away on its own after [duration] -
  /// the same shape/behaviour as a native Android Toast or WeChat's own
  /// message pill, which is what was actually asked for after the
  /// previous white card version still didn't read as "how a normal
  /// app shows this". Every SnackBar this page shows goes through this
  /// one helper so they all look and behave the same way.
  void _showSnack(
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: 36),
          // Center + no explicit width on the pill itself, so it wraps
          // exactly around whatever the message actually is instead of
          // stretching to fill the screen like a normal SnackBar does -
          // the ConstrainedBox just stops a genuinely long message from
          // running off the sides, wrapping to a second line instead.
          content: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.82),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isError
                      ? const Color(0xE6B3261E)
                      : const Color(0xE6323232),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    // Checked up front (not only once Edit is tapped) so the Edit
    // button itself can start out disabled - with a small spinner
    // instead of the pencil - for a trip where nothing turns out to be
    // real-alternative-editable at all (e.g. offline/mock data, or a
    // route HERE has no other real way to cover any leg of), rather
    // than only discovering that after already entering Edit mode - see
    // _editableLegIndices/_DetailsActions.canEdit.
    _loadingLegAlternatives = true;
    _loadLegAlternatives();
  }

  Future<void> _loadSavedState() async {
    // Best-effort only: if this throws (no signed-in user yet, a
    // Firestore rule not deployed, no network...) the heart icon just
    // stays in its default "not saved" state instead of crashing the
    // page - _toggleSave below is what actually surfaces a save failure
    // to the person, since that's the action they're deliberately
    // taking.
    try {
      final saved = await _controller.isTripSaved(_asSavedTrip.id);
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (_) {
      // Ignored - see comment above.
    }
  }

  /// Moves this exact trip to a newly-picked departure time - only
  /// reachable when widget.allowTimeChange is true (see
  /// SavedListPage._openTrip). Tries to keep BOTH things the person
  /// wants at once: the exact same route (same bus/train, same
  /// transfers, same fare) AND real, schedule-confirmed times for the
  /// new date - not a fresh search that could come back with a
  /// genuinely different combination of real alternatives (that's what
  /// the per-leg Edit feature is for, for someone who explicitly wants
  /// to swap something), and not an unverified guess either.
  ///
  /// Does this leg-by-leg rather than as one whole-trip search: an
  /// earlier version searched fresh for the whole trip and looked for a
  /// candidate riding the exact same combination of real services, but
  /// HERE's own search only ever returns ITS best-ranked alternative(s)
  /// for a from/to/time query - it doesn't answer "does this SPECIFIC
  /// multi-transfer combination still exist", so a real 3-transfer
  /// route (e.g. bus 104 -> bus 102 -> bus 303) routinely failed to
  /// reappear as a whole even when every individual bus in it was still
  /// genuinely running, which showed up as "could not confirm" far more
  /// than it should have. Checking one real leg at a time against
  /// [TransportController.findLegAlternatives] for that exact leg's own
  /// start/end points - the same real per-leg lookup the pencil-icon
  /// Edit feature already uses - confirms each bus/train individually
  /// instead of guessing at the whole trip in one shot.
  ///
  /// Every real (non-walk) leg must confirm for the result to count as
  /// schedule-confirmed; the moment any one of them can't be found
  /// running near its own newly-shifted time, this gives up on
  /// verification entirely and falls back to [withTimeShifted]'s plain,
  /// unverified shift for the WHOLE trip - a partially-confirmed trip
  /// (some legs real, one leg guessed) would be more confusing than
  /// useful. Either way the person is told which one happened (see the
  /// SnackBar below), never silently.
  Future<void> _changeDepartureTime() async {
    final current = _option.departTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    // Backing out of the time step (tapping outside the dialog, the
    // back button, "Cancel") used to discard the date just picked too -
    // the whole change silently did nothing, which read as "I picked a
    // new date and nothing happened". Falling back to the trip's
    // original time-of-day instead means a date-only change (pick a
    // date, then back out of the time step because the time is already
    // right) actually takes effect.
    final pickedTime = time ?? TimeOfDay.fromDateTime(current);

    final newDepartAt = DateTime(
      date.year,
      date.month,
      date.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final delta = newDepartAt.difference(current);
    if (delta == Duration.zero) return;

    setState(() => _changingTime = true);
    var updated = withTimeShifted(_option, delta);
    var confirmed = false;
    try {
      final legs = _option.legs;
      final realLegIndices = [
        for (var i = 0; i < legs.length; i++)
          if (realLegLabel(legs[i]) != null) i,
      ];

      if (realLegIndices.isNotEmpty) {
        final replacements = <int, RideOption>{};
        // How far this leg's OWN real confirmed timing has drifted from
        // the naive uniform shift so far - starts at the plain picked
        // delta (nothing confirmed yet), then gets corrected leg by leg
        // as each one's real schedule turns out a little different from
        // that guess, so a later leg is probed near where the trip
        // would ACTUALLY be by then, not blindly at delta - see
        // withLegsReplaced's own doc comment for the same idea applied
        // to the rebuilt itinerary.
        var carryDelta = delta;
        var allConfirmed = true;

        for (final legIndex in realLegIndices) {
          final leg = legs[legIndex];
          final wantedLabel = realLegLabel(leg);
          final legFrom = leg.startPoint;
          final legTo = leg.endPoint;
          if (wantedLabel == null || legFrom == null || legTo == null) {
            allConfirmed = false;
            break;
          }

          final baseProbeAt = leg.start.add(carryDelta);
          RideOption? matched;
          // Same "don't insist on the exact minute" reasoning the
          // original whole-trip probing used - a real bus a little
          // later than the naive guess is still a genuine,
          // schedule-confirmed answer for this leg.
          for (final probeAt in [
            baseProbeAt,
            baseProbeAt.add(const Duration(minutes: 30)),
            baseProbeAt.add(const Duration(hours: 1)),
            baseProbeAt.add(const Duration(hours: 2)),
          ]) {
            final candidates = await _controller.findLegAlternatives(
              from: legFrom,
              to: legTo,
              departAt: probeAt,
            );
            for (final candidate in candidates) {
              final labels = hopRouteLabels(candidate);
              if (labels.length != 1 || labels.first != wantedLabel) {
                continue;
              }
              // The one leg inside `candidate` that actually carries
              // `wantedLabel` - usually the whole thing for a direct
              // hop, but it can be sandwiched between short
              // access/egress walk legs HERE added to reach the stop.
              TripLeg? realLeg;
              for (final candidateLeg in candidate.legs) {
                if (realLegLabel(candidateLeg) == wantedLabel) {
                  realLeg = candidateLeg;
                  break;
                }
              }
              if (realLeg == null) continue;
              // Riding the same numbered service isn't enough on its
              // own - HERE's "alternatives" for one leg's start/end
              // aren't all clustered near the requested time (a service
              // that only runs a couple of times a day can still show
              // up as "an alternative", just many hours away), and
              // accepting one of those would "confirm" a route that
              // isn't actually the one running anywhere near the picked
              // time - exactly the impossible-looking jump from, say,
              // 7am to 11pm this check used to let through.
              //
              // This has to be a one-sided window, not just "close to
              // probeAt": [probeAt] IS this leg's own real, just-
              // confirmed arrival point from the PREVIOUS leg (see
              // carryDelta below - a genuinely sequential "search from
              // where the last leg actually leaves you off" chain, the
              // same way a person checks a real timetable leg by leg).
              // A same-numbered service that departs even a minute
              // BEFORE that is a bus this itinerary could never actually
              // catch - accepting it produced exactly the
              // impossible-to-board connection (a leg "departing" a few
              // minutes before the previous one even arrives) that
              // showed up after the first drift check went in. Only a
              // small grace period allows for a same-minute boarding;
              // arriving late is fine up to a real, reasonable wait.
              if (realLeg.start.isBefore(
                probeAt.subtract(const Duration(minutes: 1)),
              )) {
                continue;
              }
              if (realLeg.start.isAfter(
                probeAt.add(const Duration(minutes: 60)),
              )) {
                continue;
              }
              matched = candidate;
              break;
            }
            if (matched != null) break;
          }

          if (matched == null) {
            allConfirmed = false;
            break;
          }
          replacements[legIndex] = matched;
          final matchedLegs = matched.legs;
          if (matchedLegs.isNotEmpty) {
            carryDelta = matchedLegs.last.end.difference(leg.end);
          }
        }

        if (allConfirmed && replacements.isNotEmpty) {
          updated = withLegsReplaced(
            _option,
            replacements: replacements,
            from: widget.from,
            initialDelta: delta,
          );
          confirmed = true;
        }
      }
    } catch (error) {
      // A failed re-verification shouldn't leave the trip stuck on the
      // old date - `updated` already holds the plain shifted fallback
      // from above, so this just means staying with that.
      debugPrint('[TripDetailsPage] schedule re-check failed: $error');
    }
    if (!mounted) return;

    setState(() {
      _option = updated;
      // A different departure time means a different RideOption.id (see
      // SavedTrip.id), so whatever saved status applied before no
      // longer means anything for it - same convention as _editLeg.
      _saved = false;
      _legAlternatives = {};
      _loadingLegAlternatives = true;
      _changingTime = false;
    });
    _showSnack(
      confirmed
          ? 'Updated to depart ${formatFriendlyDateTime(updated.departTime)} - confirmed against the real schedule.'
          : 'Updated to depart ${formatFriendlyDateTime(updated.departTime)} - could not confirm this route runs then, so the time is estimated.',
      duration: const Duration(seconds: 4),
    );
    // Which legs have a real alternative worth showing as editable can
    // itself depend on the time (a leg's own real alternatives are
    // searched around its own start time) - re-checked for the new
    // times, same as after any other edit (see _editLeg).
    await _loadLegAlternatives();
  }

  Future<void> _toggleSave() async {
    try {
      final nowSaved = await _controller.toggleSavedTrip(_asSavedTrip);
      if (!mounted) return;
      setState(() => _saved = nowSaved);
      _showSnack(
        nowSaved ? 'Trip saved' : 'Removed from saved list',
        duration: const Duration(seconds: 1),
      );
    } catch (error) {
      // Surface the real reason (e.g. "permission-denied" from a missing
      // Firestore rule, or no signed-in Firebase user) instead of the
      // save silently doing nothing - that's what made "why isn't this
      // showing up in Firebase" hard to diagnose before.
      if (!mounted) return;
      _showSnack(
        'Could not save trip: $error',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _edit() async {
    if (!_editing) {
      // Snapshot what the trip looked like right before this Edit
      // session, so declining to save on the way out (see below) has
      // something real to revert to instead of just discarding the
      // in-memory edits and leaving whatever the last change happened
      // to leave on screen.
      _optionBeforeEditing = _option;
      _savedBeforeEditing = _saved;
      setState(() {
        _editing = true;
        _legAlternatives = {};
        _loadingLegAlternatives = true;
      });
      _showSnack(
        'Checking real alternatives for this trip\'s segments...',
        duration: const Duration(seconds: 3),
      );
      await _loadLegAlternatives();
      return;
    }

    // Leaving Edit mode (Done was pressed). Only ask about saving if
    // something in this session actually changed - toggling Edit on and
    // off without touching any leg has nothing worth prompting about.
    if (_hasPendingEdits) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save changes?'),
          content: const Text(
            "You've changed part of this trip. Save it with these "
            'changes, or go back to how it was before?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Revert'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (shouldSave == true) {
        await _saveEditedOption();
      } else {
        // "Revert" (or the dialog was dismissed without an explicit
        // choice) - a person who didn't say "save" almost certainly
        // doesn't want to keep looking at an itinerary that only exists
        // in memory, so this puts the trip back exactly how it was
        // before this Edit session started rather than leaving the
        // edited-but-unsaved version on screen.
        setState(() {
          _option = _optionBeforeEditing!;
          _saved = _savedBeforeEditing;
        });
      }
      _hasPendingEdits = false;
    }
    if (!mounted) return;
    setState(() {
      _editing = false;
      _legAlternatives = {};
      _loadingLegAlternatives = false;
    });
  }

  /// Fetches real HERE alternatives for every editable leg of the
  /// CURRENT [_option] in parallel, then reveals the pencil icon only on
  /// legs that actually got back more than one real alternative (see
  /// _editableLegIndices) - a leg HERE has no other real way to cover
  /// isn't worth pretending is editable.
  Future<void> _loadLegAlternatives() async {
    final legs = _option.legs;
    final indices = <int>[];
    final futures = <Future<List<RideOption>>>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.isTransfer || leg.startPoint == null || leg.endPoint == null) {
        continue;
      }
      indices.add(i);
      futures.add(
        _controller.findLegAlternatives(
          from: leg.startPoint!,
          to: leg.endPoint!,
          departAt: leg.start,
        ),
      );
    }

    final resolved = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _legAlternatives = {
        for (var i = 0; i < indices.length; i++) indices[i]: resolved[i],
      };
      _loadingLegAlternatives = false;
    });
  }

  /// Unconditionally saves the current (possibly edited) [_option] - see
  /// TransportController.saveTrip's doc comment for why this is a plain
  /// save rather than routing through the same toggle _toggleSave uses.
  Future<void> _saveEditedOption() async {
    try {
      await _controller.saveTrip(_asSavedTrip);
      if (!mounted) return;
      setState(() => _saved = true);
      _showSnack('Trip saved', duration: const Duration(seconds: 1));
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'Could not save trip: $error',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Opens the "choose a real alternative for this segment" sheet for
  /// legs[legIndex], using the alternatives already fetched by
  /// _loadLegAlternatives (this is only ever reachable through a pencil
  /// icon, which only shows once that leg is known to have more than
  /// one - see _editableLegIndices - so there's no need to hit HERE
  /// again here). If the person actually picked one, rather than
  /// dismissing the sheet, rebuilds _option with that leg replaced (see
  /// withLegReplaced's doc comment for how the rest of the itinerary
  /// reacts to a faster/slower replacement), then refreshes every leg's
  /// alternatives again - an edit shifts every leg index after it, and
  /// can introduce entirely new legs, so the previous fetch no longer
  /// lines up with the new itinerary.
  Future<void> _editLeg(int legIndex) async {
    final leg = _option.legs[legIndex];
    final alternatives = _legAlternatives[legIndex];
    if (alternatives == null || alternatives.length < 2) return;

    final replacement = await showModalBottomSheet<RideOption>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _LegAlternativesSheet(
        currentLegTitle: leg.title,
        alternatives: alternatives,
      ),
    );
    if (replacement == null || !mounted) return;

    setState(() {
      _option = withLegReplaced(
        _option,
        legIndex: legIndex,
        replacement: replacement,
        from: widget.from,
      );
      _hasPendingEdits = true;
      // The edited option is a different SavedTrip.id (it embeds
      // RideOption.id - see withLegReplaced/SavedTrip.id), so whatever
      // saved status applied to the trip before this edit no longer
      // means anything for it - the heart icon should read "not saved"
      // until this specific edited version is actually saved.
      _saved = false;
      _legAlternatives = {};
      _loadingLegAlternatives = true;
    });
    await _loadLegAlternatives();
  }

  void _startNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          from: widget.from,
          to: widget.to,
          option: _option,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _DetailsBackground(destination: widget.to),
          _TripContent(
            from: widget.from,
            to: widget.to,
            option: _option,
            editing: _editing,
            editableLegIndices: _editableLegIndices,
            loadingAlternatives: _loadingLegAlternatives,
            onLegTap: _editLeg,
            allowTimeChange: widget.allowTimeChange,
            changingTime: _changingTime,
            onChangeTime: _changeDepartureTime,
            // Was a Positioned bar permanently pinned over the timeline
            // (see _DetailsActions' old doc comment) - now just the last
            // section of the same scrollable card, after the itinerary,
            // so it scrolls away with the rest of the trip detail
            // instead of always covering part of the screen.
            saved: _saved,
            checkingEditability: !_editing && _loadingLegAlternatives,
            canEdit: _editableLegIndices.isNotEmpty,
            onSave: _toggleSave,
            onEdit: _edit,
            onStartNavigation: _startNavigation,
          ),
          _BackButton(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _DetailsBackground extends StatelessWidget {
  const _DetailsBackground({required this.destination});

  final LocationPoint destination;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Column(
        children: [
          SizedBox(
            height: 230,
            width: double.infinity,
            child: _DestinationImage(destination: destination),
          ),
          const Expanded(child: ColoredBox(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Second-tier fallback for [_DestinationImage]: a small static map
/// centred on the destination, for when there's no real photo of it (an
/// ordinary bus stop or street address rather than a landmark). Reuses
/// the HERE key the transportation module already has for routing (see
/// ApiConfig) instead of adding a third image API/key just for this.
///
/// Falls back further, to the app's original fixed header image,
/// whenever there is no HERE key yet (this module also works fully
/// offline - see ApiConfig's doc comment) or the map request fails for
/// any reason (no network, HERE outage, etc.) - a broken image is worse
/// than a generic one.
class _DestinationMap extends StatelessWidget {
  const _DestinationMap({required this.destination});

  final LocationPoint destination;

  static const _fallback = Image(
    image: AssetImage(AppAssets.temple),
    fit: BoxFit.cover,
  );

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasHereApiKey) return _fallback;

    // HERE Map Image API v3: auto-fits/zooms to the pinned point with
    // some padding, so there is no zoom level to guess at for a
    // destination that could be anywhere from a village to a city.
    final url =
        'https://image.maps.hereapi.com/mia/v3/base/mc/overlay:padding=48'
        '/750x460/png'
        '?apiKey=${ApiConfig.hereApiKey}'
        '&overlay=point:${destination.lat},${destination.lng}'
        '&style=lite.day';

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: AppColors.lightGreen,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        );
      },
    );
  }
}

/// The trip details header image: a real photo of the destination
/// (e.g. searching "Ayer Itam" pulls a real photo of Ayer Itam) fetched
/// from Wikipedia by place name - see DestinationPhotoService for why
/// Wikipedia specifically (no API key needed). Named stops/addresses
/// with no Wikipedia article of their own fall back to _DestinationMap
/// (a map pin at the real coordinates), which itself falls back to a
/// fixed generic image if even that isn't available - see that class's
/// doc comment.
class _DestinationImage extends StatefulWidget {
  const _DestinationImage({required this.destination});

  final LocationPoint destination;

  @override
  State<_DestinationImage> createState() => _DestinationImageState();
}

class _DestinationImageState extends State<_DestinationImage> {
  late final Future<String?> _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = DestinationPhotoService.fetchPhotoUrl(widget.destination.name);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _photoUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: AppColors.lightGreen,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.green),
            ),
          );
        }

        final photoUrl = snapshot.data;
        if (photoUrl == null) {
          return _DestinationMap(destination: widget.destination);
        }

        return Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _DestinationMap(destination: widget.destination),
        );
      },
    );
  }
}

class _TripContent extends StatelessWidget {
  const _TripContent({
    required this.from,
    required this.to,
    required this.option,
    this.editing = false,
    this.editableLegIndices = const {},
    this.loadingAlternatives = false,
    this.onLegTap,
    this.allowTimeChange = false,
    this.changingTime = false,
    this.onChangeTime,
    required this.saved,
    required this.checkingEditability,
    required this.canEdit,
    required this.onSave,
    required this.onEdit,
    required this.onStartNavigation,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;
  final bool editing;
  final Set<int> editableLegIndices;
  final bool loadingAlternatives;
  final void Function(int legIndex)? onLegTap;

  /// See TripDetailsPage.allowTimeChange's doc comment.
  final bool allowTimeChange;
  final bool changingTime;
  final VoidCallback? onChangeTime;

  // Passed straight through to _DetailsActions below, now that it's
  // rendered as the last section of this same scrollable card instead
  // of a separate always-visible overlay - see that class's own doc
  // comments for what each of these means.
  final bool saved;
  final bool checkingEditability;
  final bool canEdit;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    // Roughly one phone screen's worth, minus this scroll area's own
    // top/bottom padding (the gap _DetailsBackground/_BackButton show
    // through above, and the breathing room below) - so a short trip
    // (few legs, no transfers) still fills about a full screen instead
    // of the white card stopping right after a couple of rows with the
    // 3 action buttons floating awkwardly close underneath. A longer
    // itinerary is unaffected - it simply grows past this and scrolls,
    // same as before.
    final screenHeight = MediaQuery.of(context).size.height;
    final cardMinHeight = (screenHeight - 170 - 24).clamp(0.0, double.infinity);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 170, 14, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cardMinHeight),
          // Lets the Column below resolve to a real, bounded height (its
          // own natural content height, or [cardMinHeight] when that's
          // taller - see BoxConstraints.tighten's own clamping) instead
          // of the unbounded height SingleChildScrollView normally gives
          // its child, which a bounded-height trick like Spacer/Expanded
          // (used just below to push the buttons to the bottom of a
          // short trip's card) requires to mean anything.
          child: IntrinsicHeight(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: (allowTimeChange && !changingTime)
                      ? onChangeTime
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Departs ${formatFriendlyDateTime(option.departTime)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (allowTimeChange)
                        changingTime
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: AppColors.green,
                              ),
                    ],
                  ),
                ),
              ),
              LocationRow(label: 'From', value: from.name, color: AppColors.green),
              const Divider(height: 18),
              LocationRow(
                label: 'To',
                value: to.name,
                color: AppColors.orange,
                outlined: true,
              ),
              const SizedBox(height: 10),
              TripSummary(option: option, from: from),
              const SizedBox(height: 22),
              if (editing && loadingAlternatives)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ..._timelineItems(
                option.legs,
                from: from,
                editing: editing,
                editableLegIndices: editableLegIndices,
                onLegTap: onLegTap,
              ),
              DestinationRow(
                arrivalTimeLabel: formatClockTime(option.arriveTime),
                destinationLabel: to.name,
              ),
              const SizedBox(height: 22),
              // Eats whatever's left of [cardMinHeight] on a short trip
              // (0 on a trip already taller than that, per Spacer's own
              // flex-vs-intrinsic behaviour) so these buttons land right
              // at the bottom of the card either way, never floating
              // right under a couple of timeline rows.
              const Spacer(),
              _DetailsActions(
                saved: saved,
                editing: editing,
                checkingEditability: checkingEditability,
                canEdit: canEdit,
                busy: changingTime,
                onSave: onSave,
                onEdit: onEdit,
                onStartNavigation: onStartNavigation,
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: Colors.white70),
          onPressed: onPressed,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DetailsActions extends StatelessWidget {
  const _DetailsActions({
    required this.saved,
    required this.editing,
    required this.checkingEditability,
    required this.canEdit,
    required this.busy,
    required this.onSave,
    required this.onEdit,
    required this.onStartNavigation,
  });

  final bool saved;
  final bool editing;

  /// True while a re-plan for a newly-picked departure time is in
  /// flight (see TripDetailsPage._changeDepartureTime) - disables every
  /// action below so nothing races the in-progress swap of [_option].
  final bool busy;

  /// True only before Edit mode has ever been entered, while
  /// TripDetailsPage is still asking HERE whether any leg of this trip
  /// has a real alternative at all - shows a small spinner on the Edit
  /// button instead of the pencil so a temporarily-disabled button (still
  /// checking) doesn't look identical to a permanently-disabled one
  /// (checked, and there's genuinely nothing to edit).
  final bool checkingEditability;

  /// Whether the Edit button itself should be pressable. False once
  /// TripDetailsPage has confirmed none of this trip's legs have more
  /// than one real alternative to swap to - entering Edit mode would
  /// just show a timeline with no pencils on it at all, so there's
  /// nothing to edit. Ignored (Edit always pressable, as "Done") while
  /// already [editing] - leaving Edit mode must always be possible.
  final bool canEdit;

  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    // Plain inline section now (see _TripContent, which renders this
    // right after the itinerary/DestinationRow) rather than a Positioned
    // bar permanently pinned over the trip timeline - these buttons
    // scroll away with the rest of the trip detail like everything else
    // on the page instead of always covering part of the screen.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 43,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: (editing || busy) ? null : onStartNavigation,
            icon: const Icon(Icons.navigation_outlined, size: 19),
            label: const Text(
              'Start Navigation',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !busy && (editing || canEdit) ? onEdit : null,
                icon: editing
                    ? const Icon(Icons.check, size: 16)
                    : checkingEditability
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  editing ? 'Done' : 'Edit',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (editing || busy) ? null : onSave,
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                ),
                label: Text(
                  saved ? 'Saved' : 'Save',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A short label for one alternative in the picker below, e.g.
/// "Bus (104)" or "Walk only" - reuses [hopRouteLabels]'s real-number
/// extraction (already used for grouping "Bus (104 + 11)"-style titles
/// elsewhere) so a multi-leg alternative (e.g. a short walk then a bus)
/// still reads as one concise line instead of every leg spelled out.
String _alternativeSummary(RideOption alt) {
  final realLegs = alt.legs.where(
    (leg) => !leg.isTransfer && leg.mode != TransportMode.walk,
  );
  if (realLegs.isEmpty) return 'Walk only';
  final modeLabel = realLegs.first.mode.label;
  final labels = hopRouteLabels(alt);
  return labels.isEmpty ? modeLabel : '$modeLabel (${labels.join(' + ')})';
}

/// Bottom sheet opened by tapping a real, editable leg in Edit mode -
/// lists every real alternative HERE has for that exact segment (see
/// TransportController.findLegAlternatives) and returns whichever one
/// the person taps via Navigator.pop(context, picked); popped with no
/// value (back gesture, tapping outside, or the close button) if they
/// change their mind, which TripDetailsPage._editLeg already treats as
/// "no change".
class _LegAlternativesSheet extends StatelessWidget {
  const _LegAlternativesSheet({
    required this.currentLegTitle,
    required this.alternatives,
  });

  final String currentLegTitle;

  // Already resolved by the time this sheet opens - TripDetailsPage
  // only ever opens it from a pencil icon, which only shows once
  // _loadLegAlternatives has confirmed this leg has more than one real
  // alternative (see _editableLegIndices), so there's nothing left to
  // await here.
  final List<RideOption> alternatives;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replace "$currentLegTitle" with...',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: alternatives.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = alternatives[index];
                  final realLeg = option.legs.firstWhere(
                    (leg) => !leg.isTransfer && leg.mode != TransportMode.walk,
                    orElse: () => option.legs.first,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: transportModeGlyph(realLeg.mode, size: 18),
                    ),
                    title: Text(
                      _alternativeSummary(option),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${formatClockTime(option.departTime)} - '
                      '${formatClockTime(option.arriveTime)}  '
                      '(${formatDuration(option.totalDuration)})',
                    ),
                    trailing: Text(
                      'RM ${option.estCostRm.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
