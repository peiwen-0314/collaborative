import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/ai_trip_planner_controller.dart';
import '../controllers/personalization_controller.dart';
import '../controllers/transport_controller.dart';
import '../core/formatters.dart';
import '../models/attraction.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip_plan.dart';
import '../models/transport_mode.dart';
import '../models/trip_schedule_item.dart';
import '../services/location_service.dart';
import 'attraction_detail_page.dart';
import 'ai_trip_planner_page.dart';
import 'trip_details_page.dart';
import 'trip_location_date_page.dart';

class GeneratedTripPage extends StatefulWidget {
  final AiTripPlannerController controller;

  const GeneratedTripPage({
    super.key,
    required this.controller,
  });

  @override
  State<GeneratedTripPage> createState() => _GeneratedTripPageState();
}

class _GeneratedTripPageState extends State<GeneratedTripPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color textGrey = Color(0xFF666666);

  int selectedDay = 0;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _savedPlanId;

  final PersonalizationController
  _personalizationController =
  PersonalizationController();

  bool _hasRecordedGeneratedPreferences = false;

  // Real transportation, computed automatically the moment this page
  // opens (see _computeTransport) using the same engine as the
  // transportation module's own "Plan Transportation" flow
  // (TransportController.planTransportationForPlan) - replaces the
  // HERE-routing-based estimate this page used to compute for itself
  // (TripScheduleItem.transportMinutesBefore etc, still kept as raw
  // schedule data but no longer shown as the "estimate").
  final TransportController _transportController = TransportController();
  final LocationService _locationService = const LocationService();
  List<PlannedPlanLeg>? _transportLegs;
  Map<String, PlannedPlanLeg> _legsByKey = {};
  Map<String, int> _legIndexByKey = {};
  final Set<int> _retryingLegs = {};
  bool _transportLoading = false;
  bool _transportInitialComputeDone = false;
  String? _transportError;
  double _totalTransportCo2Kg = 0;

  /// Sum of every planned leg's real transport fare - see _summary(),
  /// which folds this into the budget check so "within budget" means
  /// attractions AND getting to them, not just attractions.
  double get _totalTransportCostRm {
    final legs = _transportLegs;
    if (legs == null) return 0;
    var total = 0.0;
    for (final leg in legs) {
      final cost = leg.option?.estCostRm;
      if (cost != null) total += cost;
    }
    return total;
  }

  static String _legKey(int day, String attractionName) =>
      '$day::$attractionName';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordGeneratedTripPreferences();
      _computeTransport();
    });
  }

  Future<void> _recordGeneratedTripPreferences() async {
    if (_hasRecordedGeneratedPreferences) {
      return;
    }

    _hasRecordedGeneratedPreferences = true;

    await _personalizationController
        .recordGeneratedTripPreferences(
      selectedState:
      widget.controller.preferences.selectedState,
      travelStyles:
      List<String>.from(
        widget.controller.preferences.travelStyles,
      ),
    );
  }

  /// Plans real transportation for every stop in this itinerary, using
  /// the transportation module's own engine
  /// (TransportController.planTransportationForPlan) - the same one
  /// the (now removed) manual "Plan Transportation" flow used. Runs
  /// automatically as soon as this page opens, before the person
  /// presses Save, so it needs their current location right away.
  Future<void> _computeTransport() async {
    if (_transportLoading) return;

    setState(() {
      _transportLoading = true;
      _transportError = null;
    });

    try {
      final preferences = widget.controller.preferences;
      final totalDays =
          preferences.totalDays <= 0 ? 1 : preferences.totalDays;

      final attractions = <SavedTripPlanAttraction>[];
      for (var dayIndex = 0; dayIndex < totalDays; dayIndex++) {
        for (final attraction
            in widget.controller.attractionsForDay(dayIndex)) {
          attractions.add(
            SavedTripPlanAttraction(
              name: attraction.name,
              address: attraction.address,
              area: attraction.area,
              day: dayIndex + 1,
              openingTime: attraction.openingTime,
              closingTime: attraction.closingTime,
              recommendedDuration: attraction.recommendedDuration,
            ),
          );
        }
      }

      if (attractions.isEmpty) {
        if (!mounted) return;
        setState(() {
          _transportLoading = false;
          _transportInitialComputeDone = true;
        });
        return;
      }

      // In-memory only (id: '') - this plan may not be saved to
      // Firestore yet. planTransportationForPlan never reads plan.id,
      // only the fields set here, so this is safe.
      final plan = SavedTripPlan(
        id: '',
        selectedState: preferences.selectedState,
        startDate: preferences.startDate ?? DateTime.now(),
        endDate: preferences.endDate ?? DateTime.now(),
        dateSummary: preferences.dateSummary,
        totalDays: totalDays,
        totalAttractions: attractions.length,
        travelStyle: preferences.travelStyles.isNotEmpty
            ? preferences.travelStyles.first
            : null,
        attractions: attractions,
      );

      final locationResult = await _locationService.detectCurrentLocation();
      if (!mounted) return;

      final startingFrom = locationResult.point;
      if (startingFrom == null) {
        setState(() {
          _transportLoading = false;
          _transportInitialComputeDone = true;
          _transportError =
              "Couldn't detect your current location, so real "
              'transportation routes could not be planned for this trip.';
        });
        return;
      }

      final legs = await _transportController.planTransportationForPlan(
        plan,
        startingFrom: startingFrom,
      );
      if (!mounted) return;

      final legsByKey = <String, PlannedPlanLeg>{};
      final legIndexByKey = <String, int>{};
      var totalCo2 = 0.0;
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final key = _legKey(leg.day, leg.attractionName);
        legsByKey[key] = leg;
        legIndexByKey[key] = i;
        final co2 = leg.option?.co2Kg;
        if (co2 != null) totalCo2 += co2;
      }

      setState(() {
        _transportLegs = legs;
        _legsByKey = legsByKey;
        _legIndexByKey = legIndexByKey;
        _totalTransportCo2Kg = totalCo2;
        _transportLoading = false;
        _transportInitialComputeDone = true;
      });
    } catch (error) {
      debugPrint('[GeneratedTripPage] transport planning failed: $error');
      if (!mounted) return;
      setState(() {
        _transportLoading = false;
        _transportInitialComputeDone = true;
        _transportError = 'Could not plan transportation for this trip.';
      });
    }
  }

  /// Opens the same detail/edit page the (now removed) manual "Plan
  /// Transportation" flow used for one leg - lets the person change
  /// the starting point or pick a different route, same as before.
  void _openLegDetail(int index) {
    final legs = _transportLegs;
    if (legs == null || index < 0 || index >= legs.length) return;
    final leg = legs[index];
    final option = leg.option;
    final to = leg.to;
    if (option == null || to == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: leg.from,
          to: to,
          option: option,
          allowTimeChange: true,
          isPlanLeg: true,
          onChangeFrom: (query) => _searchAndRetryLeg(index, query),
          onAutoDetectFrom: () => _detectAndRetryLeg(index),
          onSaveEditedLeg: (editedOption) => _saveEditedLeg(index, editedOption),
        ),
      ),
    );
  }

  Future<void> _persistLegsIfSaved() async {
    final planId = _savedPlanId;
    final legs = _transportLegs;
    if (!_isSaved || planId == null || legs == null) return;
    try {
      await _transportController.saveTransportPlan(planId, legs);
    } catch (error) {
      debugPrint(
        '[GeneratedTripPage] re-saving transport plan failed: $error',
      );
    }
  }

  void _replaceLeg(int index, PlannedPlanLeg updated) {
    final legs = _transportLegs;
    if (legs == null || index < 0 || index >= legs.length) return;

    final newLegs = List<PlannedPlanLeg>.from(legs);
    newLegs[index] = updated;

    final newByKey = Map<String, PlannedPlanLeg>.from(_legsByKey);
    newByKey[_legKey(updated.day, updated.attractionName)] = updated;

    var totalCo2 = 0.0;
    for (final leg in newLegs) {
      final co2 = leg.option?.co2Kg;
      if (co2 != null) totalCo2 += co2;
    }

    setState(() {
      _transportLegs = newLegs;
      _legsByKey = newByKey;
      _totalTransportCo2Kg = totalCo2;
    });
  }

  Future<void> _saveEditedLeg(int index, RideOption option) async {
    final legs = _transportLegs;
    if (legs == null || index < 0 || index >= legs.length) return;
    _replaceLeg(index, legs[index].withOption(option));
    await _persistLegsIfSaved();
  }

  /// Rebuilds the same SavedTripPlanAttraction _computeTransport would
  /// have built for this leg, so retryPlanLeg can be called for just
  /// this one stop instead of recomputing the whole itinerary.
  SavedTripPlanAttraction? _attractionForLeg(PlannedPlanLeg leg) {
    final preferences = widget.controller.preferences;
    final totalDays =
        preferences.totalDays <= 0 ? 1 : preferences.totalDays;
    final dayIndex = leg.day - 1;
    if (dayIndex < 0 || dayIndex >= totalDays) return null;

    for (final attraction in widget.controller.attractionsForDay(dayIndex)) {
      if (attraction.name == leg.attractionName) {
        return SavedTripPlanAttraction(
          name: attraction.name,
          address: attraction.address,
          area: attraction.area,
          day: leg.day,
          openingTime: attraction.openingTime,
          closingTime: attraction.closingTime,
          recommendedDuration: attraction.recommendedDuration,
        );
      }
    }
    return null;
  }

  Future<PlannedPlanLeg?> _applyRetriedLeg(
    int index,
    LocationPoint from,
  ) async {
    final legs = _transportLegs;
    if (legs == null || index < 0 || index >= legs.length) return null;
    final leg = legs[index];
    final attraction = _attractionForLeg(leg);
    if (attraction == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find this attraction in the itinerary anymore.',
            ),
          ),
        );
      }
      return null;
    }

    final earliestDepart = index > 0
        ? legs[index - 1].visitEnd
        : leg.visitStart.subtract(const Duration(hours: 3));

    setState(() => _retryingLegs.add(index));
    try {
      final updated = await _transportController.retryPlanLeg(
        from: from,
        attraction: attraction,
        day: leg.day,
        visitStart: leg.visitStart,
        visitEnd: leg.visitEnd,
        earliestDepart: earliestDepart,
      );
      if (!mounted) return updated;
      _replaceLeg(index, updated);
      setState(() => _retryingLegs.remove(index));
      await _persistLegsIfSaved();
      return updated;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _retryingLegs.remove(index));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $error')));
      return null;
    }
  }

  /// Plain retry - same starting point as before, in case the earlier
  /// failure was just a transient search/network hiccup.
  Future<void> _retryLegTap(int index) {
    final legs = _transportLegs;
    if (legs == null || index < 0 || index >= legs.length) {
      return Future<void>.value();
    }
    return _applyRetriedLeg(index, legs[index].from).then((_) {});
  }

  Future<PlannedPlanLeg?> _searchAndRetryLeg(int index, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final point = await _locationService.searchPlace(trimmed);
    if (!mounted || point == null) return null;
    return _applyRetriedLeg(index, point);
  }

  Future<PlannedPlanLeg?> _detectAndRetryLeg(int index) async {
    final result = await _locationService.detectCurrentLocation();
    if (!mounted) return null;
    final point = result.point;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location - search a starting point instead.",
          ),
        ),
      );
      return null;
    }
    return _applyRetriedLeg(index, point);
  }

  Widget _transportBannerIcon() {
    if (_transportLoading) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: mainGreen),
      );
    }
    if (_transportError != null) {
      return const Icon(Icons.error_outline, size: 14, color: Colors.orange);
    }
    return const Icon(Icons.route_outlined, size: 14, color: mainGreen);
  }

  String _transportBannerText() {
    if (_transportLoading) {
      return 'Planning real transportation routes for every stop, based '
          'on your current location...';
    }
    final error = _transportError;
    if (error != null) return error;
    if (_transportLegs != null) {
      return 'Real transportation planned for every stop - total '
          'transport CO2: ${_totalTransportCo2Kg.toStringAsFixed(2)} kg.';
    }
    return 'Daily stop sequence optimized for a sustainable, walkable '
        'route.';
  }

  @override
  void dispose() {
    _personalizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_transportInitialComputeDone) {
      return _buildTransportLoadingScreen();
    }

    final int days = widget.controller.preferences.totalDays <= 0
        ? 1
        : widget.controller.preferences.totalDays;

    final List<TripScheduleItem> list =
    widget.controller.scheduleForDay(selectedDay);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnToPlanner();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _appBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: lightGreen,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: mainGreen,
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your trip is ready!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'We’ve crafted a personalized, sustainable itinerary just for you.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF777777),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _summary(),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _transportBannerIcon(),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _transportBannerText(),
                                style: const TextStyle(
                                  fontSize: 7.5,
                                  color: textGrey,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (_transportError != null) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _computeTransport,
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    color: mainGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days,
                          separatorBuilder: (_, __) => const SizedBox(width: 7),
                          itemBuilder: (context, index) {
                            final bool isSelected = selectedDay == index;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedDay = index;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? mainGreen : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? mainGreen
                                        : const Color(0xFFE1E1E1),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Day ${index + 1}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF555555),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text('No attractions for this day.'),
                          ),
                        )
                      else
                        ...List.generate(
                          list.length,
                              (index) => _item(
                            list[index],
                            index == list.length - 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _bottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown instead of the itinerary while the very first transport
  /// computation is still running, so the person only ever sees the
  /// finished plan - attractions AND real transportation together -
  /// rather than a page that opens with transport chips filling in
  /// one by one.
  Widget _buildTransportLoadingScreen() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnToPlanner();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: mainGreen),
                  const SizedBox(height: 18),
                  const Text(
                    'Generating your trip...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Please don't exit while we finish generating your "
                    'trip.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF777777),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          IconButton(
            onPressed: _returnToPlanner,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
          ),
          const Expanded(
            child: Text(
              'AI Trip Planner',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _summary() {
    final preferences =
        widget.controller.preferences;

    final int totalDays =
        preferences.totalDays;

    final double budget =
        preferences.budget;

    final double attractionCost =
        widget.controller
            .estimatedTotalAttractionCost;

    final double transportCost = _totalTransportCostRm;

    final double estimatedCost = attractionCost + transportCost;

    final int places =
        widget.controller
            .generatedAttractions.length;

    final bool overBudget =
        budget > 0 && estimatedCost > budget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryBox(
                  icon:
                  Icons.calendar_today_outlined,
                  value:
                  '$totalDays Days',
                  label:
                  'Total Days',
                ),
              ),
              Expanded(
                child: _summaryBox(
                  icon:
                  Icons.account_balance_wallet_outlined,
                  value:
                  'MYR ${_formatMoney(estimatedCost)} / ${_formatMoney(budget)}',
                  label:
                  'Est. Total Cost (+ Transport) / Budget',
                ),
              ),
              Expanded(
                child: _summaryBox(
                  icon:
                  Icons.location_on_outlined,
                  value:
                  '$places ${places == 1 ? 'Place' : 'Places'}',
                  label:
                  'Total Attractions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: overBudget
                  ? const Color(0xFFFFF3E0)
                  : Colors.white.withValues(
                alpha: 0.72,
              ),
              borderRadius:
              BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  overBudget
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: overBudget
                      ? const Color(0xFFE65100)
                      : mainGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    overBudget
                        ? 'Over budget by MYR ${_formatMoney(estimatedCost - budget)}'
                        : 'Within budget • MYR ${_formatMoney((budget - estimatedCost) < 0 ? 0 : (budget - estimatedCost))} remaining',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                      FontWeight.w600,
                      color: overBudget
                          ? const Color(0xFFE65100)
                          : mainGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              'Estimated cost currently includes attraction admission fees only.',
              style: TextStyle(
                fontSize: 6.8,
                color: textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: mainGreen),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 6.7,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(
      TripScheduleItem scheduleItem,
      bool last,
      ) {
    final attraction =
        scheduleItem.attraction;

    final String image =
    attraction.coverImageUrl
        .trim()
        .isNotEmpty
        ? attraction.coverImageUrl
        : attraction.imageUrls.isNotEmpty
        ? attraction.imageUrls.first
        : '';

    final double estimatedFee =
        scheduleItem.estimatedFee;

    final String openingHours =
    _openingHours(attraction);

    final String time =
    _formatClock(
      scheduleItem.startTime,
    );

    final String endTime =
    _formatClock(
      scheduleItem.endTime,
    );

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF555555),
            ),
          ),
        ),
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: mainGreen,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: 168,
                  color:
                  const Color(0xFFAAAAAA),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.only(
              bottom: 14,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final key = _legKey(
                      scheduleItem.dayNumber,
                      scheduleItem.attraction.name,
                    );
                    final leg = _legsByKey[key];
                    final legIndex = _legIndexByKey[key];
                    final option = leg?.option;
                    final retrying =
                        legIndex != null && _retryingLegs.contains(legIndex);

                    if (option != null) {
                      final mode = _dominantLegMode(option);
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: legIndex == null
                            ? null
                            : () => _openLegDetail(legIndex),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              transportModeGlyph(
                                mode,
                                size: 12,
                                color: mainGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${formatDuration(option.totalDuration)}'
                                    ' • '
                                    '${option.co2Kg.toStringAsFixed(2)} kg CO2',
                                style: const TextStyle(
                                  fontSize: 7.5,
                                  color: mainGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                mode.label,
                                style: const TextStyle(
                                  fontSize: 6.5,
                                  color: textGrey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 13,
                                color: mainGreen.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (leg != null) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: retrying || legIndex == null
                            ? null
                            : () => _retryLegTap(legIndex),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: retrying
                                ? const [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.4,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retrying...',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ]
                                : [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'No real route found - tap to retry',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      );
                    }

                    if (_transportLoading) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.4,
                                color: mainGreen,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Planning route...',
                              style: TextStyle(
                                fontSize: 7.5,
                                color: textGrey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AttractionDetailPage(
                              attraction:
                              attraction,
                              estimatedFee:
                              estimatedFee,
                            ),
                      ),
                    );
                  },
                  borderRadius:
                  BorderRadius.circular(9),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          8,
                        ),
                        child: SizedBox(
                          width: 82,
                          height: 120,
                          child: image.isEmpty
                              ? Container(
                            color:
                            lightGreen,
                            child:
                            const Icon(
                              Icons
                                  .image_outlined,
                              color:
                              mainGreen,
                            ),
                          )
                              : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                _,
                                __,
                                ___,
                                ) =>
                                Container(
                                  color:
                                  lightGreen,
                                  child:
                                  const Icon(
                                    Icons
                                        .image_outlined,
                                    color:
                                    mainGreen,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              attraction.name,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .location_on_outlined,
                                  color:
                                  mainGreen,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${attraction.area}, ${attraction.state}',
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(
                                      color:
                                      mainGreen,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .schedule_outlined,
                                  size: 11,
                                  color:
                                  textGrey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '$time - $endTime'
                                        ' • '
                                        '${scheduleItem.visitMinutes} min visit',
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 8,
                                      color:
                                      textGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .access_time_rounded,
                                  size: 11,
                                  color:
                                  textGrey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    openingHours,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 8,
                                      color:
                                      textGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .confirmation_number_outlined,
                                  size: 11,
                                  color:
                                  textGrey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    attraction
                                        .isFreeEntry
                                        ? 'Free Entry'
                                        : 'Estimated Fee: MYR ${_formatMoney(estimatedFee)}',
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 8,
                                      color:
                                      textGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children:
                              _categoryTags(
                                attraction,
                              )
                                  .map(
                                _categoryChip,
                              )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _categoryTags(
      AttractionModel attraction,
      ) {
    final tags = <String>{
      ...attraction.categoryNames
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
      if (attraction.categoryName.trim().isNotEmpty)
        attraction.categoryName.trim(),
    }.toList();

    return tags.isEmpty ? <String>['Attraction'] : tags;
  }

  Widget _categoryChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFC8E6C9),
          width: 0.7,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: mainGreen,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _feeInformation(AttractionModel attraction) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        if (attraction.malaysianAdultFee > 0)
          _feeChip('Adult', attraction.malaysianAdultFee),
        if (attraction.malaysianChildFee > 0)
          _feeChip('Child', attraction.malaysianChildFee),
        if (attraction.malaysianSeniorFee > 0)
          _feeChip('Senior', attraction.malaysianSeniorFee),
      ],
    );
  }

  Widget _feeChip(String label, double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Text(
        '$label RM${_formatMoney(price)}',
        style: const TextStyle(
          fontSize: 6.7,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  Widget _bottomButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _toggleSavePlan,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainGreen,
                  side: const BorderSide(color: mainGreen, width: 1.2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mainGreen,
                  ),
                )
                    : Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 17,
                ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isSaved
                      ? 'Saved'
                      : 'Save Plan',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _regeneratePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Regenerate Plan',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSavePlan() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login before saving your trip plan.',
        isError: true,
      );
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isSaved) {
        final savedId = _savedPlanId;

        if (savedId != null) {
          await FirebaseFirestore.instance
              .collection('saved_trip_plans')
              .doc(savedId)
              .delete();
          await _transportController.deleteTransportPlan(savedId);
        }

        if (!mounted) return;

        setState(() {
          _isSaved = false;
          _savedPlanId = null;
        });

        _showMessage('Trip plan removed from saved plans.');
        return;
      }

      if (widget.controller.generatedAttractions.isEmpty) {
        _showMessage(
          'There is no trip plan to save.',
          isError: true,
        );
        return;
      }

      final preferences = widget.controller.preferences;
      final attractions = widget.controller.generatedAttractions;
      final List<Map<String, dynamic>> attractionData = [];

      for (final attraction in attractions) {
        attractionData.add({
          'id': attraction.id,
          'name': attraction.name,
          'categoryId': attraction.categoryId,
          'categoryName': attraction.categoryName,
          'categoryIds': attraction.categoryIds,
          'categoryNames': attraction.categoryNames,
          'state': attraction.state,
          'area': attraction.area,
          'address': attraction.address,
          'description': attraction.description,
          'coverImageUrl': attraction.coverImageUrl,
          'imageUrls': attraction.imageUrls,
          'isFreeEntry': attraction.isFreeEntry,
          'malaysianAdultFee': attraction.malaysianAdultFee,
          'malaysianChildFee': attraction.malaysianChildFee,
          'malaysianSeniorFee': attraction.malaysianSeniorFee,
          'nonMalaysianAdultFee': attraction.nonMalaysianAdultFee,
          'nonMalaysianChildFee': attraction.nonMalaysianChildFee,
          'nonMalaysianSeniorFee': attraction.nonMalaysianSeniorFee,
          'estimatedFee': widget.controller.estimateAttractionFee(attraction),
          'openingTime': attraction.openingTime,
          'closingTime': attraction.closingTime,
          'recommendedDuration': attraction.recommendedDuration,
          'phoneNumber': attraction.phoneNumber,
          'facilities': attraction.facilities,
          'highlights': attraction.highlights,
          'day': _getAttractionDay(attraction),
          ..._scheduleDataForAttraction(attraction),
        });
      }

      final doc = await FirebaseFirestore.instance
          .collection('saved_trip_plans')
          .add({
        'userId': user.uid,
        'userEmail': user.email,
        'selectedState': preferences.selectedState,
        'startDate': preferences.startDate == null
            ? null
            : Timestamp.fromDate(preferences.startDate!),
        'endDate': preferences.endDate == null
            ? null
            : Timestamp.fromDate(preferences.endDate!),
        'totalDays': preferences.totalDays,
        'dateSummary': preferences.dateSummary,
        'adults': preferences.adults,
        'children': preferences.children,
        'seniors': preferences.seniors,
        'totalTravelers': preferences.totalTravelers,
        'travelerSummary': preferences.travelerSummary,
        'budget': preferences.budget,
        'estimatedAttractionCost':
        widget.controller.estimatedTotalAttractionCost,
        'totalTransportCo2Kg': _totalTransportCo2Kg,
        'totalTransportCostRm': _totalTransportCostRm,
        'travelStyles': List<String>.from(preferences.travelStyles),
        'travelStyleSummary': preferences.travelStyleSummary,
        'totalAttractions': attractions.length,
        'attractions': attractionData,
        'status': 'saved',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final legsToSave = _transportLegs;
      if (legsToSave != null && legsToSave.isNotEmpty) {
        try {
          await _transportController.saveTransportPlan(doc.id, legsToSave);
        } catch (error) {
          debugPrint(
            '[GeneratedTripPage] saving transport plan failed: $error',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _isSaved = true;
        _savedPlanId = doc.id;
      });

      _showMessage('Trip plan saved successfully!');
    } catch (e) {
      debugPrint('Toggle save trip plan error: $e');

      if (!mounted) return;

      _showMessage(
        _isSaved
            ? 'Unable to remove saved trip plan.'
            : 'Unable to save trip plan.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Map<String, dynamic> _scheduleDataForAttraction(
      AttractionModel attraction,
      ) {
    for (final item
    in widget.controller.generatedSchedule) {
      if (item.attraction.id ==
          attraction.id) {
        return {
          'startTime':
          Timestamp.fromDate(
            item.startTime,
          ),
          'endTime':
          Timestamp.fromDate(
            item.endTime,
          ),
          'visitMinutes':
          item.visitMinutes,
          'transportMinutesBefore':
          item.transportMinutesBefore,
          'distanceFromPreviousKm':
          item.distanceFromPreviousKm,
          'usedHereRouting':
          item.usedHereRouting,
          'recommendationScore':
          item.recommendationScore,
        };
      }
    }

    return {};
  }

  int _getAttractionDay(AttractionModel attraction) {
    final int totalDays = widget.controller.preferences.totalDays <= 0
        ? 1
        : widget.controller.preferences.totalDays;

    for (int day = 0; day < totalDays; day++) {
      final List<AttractionModel> dayAttractions =
      widget.controller.attractionsForDay(day);

      final bool exists = dayAttractions.any(
            (item) => item.id == attraction.id,
      );

      if (exists) {
        return day + 1;
      }
    }

    return 1;
  }

  void _returnToPlanner() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AiTripPlannerPage(),
      ),
          (route) => route.isFirst,
    );
  }

  void _regeneratePlan() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => TripLocationDatePage(
          controller: widget.controller,
        ),
      ),
          (route) => route.isFirst,
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : mainGreen,
      ),
    );
  }

  String _openingHours(AttractionModel attraction) {
    final String opening = _format24HourTime(attraction.openingTime);
    final String closing = _format24HourTime(attraction.closingTime);

    if (opening.isEmpty && closing.isEmpty) {
      return 'Opening hours unavailable';
    }
    if (opening.isEmpty) return closing;
    if (closing.isEmpty) return opening;

    return '$opening-$closing';
  }

  String _format24HourTime(String value) {
    final String input = value.trim();

    if (input.isEmpty) return '';

    final Match? normal24 = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(input);

    if (normal24 != null) {
      final int hour = int.tryParse(normal24.group(1)!) ?? 0;
      final String minute = normal24.group(2)!;
      return '$hour:$minute';
    }

    final Match? twelveHour = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(input);

    if (twelveHour != null) {
      int hour = int.tryParse(twelveHour.group(1)!) ?? 0;
      final String minute = twelveHour.group(2)!;
      final String period = twelveHour.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return '$hour:$minute';
    }

    return input;
  }

  String _formatClock(
      DateTime value,
      ) {
    final hour =
    value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final minute =
    value.minute
        .toString()
        .padLeft(2, '0');

    final period =
    value.hour >= 12
        ? 'PM'
        : 'AM';

    return '$hour:$minute $period';
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

/// Same "which mode dominates this route" rule as RideCard's own
/// private _majorityMode (ride_card.dart) - duplicated here (rather
/// than exported) so this page doesn't need to import a widget file
/// just for one small pure function.
TransportMode _dominantLegMode(RideOption option) {
  final legs = option.legs;
  if (legs.isEmpty) return TransportMode.other;

  final totalsByMode = <TransportMode, Duration>{};
  for (final leg in legs) {
    totalsByMode[leg.mode] =
        (totalsByMode[leg.mode] ?? Duration.zero) + leg.duration;
  }

  var majority = legs.first.mode;
  var majorityDuration = Duration.zero;
  for (final entry in totalsByMode.entries) {
    if (entry.value > majorityDuration) {
      majority = entry.key;
      majorityDuration = entry.value;
    }
  }
  return majority;
}
