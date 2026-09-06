import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../models/saved_trip_plan.dart';
import 'plan_transport_page.dart';

/// Lists every one of the signed-in user's saved trip plans (the AI
/// Trip Planner module's `saved_trip_plans`) that hasn't ended yet - see
/// TransportController.getActiveSavedPlans. Replaces the old
/// lightbulb-icon bottom sheet on RideHomePage's header, which only
/// ever surfaced a single "today" recommendation with nowhere to go
/// from there. Styled like SavedListPage (a real full page, not a
/// drawer/sheet) so a person can browse every upcoming trip at once and
/// pick one to plan transportation for in full - see PlanTransportPage.
class TripPlansPage extends StatefulWidget {
  const TripPlansPage({super.key});

  @override
  State<TripPlansPage> createState() => _TripPlansPageState();
}

class _TripPlansPageState extends State<TripPlansPage> {
  final TransportController _controller = TransportController();

  List<SavedTripPlan>? _plans;
  String? _error;

  /// Which of [_plans] already have a saved transportation plan (see
  /// TransportController.plannedTransportPlanIds) - lets each
  /// [_PlanCard] show whether it still needs transport planned or is
  /// already sorted, instead of the person having to open every plan to
  /// find out. Empty (not null) until it's actually known, so a plan
  /// never flashes "planned" before this loads.
  Set<String> _plannedIds = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plans = await _controller.getActiveSavedPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _error = null;
      });
      // Best-effort, separate from the plans themselves loading - a
      // failure here just means every card shows as "not planned yet"
      // rather than blocking the whole list.
      try {
        final plannedIds = await _controller.plannedTransportPlanIds(
          plans.map((plan) => plan.id),
        );
        if (!mounted) return;
        setState(() => _plannedIds = plannedIds);
      } catch (error) {
        debugPrint('[TripPlansPage] planned-status lookup failed: $error');
      }
    } catch (error) {
      // Surfaced plainly (e.g. "please log in") rather than an empty
      // list, which would read as "you have no trip plans" even when
      // the real reason is something fixable.
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _openPlan(SavedTripPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanTransportPage(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'My Trip Plans',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
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
              const Text(
                'Could not load your trip plans.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final plans = _plans;
    if (plans == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (plans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No upcoming trip plans.\nSave a trip in the AI Trip Planner to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      itemCount: plans.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PlanCard(
        plan: plans[index],
        transportPlanned: _plannedIds.contains(plans[index].id),
        onTap: () => _openPlan(plans[index]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.transportPlanned,
    required this.onTap,
  });

  final SavedTripPlan plan;

  /// Whether this plan already has a saved transportation plan (see
  /// TripPlansPage._plannedIds) - shown as a small badge so the person
  /// can tell at a glance which trips still need transport planned.
  final bool transportPlanned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = plan.selectedState?.trim();
    final subtitleParts = <String>[
      '${plan.totalAttractions} attractions',
      '${plan.totalDays} day${plan.totalDays == 1 ? '' : 's'}',
      if (plan.travelStyle != null && plan.travelStyle!.trim().isNotEmpty)
        plan.travelStyle!,
    ];

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            state != null && state.isNotEmpty
                                ? state
                                : 'Trip Plan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TransportStatusBadge(planned: transportPlanned),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.dateSummary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' \u00b7 '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Transport planned" (green, checked) vs "Not planned yet" (muted
/// outline) - see TripPlansPage._plannedIds/_PlanCard.transportPlanned.
class _TransportStatusBadge extends StatelessWidget {
  const _TransportStatusBadge({required this.planned});

  final bool planned;

  @override
  Widget build(BuildContext context) {
    final color = planned ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: planned ? AppColors.paleGreen : AppColors.chip,
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            planned ? Icons.check_circle : Icons.schedule,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            planned ? 'Planned' : 'Not planned',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
