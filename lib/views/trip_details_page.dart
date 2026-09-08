import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/api_config.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/transport_data.dart';
import '../models/delay_estimate.dart';
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

  final searchIsPenang = isPenangArea(from);

  String? fareLabel(TripLeg leg) {
    final fare = legFareRm(leg, isPenangArea: searchIsPenang);
    return fare == null ? null : 'RM ${fare.toStringAsFixed(2)}';
  }

  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
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

class _AutoDetectChoice {
  const _AutoDetectChoice();
}

const _autoDetectChoice = _AutoDetectChoice();

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
    this.allowTimeChange = false,
    this.isPlanLeg = false,
    this.onChangeFrom,
    this.onAutoDetectFrom,
    this.onSaveEditedLeg,
    this.isSavedTrip = false,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  final bool allowTimeChange;

  final bool isSavedTrip;

  final bool isPlanLeg;

  final Future<PlannedPlanLeg?> Function(String query)? onChangeFrom;

  final Future<PlannedPlanLeg?> Function()? onAutoDetectFrom;

  final Future<void> Function(RideOption editedOption)? onSaveEditedLeg;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final TransportController _controller = TransportController();

  bool _saved = false;
  bool _editing = false;

  bool _changingTime = false;

  bool _hasPendingEdits = false;

  Map<int, List<RideOption>> _legAlternatives = {};
  bool _loadingLegAlternatives = false;

  Set<int> get _editableLegIndices => {
    for (final entry in _legAlternatives.entries)
      if (entry.value.length > 1) entry.key,
  };

  late RideOption _option = widget.option;

  late LocationPoint _from = widget.from;

  // True while a change-starting-point search/retry is in flight - see
  // _changeFrom. Only ever reachable when widget.isPlanLeg is true.
  bool _changingFrom = false;

  RideOption? _optionBeforeEditing;
  bool _savedBeforeEditing = false;

  SavedTrip get _asSavedTrip => SavedTrip(
    from: _from,
    to: widget.to,
    option: _option,
    savedAt: DateTime.now(),
  );

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
    if (widget.isPlanLeg) {
      _saved = true;
    } else {
      _loadSavedState();
    }
    _loadingLegAlternatives = true;
    _loadLegAlternatives();
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = await _controller.isTripSaved(_asSavedTrip.id);
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (_) {
      // Ignored - see comment above.
    }
  }

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
    int? failedLegIndex;
    String? failedWantedLabel;
    RideOption? failedAlternative;
    try {
      final legs = _option.legs;
      final realLegIndices = [
        for (var i = 0; i < legs.length; i++)
          if (realLegLabel(legs[i]) != null) i,
      ];

      if (realLegIndices.isEmpty) {
        confirmed = true;
      } else {
        final replacements = <int, RideOption>{};
        var carryDelta = delta;
        var allConfirmed = true;

        for (final legIndex in realLegIndices) {
          final leg = legs[legIndex];
          final wantedLabel = realLegLabel(leg);
          final legFrom = leg.startPoint;
          final legTo = leg.endPoint;
          if (wantedLabel == null || legFrom == null || legTo == null) {
            allConfirmed = false;
            failedLegIndex = legIndex;
            failedWantedLabel = wantedLabel;
            break;
          }

          final baseProbeAt = leg.start.add(carryDelta);
          RideOption? matched;
          RideOption? nearMiss;
          Duration? nearMissGap;
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
              TripLeg? realLeg;
              for (final candidateLeg in candidate.legs) {
                if (realLegLabel(candidateLeg) != null) {
                  realLeg = candidateLeg;
                  break;
                }
              }
              if (realLeg == null) continue;
              if (realLeg.start.isBefore(
                probeAt.subtract(const Duration(minutes: 1)),
              )) {
                continue;
              }

              final label = realLegLabel(realLeg);
              final isExactService = label == wantedLabel;
              if (isExactService &&
                  !realLeg.start.isAfter(
                    probeAt.add(const Duration(minutes: 60)),
                  )) {
                matched = candidate;
                break;
              }

              final gap = realLeg.start.difference(baseProbeAt).abs();
              if (nearMissGap == null || gap < nearMissGap) {
                nearMiss = candidate;
                nearMissGap = gap;
              }
            }
            if (matched != null) break;
          }

          if (matched == null) {
            allConfirmed = false;
            failedLegIndex = legIndex;
            failedWantedLabel = wantedLabel;
            failedAlternative = nearMiss;
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
            from: _from,
            initialDelta: delta,
          );
          confirmed = true;
        }
      }
    } catch (error) {
      debugPrint('[TripDetailsPage] schedule re-check failed: $error');
    }
    if (!mounted) return;

    if (confirmed) {
      setState(() {
        _option = updated;
        _saved = false;
        _legAlternatives = {};
        _loadingLegAlternatives = true;
        _changingTime = false;
      });
      _showSnack(
        'Updated to depart ${formatFriendlyDateTime(updated.departTime)} - confirmed against the real schedule.',
        duration: const Duration(seconds: 4),
      );
      await _loadLegAlternatives();
      return;
    }

    setState(() => _changingTime = false);
    await _resolveUnconfirmedTime(
      estimatedFallback: updated,
      newDepartAt: newDepartAt,
      delta: delta,
      failedLegIndex: failedLegIndex,
      failedWantedLabel: failedWantedLabel,
      failedAlternative: failedAlternative,
    );
  }

  Future<void> _resolveUnconfirmedTime({
    required RideOption estimatedFallback,
    required DateTime newDepartAt,
    required Duration delta,
    int? failedLegIndex,
    String? failedWantedLabel,
    RideOption? failedAlternative,
  }) async {
    final choice = await showModalBottomSheet<_ScheduleFallbackChoice>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ScheduleFallbackSheet(
        wantedLabel: failedWantedLabel,
        alternative: failedAlternative,
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _ScheduleFallbackChoice.useAlternative:
        if (failedLegIndex == null || failedAlternative == null) return;
        final replaced = withLegsReplaced(
          _option,
          replacements: {failedLegIndex: failedAlternative},
          from: _from,
          initialDelta: delta,
        );
        setState(() {
          _option = replaced;
          _saved = false;
          _legAlternatives = {};
          _loadingLegAlternatives = true;
        });
        _showSnack(
          'Switched to a real alternative - now departing '
          '${formatFriendlyDateTime(replaced.departTime)}, confirmed '
          'against the real schedule.',
          duration: const Duration(seconds: 4),
        );
        await _loadLegAlternatives();
        break;
      case _ScheduleFallbackChoice.regenerate:
        await _regenerateForNewTime(newDepartAt);
        break;
      case _ScheduleFallbackChoice.useEstimate:
        setState(() {
          _option = estimatedFallback;
          _saved = false;
          _legAlternatives = {};
          _loadingLegAlternatives = true;
        });
        _showSnack(
          'Updated to depart '
          '${formatFriendlyDateTime(estimatedFallback.departTime)} - '
          'could not confirm this route runs then, so the time is '
          'estimated.',
          duration: const Duration(seconds: 4),
        );
        await _loadLegAlternatives();
        break;
    }
  }

  Future<void> _regenerateForNewTime(DateTime newDepartAt) async {
    setState(() => _changingTime = true);
    try {
      final result = await _controller.searchRides(
        from: _from,
        to: widget.to,
        departAt: newDepartAt,
      );
      if (!mounted) return;
      if (result.options.isEmpty) {
        _showSnack(
          'Could not find any real route for that date - try a '
          'different time.',
          isError: true,
          duration: const Duration(seconds: 4),
        );
        return;
      }
      setState(() {
        _option = result.options.first;
        _saved = false;
        _legAlternatives = {};
        _loadingLegAlternatives = true;
      });
      _showSnack(
        'Found a new real route departing '
        '${formatFriendlyDateTime(_option.departTime)}.',
        duration: const Duration(seconds: 4),
      );
      await _loadLegAlternatives();
    } catch (error) {
      debugPrint('[TripDetailsPage] regenerate for new time failed: $error');
      if (!mounted) return;
      _showSnack(
        'Could not search for a new route right now.',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _changingTime = false);
    }
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
      if (!mounted) return;
      _showSnack(
        'Could not save trip: $error',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _saveToPlan() async {
    final onSaveEditedLeg = widget.onSaveEditedLeg;
    if (onSaveEditedLeg == null) return;
    try {
      await onSaveEditedLeg(_option);
      if (!mounted) return;
      setState(() => _saved = true);
      _showSnack('Saved to plan', duration: const Duration(seconds: 1));
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'Could not save to plan: $error',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _edit() async {
    if (!_editing) {
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
        if (widget.isPlanLeg && widget.onSaveEditedLeg != null) {
          await _saveToPlan();
        } else {
          await _saveEditedOption();
        }
      } else {
        setState(() {
          _option = _optionBeforeEditing!;
          _saved = _savedBeforeEditing;
        });
      }
      _hasPendingEdits = false;
    }
    if (!mounted) return;
    // Keep _legAlternatives around (don't reset to {}) - clearing it here
    // made _editableLegIndices empty again right after finishing an edit,
    // which disabled the Edit button until the page was fully reopened.
    setState(() {
      _editing = false;
      _loadingLegAlternatives = false;
    });
  }

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

  Future<Map<int, RideOption>> _reconfirmDownstreamLegs({
    required List<TripLeg> legs,
    required int fromIndex,
    required Duration startDelta,
  }) async {
    final replacements = <int, RideOption>{};
    var carryDelta = startDelta;

    for (var legIndex = fromIndex; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex];
      final wantedLabel = realLegLabel(leg);
      final legFrom = leg.startPoint;
      final legTo = leg.endPoint;
      if (wantedLabel == null || legFrom == null || legTo == null) continue;

      final baseProbeAt = leg.start.add(carryDelta);
      RideOption? matched;
      RideOption? nearMiss;
      Duration? nearMissGap;
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
          TripLeg? realLeg;
          for (final candidateLeg in candidate.legs) {
            if (realLegLabel(candidateLeg) != null) {
              realLeg = candidateLeg;
              break;
            }
          }
          if (realLeg == null) continue;
          if (realLeg.start.isBefore(
            probeAt.subtract(const Duration(minutes: 1)),
          )) {
            continue;
          }
          final label = realLegLabel(realLeg);
          final isExactService = label == wantedLabel;
          if (isExactService &&
              !realLeg.start.isAfter(
                probeAt.add(const Duration(minutes: 60)),
              )) {
            matched = candidate;
            break;
          }
          final gap = realLeg.start.difference(baseProbeAt).abs();
          if (nearMissGap == null || gap < nearMissGap) {
            nearMiss = candidate;
            nearMissGap = gap;
          }
        }
        if (matched != null) break;
      }

      if (matched != null) {
        replacements[legIndex] = matched;
        final matchedLegs = matched.legs;
        if (matchedLegs.isNotEmpty) {
          carryDelta = matchedLegs.last.end.difference(leg.end);
        }
        continue;
      }

      final offer = nearMiss;
      if (offer == null) continue;

      if (!mounted) continue;
      final wantsSwitch = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _DownstreamLegSwitchSheet(
          wantedLabel: wantedLabel,
          alternative: offer,
        ),
      );
      if (wantsSwitch == true) {
        replacements[legIndex] = offer;
        final matchedLegs = offer.legs;
        if (matchedLegs.isNotEmpty) {
          carryDelta = matchedLegs.last.end.difference(leg.end);
        }
      }
    }

    return replacements;
  }

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

    setState(() => _loadingLegAlternatives = true);

    final legsBeforeEdit = _option.legs;
    final replacementLegs = replacement.legs;
    final directDelta = replacementLegs.isEmpty
        ? Duration.zero
        : replacementLegs.last.end.difference(leg.end);

    final downstreamReplacements = await _reconfirmDownstreamLegs(
      legs: legsBeforeEdit,
      fromIndex: legIndex + 1,
      startDelta: directDelta,
    );
    if (!mounted) return;

    setState(() {
      final rebuilt = withLegsReplaced(
        _option,
        replacements: {legIndex: replacement, ...downstreamReplacements},
        from: _from,
      );
      _option = rebuilt.tags.contains('Edited')
          ? rebuilt
          : RideOption(
              id: rebuilt.id,
              title: rebuilt.title,
              legs: rebuilt.legs,
              estCostRm: rebuilt.estCostRm,
              co2Kg: rebuilt.co2Kg,
              tags: [...rebuilt.tags, 'Edited'],
              searchDepartAt: rebuilt.searchDepartAt,
              isLiveData: rebuilt.isLiveData,
              path: rebuilt.path,
              delayEstimate: rebuilt.delayEstimate,
            );
      _hasPendingEdits = true;
      _saved = false;
      _legAlternatives = {};
      _loadingLegAlternatives = true;
    });
    await _loadLegAlternatives();
  }

  // Shows this trip's route on the app's own in-app map (no external
  // app) - see RouteMapPage in navigation_page.dart, which was built
  // for exactly this: drawing one RideOption's route between two
  // points.
  Future<void> _startNavigation() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RouteMapPage(from: _from, to: widget.to, option: _option),
      ),
    );
  }

  Future<void> _changeFrom() async {
    final onChangeFrom = widget.onChangeFrom;
    if (onChangeFrom == null || _changingFrom) return;

    final textController = TextEditingController(text: _from.name);
    final onAutoDetectFrom = widget.onAutoDetectFrom;
    final choice = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change starting point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search a place, e.g. Komtar, George Town',
              ),
            ),
            if (onAutoDetectFrom != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _autoDetectChoice),
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Use my current location'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, textController.text),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Search & Retry'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (identical(choice, _autoDetectChoice)) {
      if (onAutoDetectFrom == null) return;
      setState(() => _changingFrom = true);
      final result = await onAutoDetectFrom();
      if (!mounted) return;
      _applyChangeFromOutcome(result);
      return;
    }

    final query = choice is String ? choice : '';
    if (query.trim().isEmpty) return;

    setState(() => _changingFrom = true);
    final result = await onChangeFrom(query);
    if (!mounted) return;
    _applyChangeFromOutcome(result);
  }

  void _applyChangeFromOutcome(PlannedPlanLeg? result) {
    if (result == null) {
      setState(() => _changingFrom = false);
      _showSnack(
        'Could not find that place - try a more specific search.',
        isError: true,
      );
      return;
    }

    final newOption = result.option;
    setState(() {
      _from = result.from;
      if (newOption != null) _option = newOption;
      _changingFrom = false;
      if (newOption != null) _saved = false;
    });

    if (newOption != null) {
      _showSnack('Updated to depart from ${result.from.name}.');
    } else {
      _showSnack(
        result.warning ??
            'Still could not find a real route from there - try another '
                'starting point.',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _DetailsBackground(destination: widget.to),
          _TripContent(
            from: _from,
            to: widget.to,
            option: _option,
            editing: _editing,
            editableLegIndices: _editableLegIndices,
            loadingAlternatives: _loadingLegAlternatives,
            onLegTap: _editLeg,
            allowTimeChange: widget.allowTimeChange,
            isSavedTrip: widget.isSavedTrip,
            changingTime: _changingTime,
            onChangeTime: _changeDepartureTime,
            isPlanLeg: widget.isPlanLeg,
            changingFrom: _changingFrom,
            onChangeFrom: widget.onChangeFrom == null ? null : _changeFrom,
            saved: _saved,
            checkingEditability: !_editing && _loadingLegAlternatives,
            canEdit: _editableLegIndices.isNotEmpty,
            onSave: widget.isPlanLeg ? _saveToPlan : _toggleSave,
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
    this.isSavedTrip = false,
    this.changingTime = false,
    this.onChangeTime,
    this.isPlanLeg = false,
    this.changingFrom = false,
    this.onChangeFrom,
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

  /// See TripDetailsPage.isSavedTrip's doc comment.
  final bool isSavedTrip;
  final bool changingTime;
  final VoidCallback? onChangeTime;

  final bool isPlanLeg;
  final bool changingFrom;
  final VoidCallback? onChangeFrom;

  final bool saved;
  final bool checkingEditability;
  final bool canEdit;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cardMinHeight = (screenHeight - 170 - 24).clamp(0.0, double.infinity);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 170, 14, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cardMinHeight),
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
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Departs ${formatFriendlyDateTime(option.departTime)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isSavedTrip &&
                                option.waitBeforeDeparture >
                                    const Duration(minutes: 15))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  'Wait ${formatDuration(option.waitBeforeDeparture)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
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
              InkWell(
                onTap: (isPlanLeg && !changingFrom) ? onChangeFrom : null,
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      child: LocationRow(
                        label: 'From',
                        value: from.name,
                        color: AppColors.green,
                      ),
                    ),
                    if (isPlanLeg) ...[
                      const SizedBox(width: 6),
                      changingFrom
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: AppColors.green,
                            ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 18),
              LocationRow(
                label: 'To',
                value: to.name,
                color: AppColors.orange,
                outlined: true,
              ),
              const SizedBox(height: 10),
              TripSummary(option: option, from: from),
              if (option.delayEstimate != null) ...[
                const SizedBox(height: 10),
                _DelayEstimateBanner(estimate: option.delayEstimate!),
              ],
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
              const Spacer(),
              _DetailsActions(
                saved: saved,
                editing: editing,
                checkingEditability: checkingEditability,
                canEdit: canEdit,
                busy: changingTime,
                isPlanLeg: isPlanLeg,
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

class _DelayEstimateBanner extends StatelessWidget {
  const _DelayEstimateBanner({required this.estimate});

  final DelayEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        border: Border.all(color: AppColors.orange),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 15,
            color: AppColors.orange,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Delay: ${estimate.rangeLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Delay due to ${estimate.reasonLabel}.',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    required this.isPlanLeg,
    required this.onSave,
    required this.onEdit,
    required this.onStartNavigation,
  });

  final bool saved;
  final bool editing;

  final bool busy;

  final bool checkingEditability;

  final bool canEdit;

  // A plan leg auto-saves through the Edit flow's own "Save changes?"
  // confirmation (see TripDetailsPage._edit/_saveToPlan) - the separate
  // heart/"Save" button below is the general (non-plan) "add to Saved
  // List" affordance, so it's hidden here to avoid looking like this
  // leg has its own separate saved-list entry.
  final bool isPlanLeg;

  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
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
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
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
            if (!isPlanLeg) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (editing || busy) ? null : onSave,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(43),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
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
          ],
        ),
      ],
    );
  }
}

