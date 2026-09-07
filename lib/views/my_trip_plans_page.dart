import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../models/saved_trip_plan.dart';

// Pushed from ProfilePage's ACTIVITY section. This is a plain,
// read-only view of the trip itineraries the person has saved from
// the AI Trip Planner (SavedTripPlan, from the shared
// `saved_trip_plans` Firestore collection) - unlike TripPlansPage
// (also in this module, used by RideHomePage), this page is NOT about
// transportation: no "transport planned" badge, and tapping a plan
// opens its own day-by-day itinerary instead of PlanTransportPage.
class MyTripPlansPage extends StatefulWidget {
  const MyTripPlansPage({super.key});

  @override
  State<MyTripPlansPage> createState() => _MyTripPlansPageState();
}

class _MyTripPlansPageState extends State<MyTripPlansPage> {
  final TransportController _controller = TransportController();

  List<SavedTripPlan>? _plans;
  String? _error;

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
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _openPlan(SavedTripPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripPlanDetailPage(plan: plan)),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
            'No trip plans yet.\nSave a trip in the AI Trip Planner to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PlanCard(
        plan: plans[index],
        onTap: () => _openPlan(plans[index]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final SavedTripPlan plan;
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
                    Text(
                      state != null && state.isNotEmpty ? state : 'Trip Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
                      subtitleParts.join(' · '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PLAN DETAIL - day-by-day itinerary, read-only. No transport
// planning here on purpose - see this file's own top doc comment.
// ============================================================
class TripPlanDetailPage extends StatefulWidget {
  const TripPlanDetailPage({super.key, required this.plan});

  final SavedTripPlan plan;

  @override
  State<TripPlanDetailPage> createState() => _TripPlanDetailPageState();
}

class _TripPlanDetailPageState extends State<TripPlanDetailPage> {
  int _selectedDay = 1;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final state = plan.selectedState?.trim();
    final dayAttractions = plan.attractionsForDay(_selectedDay);

    final subtitleParts = <String>[
      '${plan.totalAttractions} attractions',
      '${plan.totalDays} day${plan.totalDays == 1 ? '' : 's'}',
      if (plan.travelStyle != null && plan.travelStyle!.trim().isNotEmpty)
        plan.travelStyle!,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          state != null && state.isNotEmpty ? state : 'Trip Plan',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.dateSummary,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),

          if (plan.totalDays > 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                itemCount: plan.totalDays,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final selected = day == _selectedDay;
                  return ChoiceChip(
                    label: Text('Day $day'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedDay = day),
                    selectedColor: AppColors.green,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.chip,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected ? AppColors.green : AppColors.border,
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 4),

          Expanded(
            child: dayAttractions.isEmpty
                ? const Center(
              child: Text(
                'No attractions for this day.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: dayAttractions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _AttractionTile(
                attraction: dayAttractions[index],
                order: index + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttractionTile extends StatelessWidget {
  const _AttractionTile({required this.attraction, required this.order});

  final SavedTripPlanAttraction attraction;
  final int order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.paleGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attraction.name.isEmpty ? 'Attraction' : attraction.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (attraction.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    attraction.address,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (attraction.openingTime.isNotEmpty ||
                        attraction.closingTime.isNotEmpty) ...[
                      const Icon(
                        Icons.schedule,
                        size: 13,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${attraction.openingTime.isEmpty ? '?' : attraction.openingTime}'
                        ' - '
                        '${attraction.closingTime.isEmpty ? '?' : attraction.closingTime}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (attraction.recommendedDuration.isNotEmpty) ...[
                      const Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        attraction.recommendedDuration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
