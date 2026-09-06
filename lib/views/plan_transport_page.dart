import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/saved_trip_plan.dart';
import '../services/location_service.dart';
import '../widgets/location_row.dart';
import '../widgets/ride_card.dart';
import 'trip_details_page.dart';

/// Shows a real, bookable transportation route for every attraction in
/// [plan], grouped by day - "plan transportation for the whole trip",
/// not just a single destination. See
/// TransportController.planTransportationForPlan for how each leg is
/// computed (day by day, working backwards from each attraction's own
/// planned arrival deadline). Reached by tapping a plan on
/// TripPlansPage.
///
/// If this plan already has a transportation plan saved (see [_save] -
/// TransportController.getSavedTransportPlan/saveTransportPlan), that
/// saved plan is shown directly - no new searches - and TripPlansPage's
/// list badges it as planned (see TripPlansPage's own doc comment).
/// Otherwise, once the person confirms they actually want this (see
/// [_confirmAndPlan] - a real GPS fix and a batch of real searches
/// shouldn't fire just from opening this page), a fresh plan is
/// computed and saved to Firebase automatically - no manual Save step.
/// Any attraction that couldn't be planned shows its own orange
/// warning box with just an inline Retry button (see
/// _UnplannedLegTile) - changing the starting point is only offered
/// once a leg actually HAS a route, right there in its own detail page
/// (see [_openLeg]'s isPlanLeg/onChangeFrom on TripDetailsPage).
///
/// The AppBar's Re-plan action (see [_confirmReplan]) is a DIFFERENT
/// thing from a per-leg Retry: a saved plan is shown as-is with no new
/// searches (directly above), so it can go stale in ways a per-leg
/// Retry can't fix - e.g. this app's own transport-timing logic
/// changing after the plan was already saved, or a since-updated real
/// bus/train schedule - without anything about any individual leg
/// having failed. Re-plan redoes every leg from a fresh GPS fix, same
/// as the very first "Plan Transportation" confirmation, and overwrites
/// the saved plan with the result (see [saveTransportPlan]'s own doc
/// comment: "re-plan is just calling this again with a freshly computed
/// list") - confirmed first since it's a real batch of live searches,
/// not a free action.
class PlanTransportPage extends StatefulWidget {
  const PlanTransportPage({super.key, required this.plan});

  final SavedTripPlan plan;

  @override
  State<PlanTransportPage> createState() => _PlanTransportPageState();
}

class _PlanTransportPageState extends State<PlanTransportPage> {
  final TransportController _controller = TransportController();
  final LocationService _locationService = const LocationService();

  List<PlannedPlanLeg>? _legs;
  String? _error;

  /// True when [_legs] is exactly what's already saved for this plan
  /// (TransportController.getSavedTransportPlan) - false while a fresh
  /// plan is still being computed (see [_computeFreshPlan]), which
  /// saves it to Firebase automatically as soon as it's ready (no
  /// manual Save action - see the AppBar's own doc comment).
  bool _isSaved = false;
  bool _saving = false;

