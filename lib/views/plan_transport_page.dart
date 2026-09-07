import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip_plan.dart';
import '../services/location_service.dart';
import '../widgets/location_row.dart';
import '../widgets/ride_card.dart';
import 'trip_details_page.dart';

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

  bool _isSaved = false;
  bool _saving = false;

  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _plan();
  }

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
          onAutoDetectFrom: index == -1
              ? null
              : () => _detectAndRetry(index),
          onSaveEditedLeg: index == -1
              ? null
              : (editedOption) => _saveEditedLeg(index, editedOption),
        ),
      ),
    );
  }

  final Set<int> _retrying = {};

  SavedTripPlanAttraction? _attractionFor(PlannedPlanLeg leg) {
    for (final candidate in widget.plan.attractionsForDay(leg.day)) {
      if (candidate.name == leg.attractionName) return candidate;
    }
    return null;
  }

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

    final earliestDepart = index > 0
        ? legs[index - 1].visitEnd
        : leg.visitStart.subtract(const Duration(hours: 3));

    setState(() => _retrying.add(index));
    try {
      final updated = await _controller.retryPlanLeg(
        from: from,
        attraction: attraction,
        day: leg.day,
        visitStart: leg.visitStart,
        visitEnd: leg.visitEnd,
        earliestDepart: earliestDepart,
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

  Future<void> _saveEditedLeg(int index, RideOption option) async {
    final legs = _legs;
    if (legs == null || index < 0 || index >= legs.length) return;
    setState(() {
      final newLegs = List<PlannedPlanLeg>.from(legs);
      newLegs[index] = newLegs[index].withOption(option);
      _legs = newLegs;
    });
    await _save();
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

  Future<PlannedPlanLeg?> _searchAndRetry(int index, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final point = await _locationService.searchPlace(trimmed);
    if (!mounted || point == null) return null;
    return _applyRetriedLeg(index, point);
  }

  Future<PlannedPlanLeg?> _detectAndRetry(int index) async {
    final result = await _locationService.detectCurrentLocation();
    if (!mounted) return null;
    final point = result.point;
    if (result.status != LocationLookupStatus.success || point == null) {
      final message = switch (result.status) {
        LocationLookupStatus.permissionDenied =>
          'Location permission denied - search a starting point instead.',
        LocationLookupStatus.serviceDisabled =>
          'Location services are off - search a starting point instead.',
        _ =>
          "Couldn't get an accurate GPS fix - search a starting point "
              'instead.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return null;
    }
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
      ],
    );
  }
}

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