String _alternativeSummary(RideOption alt) {
  final realLegs = alt.legs.where(
    (leg) => !leg.isTransfer && leg.mode != TransportMode.walk,
  );
  if (realLegs.isEmpty) return 'Walk only';
  final modeLabel = realLegs.first.mode.label;
  final labels = hopRouteLabels(alt);
  return labels.isEmpty ? modeLabel : '$modeLabel (${labels.join(' + ')})';
}

class _LegAlternativesSheet extends StatelessWidget {
  const _LegAlternativesSheet({
    required this.currentLegTitle,
    required this.alternatives,
  });

  final String currentLegTitle;

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

enum _ScheduleFallbackChoice { useAlternative, regenerate, useEstimate }

class _ScheduleFallbackSheet extends StatelessWidget {
  const _ScheduleFallbackSheet({this.wantedLabel, this.alternative});

  final String? wantedLabel;
  final RideOption? alternative;

  @override
  Widget build(BuildContext context) {
    final alt = alternative;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wantedLabel == null
                  ? "Couldn't confirm this trip's schedule for that time"
                  : "$wantedLabel doesn't seem to run around that time",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's what's actually available:",
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            if (alt != null) ...[
              _FallbackOptionTile(
                icon: Icons.swap_horiz,
                title: 'Switch to ${_alternativeSummary(alt)}',
                subtitle:
                    'Real departure ${formatClockTime(alt.departTime)} - '
                    'confirmed against the real schedule',
                onTap: () => Navigator.of(
                  context,
                ).pop(_ScheduleFallbackChoice.useAlternative),
              ),
              const SizedBox(height: 10),
            ],
            _FallbackOptionTile(
              icon: Icons.travel_explore,
              title: 'Search a fresh route for this date',
              subtitle: 'May come back with a different real combination',
              onTap: () => Navigator.of(
                context,
              ).pop(_ScheduleFallbackChoice.regenerate),
            ),
            const SizedBox(height: 10),
            _FallbackOptionTile(
              icon: Icons.schedule_outlined,
              title: 'Use the estimated time anyway',
              subtitle: 'Not confirmed against a real schedule',
              onTap: () => Navigator.of(
                context,
              ).pop(_ScheduleFallbackChoice.useEstimate),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackOptionTile extends StatelessWidget {
  const _FallbackOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownstreamLegSwitchSheet extends StatelessWidget {
  const _DownstreamLegSwitchSheet({
    required this.wantedLabel,
    required this.alternative,
  });

  final String wantedLabel;
  final RideOption alternative;

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
              "$wantedLabel doesn't seem to run around the time this "
              'edit leaves it',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'A real alternative is available for this stretch instead:',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            _FallbackOptionTile(
              icon: Icons.swap_horiz,
              title: 'Switch to ${_alternativeSummary(alternative)}',
              subtitle:
                  'Real departure ${formatClockTime(alternative.departTime)} '
                  '- confirmed against the real schedule',
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            _FallbackOptionTile(
              icon: Icons.schedule_outlined,
              title: 'Keep the estimated time',
              subtitle:
                  'Not confirmed against a real schedule for this stretch',
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