  /// True once the person has actually agreed to run the (real,
  /// multi-search) planning computation - see [_buildBody]'s
  /// confirmation prompt. Nothing is searched just from opening this
  /// page when there's no saved plan yet; a real GPS fix and a handful
  /// of live route searches shouldn't fire without the person having
  /// asked for it first. Irrelevant (never checked) once a saved plan
  /// was found - that's just shown, no confirmation needed to VIEW it.
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _plan();
  }

  /// Loads whatever's already saved for this plan first - see this
  /// class's own doc comment. If nothing was saved yet, this does NOT
  /// start computing one - it leaves [_legs]/[_error] both null with
  /// [_confirmed] still false, which [_buildBody] reads as "ask first"
  /// (see [_confirmAndPlan]).
  Future<void> _plan() async {
    setState(() {
      _legs = null;
      _error = null;
    });
    try {
      final saved = await _controller.getSavedTransportPlan(widget.plan.id);
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _legs = saved;
          _isSaved = true;
        });
      }
    } catch (error) {
      debugPrint('[PlanTransportPage] saved-plan lookup failed: $error');
      // Falls through to the "ask first" prompt, same as finding
      // nothing saved - the person can still choose to plan fresh.
    }
  }

  /// The person said yes to the confirmation prompt - now it's fine to
  /// actually detect their location and run real searches.
  Future<void> _confirmAndPlan() async {
    setState(() => _confirmed = true);
    await _computeFreshPlan();
  }

  /// The AppBar's Re-plan action - see this class's own doc comment for
  /// why this is different from a per-leg Retry. Asks first (same
  /// reasoning as [_confirmAndPlan]: a real GPS fix plus a full batch
  /// of live searches, not something to fire by accident from a single
  /// tap), then just reuses [_computeFreshPlan] - it already resets
  /// [_legs], detects location fresh, and saves the result over
  /// whatever was there before.
  Future<void> _confirmReplan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Re-plan this trip?'),
        content: const Text(
          'This re-detects your current location and searches real '
          "routes for every attraction again, replacing this plan's "
          'saved transportation with the fresh result.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Re-plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirmed = true);
    await _computeFreshPlan();
  }

  /// The error state's Retry button - re-runs whichever step actually
  /// failed instead of always re-checking for a saved plan: once the
  /// person has confirmed (see [_confirmAndPlan]), an error can only
  /// have come from the real computation itself, so retrying means
  /// running that again, not silently landing back on the "ask first"
  /// prompt with nothing happening.
  void _retry() {
    if (_confirmed) {
      _computeFreshPlan();
    } else {
      _plan();
    }
  }

  Future<void> _computeFreshPlan() async {
    setState(() {
      _legs = null;
      _error = null;
      _isSaved = false;
    });
    try {
      // Every day of the plan starts fresh from wherever the person
      // actually is right now (see planTransportationForPlan's doc
      // comment on the day-trip assumption) - a real GPS fix, not a
      // guess, since it becomes the literal search origin for the
      // whole plan.
      final locationResult = await _locationService.detectCurrentLocation();
      final startingFrom = locationResult.point;
      if (startingFrom == null) {
        if (!mounted) return;
        setState(
          () => _error =
              "Could not detect your current location - it's needed as "
              'the starting point for each day of this plan.',
        );
        return;
      }

      final legs = await _controller.planTransportationForPlan(
        widget.plan,
        startingFrom: startingFrom,
      );
      if (!mounted) return;
      setState(() => _legs = legs);
      // Save automatically as soon as a fresh plan is computed - the
      // person already agreed to plan transportation for this trip (see
      // _confirmAndPlan), so there's no separate manual Save step (see
      // the AppBar's own doc comment) - if this particular save attempt
      // fails, _save's own error handling surfaces that directly.
      await _save();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    final legs = _legs;
    if (legs == null || legs.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _controller.saveTransportPlan(widget.plan.id, legs);
      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transportation plan saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this plan: $error')),
      );
    }
  }

  void _openLeg(PlannedPlanLeg leg) {
    final option = leg.option;
    final to = leg.to;
    if (option == null || to == null) return;
    // -1 should never actually happen (leg came from _legs in the first
    // place - see _buildDayList), but isPlanLeg/onChangeFrom simply
    // don't get wired up rather than crashing if it somehow did.
    final index = _legs?.indexOf(leg) ?? -1;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: leg.from,
          to: to,
          option: option,
          allowTimeChange: true,
          isPlanLeg: index != -1,
          onChangeFrom: index == -1
              ? null
              : (query) => _searchAndRetry(index, query),
        ),
      ),
    );
  }

  /// Indices into [_legs] currently being retried - lets that one tile
  /// show a spinner and disable its own buttons without blocking the
  /// rest of the list (a person can retry more than one broken leg).
  final Set<int> _retrying = {};

  /// Looks up the original SavedTripPlanAttraction (address/area -
  /// needed to re-geocode) behind [leg] - PlannedPlanLeg itself only
  /// keeps the attraction's name, not its full saved-plan record (see
  /// PlannedPlanLeg's doc comment on why it's deliberately a thin,
  /// independent shape), so a retry looks it back up from [widget.plan]
  /// by day + name.
  SavedTripPlanAttraction? _attractionFor(PlannedPlanLeg leg) {
    for (final candidate in widget.plan.attractionsForDay(leg.day)) {
      if (candidate.name == leg.attractionName) return candidate;
    }
    return null;
  }

  /// Retries planning [_legs][index] from [from] (see
  /// TransportController.retryPlanLeg) and, on success or failure alike,
  /// replaces just that one entry in place and re-saves the whole plan -
  /// consistent with every other change to this plan being saved to
  /// Firebase automatically, not just the very first computation.
  Future<PlannedPlanLeg?> _applyRetriedLeg(
    int index,
    LocationPoint from,
  ) async {
    final legs = _legs;
    if (legs == null || index < 0 || index >= legs.length) return null;
    final leg = legs[index];
    final attraction = _attractionFor(leg);
    if (attraction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find this attraction in the plan anymore.'),
        ),
      );
      return null;
    }

    setState(() => _retrying.add(index));
    try {
      final updated = await _controller.retryPlanLeg(
        from: from,
        attraction: attraction,
        day: leg.day,
        visitStart: leg.visitStart,
        visitEnd: leg.visitEnd,
      );
      if (!mounted) return updated;
      setState(() {
        final newLegs = List<PlannedPlanLeg>.from(_legs!);
        newLegs[index] = updated;
        _legs = newLegs;
        _retrying.remove(index);
      });
      await _save();
      return updated;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _retrying.remove(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $error')),
      );
      return null;
    }
  }

  /// Plain retry - same starting point as before, in case the earlier
  /// failure was just a transient search/network hiccup.
  Future<void> _retryLeg(int index) {
    final legs = _legs;
    if (legs == null || index < 0 || index >= legs.length) {
      return Future<void>.value();
    }
    return _applyRetriedLeg(index, legs[index].from);
  }

  /// Re-geocodes [query] and retries planning [_legs][index] from the
  /// resulting point (see [_applyRetriedLeg]) - the "change starting
  /// point" action behind a plan-generated TripDetailsPage's own
  /// editable From row (see [_openLeg]). Returns null only when [query]
  /// itself couldn't be resolved to a real place at all; a query that
  /// resolves but still can't reach the attraction still returns the
  /// resulting (still-unplanned) [PlannedPlanLeg], same as
  /// [_applyRetriedLeg] always does, so the caller can show why.
  Future<PlannedPlanLeg?> _searchAndRetry(int index, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final point = await _locationService.searchPlace(trimmed);
    if (!mounted || point == null) return null;
    return _applyRetriedLeg(index, point);
  }


  @override
  Widget build(BuildContext context) {
    final state = widget.plan.selectedState?.trim();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          state != null && state.isNotEmpty ? state : 'Trip Plan',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        // No manual Save action here on purpose - a computed plan is
        // already saved to Firebase automatically (see
        // _computeFreshPlan/_applyRetriedLeg's own doc comments), so
        // there's nothing left for the person to trigger by hand.
        actions: [
          if (_legs != null)
            IconButton(
              onPressed: _confirmReplan,
              tooltip: 'Re-plan this trip',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.orange,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final legs = _legs;
    if (legs == null && !_confirmed) {
      // Nothing saved yet, and the person hasn't agreed to a fresh
      // search-heavy computation - ask first instead of silently
      // detecting their location and firing off a batch of real
      // searches the moment this page opens.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_transit_outlined,
                color: AppColors.green,
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                "This trip doesn't have a transportation plan yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'Plan real routes for every attraction, day by day? This '
                "uses your current location and runs a few real searches.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirmAndPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                ),
                child: const Text('Plan Transportation'),
              ),
            ],
          ),
        ),
      );
    }

    if (legs == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.green),
              SizedBox(height: 14),
              Text(
                'Planning real routes for every day of this trip...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    if (legs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This plan has no attractions to route to yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final days = <int>{for (final leg in legs) leg.day}.toList()..sort();

    return Column(
      children: [
        if (_isSaved)
          Container(
            width: double.infinity,
            color: AppColors.paleGreen,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.check_circle, size: 15, color: AppColors.green),
                SizedBox(width: 6),
                Text(
                  'This transportation plan is saved.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.green),
                ),
              ],
            ),
          ),
        Expanded(child: _buildDayList(legs, days)),
      ],
    );
  }

  Widget _buildDayList(List<PlannedPlanLeg> legs, List<int> days) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 22),
      itemBuilder: (context, index) {
        final day = days[index];
        final dayLegs = legs.where((leg) => leg.day == day).toList();
        final dayDate = DateTime(
          widget.plan.startDate.year,
          widget.plan.startDate.month,
          widget.plan.startDate.day + (day - 1),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 7),
              child: Text(
                'Day $day · ${_dayDateLabel(dayDate)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final leg in dayLegs) ...[
              _PlannedLegTile(
                leg: leg,
                onTap: () => _openLeg(leg),
                retrying: _retrying.contains(legs.indexOf(leg)),
                onRetry: () => _retryLeg(legs.indexOf(leg)),
              ),
              if (leg != dayLegs.last) const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

/// e.g. "Today", "Tomorrow", "24 Aug" - the day-label half of
/// formatFriendlyDateTime, without the clock time (each attraction
/// already shows its own real visit time via _PlannedLegTile).
String _dayDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final dayDiff = target.difference(today).inDays;
  if (dayDiff == 0) return 'Today';
  if (dayDiff == 1) return 'Tomorrow';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

/// One attraction's slot within a day: which attraction it is, the real
/// ride to get there (or [_UnplannedLegTile] when one couldn't be
/// found), and the real visit window worked out from that attraction's
/// own saved opening/closing time + recommended duration - see
/// TransportController.planTransportationForPlan and
/// PlannedPlanLeg.visitStart/visitEnd's doc comments.
class _PlannedLegTile extends StatelessWidget {
  const _PlannedLegTile({
    required this.leg,
    required this.onTap,
    required this.retrying,
    required this.onRetry,
  });

  final PlannedPlanLeg leg;
  final VoidCallback onTap;

  /// See PlanTransportPage._retrying's doc comment.
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final option = leg.option;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: AppColors.green,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  leg.attractionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (option != null)
          RideCard(option: option, onTap: onTap, showElapsedFromSearch: false)
        else
          _UnplannedLegTile(
            name: leg.attractionName,
            // Genuinely couldn't tell where this attraction even IS
            // (leg.to null) vs. a real place was found but no real
            // transport reaches it - two different problems, so
            // _UnplannedLegTile says which one this actually is instead
            // of one generic message for both.
            locationUnresolved: leg.to == null,
            retrying: retrying,
            onRetry: onRetry,
          ),
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 6),
          child: Text(
            'Visit ${formatClockTime(leg.visitStart)} - '
            '${formatClockTime(leg.visitEnd)} '
            '(${formatDuration(leg.visitEnd.difference(leg.visitStart))})',
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
        ),
        // The orange "couldn't meet this deadline" chip that used to
        // render here (from leg.warning) was removed at the person's
        // own request - leg.warning itself is untouched (still
        // computed by TransportController.planTransportationForPlan/
        // _planLegToMeetDeadline exactly as before, and still there
        // for any future caller that wants it - see e.g.
        // TripDetailsPage's own _changeDepartureTime, which still
        // surfaces it as a transient snackbar on failure), this just
        // stops THIS tile from displaying it permanently under every
        // affected leg.
      ],
    );
  }
}

/// Shown in place of a RideCard for a [PlannedPlanLeg] whose address
/// couldn't be geocoded or whose search came back with no real route -
/// see TransportController.planTransportationForPlan's doc comment for
/// why this never happens silently. [locationUnresolved] tells these
/// two failures apart, since they mean different things to the person
/// looking at this: not knowing where "$name" even IS (its saved
/// address is missing/wrong - see
/// TransportController._geocodeSavedPlanAttraction's doc comment on how
/// hard this already tries before giving up) is a different problem
/// than knowing exactly where it is but finding no real bus/train/etc.
/// that reaches it in time.
class _UnplannedLegTile extends StatelessWidget {
  const _UnplannedLegTile({
    required this.name,
    required this.locationUnresolved,
    required this.retrying,
    required this.onRetry,
  });

  final String name;
  final bool locationUnresolved;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        border: Border.all(color: AppColors.orange),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationUnresolved
                      ? 'We couldn\'t find where "$name" is - its saved '
                            'address may be missing or incorrect.'
                      : 'Could not find a real route to "$name" - try '
                            'again later.',
                  style: const TextStyle(fontSize: 11, color: AppColors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (retrying)
            const Padding(
              padding: EdgeInsets.only(left: 26),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.orange,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

