import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/formatters.dart';
import '../models/attraction.dart';
import '../models/ride_option.dart';
import '../models/saved_trip_plan.dart';
import '../models/transport_mode.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import 'attraction_detail_page.dart';
import 'edit_saved_trip_plan_page.dart';
import 'trip_details_page.dart';

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

class SavedTripPlansPage extends StatelessWidget {
  const SavedTripPlansPage({super.key});

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: textColor,
          ),
        ),
        title: const Text(
          'My Trip Plans',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      body: user == null
          ? _notLoggedIn()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('saved_trip_plans')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorState();
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: mainGreen,
              ),
            );
          }

          final docs = [
            ...?snapshot.data?.docs,
          ];

          docs.sort((a, b) {
            final aDate = _createdAt(a.data());
            final bDate = _createdAt(b.data());
            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return _emptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              28,
            ),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];

              return _planCard(
                context,
                planId: doc.id,
                data: doc.data(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _planCard(
      BuildContext context, {
        required String planId,
        required Map<String, dynamic> data,
      }) {
    final attractions = _attractions(data);

    String imageUrl = '';

    if (attractions.isNotEmpty) {
      imageUrl =
          (attractions.first['coverImageUrl'] ?? '')
              .toString()
              .trim();

      if (imageUrl.isEmpty) {
        final images = attractions.first['imageUrls'];

        if (images is List && images.isNotEmpty) {
          imageUrl = images.first.toString().trim();
        }
      }
    }

    final state =
    (data['selectedState'] ?? '').toString();

    final travelStyle =
    _travelStyleSummary(data);

    final dateSummary =
    _dateSummary(data);

    final travelerSummary =
    (data['travelerSummary'] ?? '').toString();

    final totalAttractions =
        (data['totalAttractions'] as num?)?.toInt() ??
            attractions.length;

    final budget =
        (data['budget'] as num?)?.toDouble() ?? 0;

    final estimatedCost =
        (data['estimatedAttractionCost'] as num?)
            ?.toDouble() ??
            _sumEstimatedFees(attractions);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SavedTripPlanDetailPage(
                    planId: planId,
                    data: data,
                  ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFE4E8E4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 112,
                  child: imageUrl.isEmpty
                      ? _imageFallback()
                      : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _imageFallback(),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SizedBox(
                  height: 112,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.isEmpty
                                  ? 'My Trip Plan'
                                  : '$state Trip',
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                _deletePlan(
                                  context,
                                  planId,
                                ),
                            borderRadius:
                            BorderRadius.circular(20),
                            child: const Padding(
                              padding:
                              EdgeInsets.all(4),
                              child: Icon(
                                Icons
                                    .delete_outline_rounded,
                                size: 18,
                                color:
                                Color(0xFF888888),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (travelStyle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          travelStyle,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: mainGreen,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _infoLine(
                        Icons.calendar_today_outlined,
                        dateSummary,
                      ),
                      const SizedBox(height: 4),
                      _infoLine(
                        Icons.people_outline_rounded,
                        travelerSummary.isEmpty
                            ? 'Traveller information unavailable'
                            : travelerSummary,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _smallBadge(
                            '$totalAttractions Places',
                          ),
                          const SizedBox(width: 6),
                          _smallBadge(
                            'Est. RM ${_money(estimatedCost)} / ${_money(budget)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoLine(
      IconData icon,
      String text,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: secondaryText,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              color: secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 7.5,
          color: mainGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: lightGreen,
      alignment: Alignment.center,
      child: const Icon(
        Icons.route_outlined,
        color: mainGreen,
        size: 32,
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: lightGreen,
              child: Icon(
                Icons.route_outlined,
                size: 34,
                color: mainGreen,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'No saved trip plans yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Generate a trip and tap "Save Plan" to keep it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return const Center(
      child: Text(
        'Unable to load your saved trip plans.',
        style: TextStyle(
          fontSize: 11,
          color: secondaryText,
        ),
      ),
    );
  }

  Widget _notLoggedIn() {
    return const Center(
      child: Text(
        'Please login to view your trip plans.',
        style: TextStyle(
          fontSize: 11,
          color: secondaryText,
        ),
      ),
    );
  }

  Future<void> _deletePlan(
      BuildContext context,
      String planId,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove Plan?',
          ),
          content: const Text(
            'This trip plan will be removed from your saved plans.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('saved_trip_plans')
        .doc(planId)
        .delete();
  }

  static List<Map<String, dynamic>> _attractions(
      Map<String, dynamic> data,
      ) {
    final raw = data['attractions'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
      Map<String, dynamic>.from(item),
    )
        .toList();
  }

  static DateTime _createdAt(
      Map<String, dynamic> data,
      ) {
    final value = data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _travelStyleSummary(
      Map<String, dynamic> data,
      ) {
    final savedSummary =
    (data['travelStyleSummary'] ?? '')
        .toString()
        .trim();

    if (savedSummary.isNotEmpty) {
      return savedSummary;
    }

    final rawStyles = data['travelStyles'];

    if (rawStyles is List) {
      final styles = rawStyles
          .map(
            (item) => item.toString().trim(),
      )
          .where(
            (item) => item.isNotEmpty,
      )
          .toList();

      if (styles.isNotEmpty) {
        return styles.join(', ');
      }
    }

    return (data['travelStyle'] ?? '')
        .toString()
        .trim();
  }

  static String _dateSummary(
      Map<String, dynamic> data,
      ) {
    final saved =
    (data['dateSummary'] ?? '')
        .toString()
        .trim();

    if (saved.isNotEmpty) {
      return saved;
    }

    return 'Travel dates unavailable';
  }

  static double _sumEstimatedFees(
      List<Map<String, dynamic>> attractions,
      ) {
    double total = 0;

    for (final attraction in attractions) {
      total +=
          (attraction['estimatedFee'] as num?)
              ?.toDouble() ??
              0;
    }

    return total;
  }

  static String _money(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}

class SavedTripPlanDetailPage
    extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> data;

  const SavedTripPlanDetailPage({
    super.key,
    required this.planId,
    required this.data,
  });

  @override
  State<SavedTripPlanDetailPage>
  createState() =>
      _SavedTripPlanDetailPageState();
}

class _SavedTripPlanDetailPageState
    extends State<SavedTripPlanDetailPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color lightGreen =
  Color(0xFFE8F5E9);

  static const Color textColor =
  Color(0xFF212121);

  static const Color secondaryText =
  Color(0xFF777777);

  int selectedDay = 0;

  final TransportController _transportController =
  TransportController();
  final LocationService _locationService = const LocationService();
  Map<String, PlannedPlanLeg> _legsByKey = {};
  List<PlannedPlanLeg> _legs = [];
  Map<String, int> _legIndexByKey = {};
  bool _computingTransport = false;
  String? _transportError;

  static String _legKey(int day, String attractionName) =>
      '$day::$attractionName';

  @override
  void initState() {
    super.initState();
    _loadTransportLegs();
  }

  Future<void> _loadTransportLegs() async {
    List<PlannedPlanLeg>? legs;
    try {
      legs = await _transportController.getSavedTransportPlan(
        widget.planId,
      );
    } catch (error) {
      debugPrint(
        '[SavedTripPlanDetailPage] loading saved transport failed: '
            '$error',
      );
    }

    if (legs != null && legs.isNotEmpty) {
      if (!mounted) return;
      final loadedLegs = legs;
      setState(() {
        _legs = loadedLegs;
        _legsByKey = {
          for (final leg in loadedLegs)
            _legKey(leg.day, leg.attractionName): leg,
        };
        _legIndexByKey = {
          for (var i = 0; i < loadedLegs.length; i++)
            _legKey(loadedLegs[i].day, loadedLegs[i].attractionName): i,
        };
      });
      return;
    }

    // Nothing saved yet for this plan - most likely it was saved
    // before real transportation planning existed. Compute it now,
    // the same way GeneratedTripPage does for a freshly generated
    // trip, and save it so it's there next time too.
    if (!mounted) return;
    setState(() {
      _computingTransport = true;
      _transportError = null;
    });
    try {
      final plan =
      SavedTripPlan.fromFirestore(widget.planId, widget.data);
      if (plan.attractions.isEmpty) {
        if (!mounted) return;
        setState(() => _computingTransport = false);
        return;
      }

      final locationResult =
      await _locationService.detectCurrentLocation();
      if (!mounted) return;

      final startingFrom = locationResult.point;
      if (startingFrom == null) {
        setState(() {
          _computingTransport = false;
          _transportError =
          "Couldn't detect your current location, so real "
              'transportation routes could not be planned for this '
              'trip.';
        });
        return;
      }

      final computedLegs =
      await _transportController.planTransportationForPlan(
        plan,
        startingFrom: startingFrom,
      );
      if (!mounted) return;

      await _transportController.saveTransportPlan(
        widget.planId,
        computedLegs,
      );
      if (!mounted) return;

      setState(() {
        _legs = computedLegs;
        _legsByKey = {
          for (final leg in computedLegs)
            _legKey(leg.day, leg.attractionName): leg,
        };
        _legIndexByKey = {
          for (var i = 0; i < computedLegs.length; i++)
            _legKey(computedLegs[i].day, computedLegs[i].attractionName): i,
        };
        _computingTransport = false;
      });
    } catch (error) {
      debugPrint(
        '[SavedTripPlanDetailPage] computing transport failed: '
            '$error',
      );
      if (!mounted) return;
      setState(() {
        _computingTransport = false;
        _transportError = 'Could not plan transportation for this '
            'trip.';
      });
    }
  }

  void _openLegDetail(int index) {
    if (index < 0 || index >= _legs.length) return;
    final leg = _legs[index];
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
          onSaveEditedLeg: (editedOption) =>
              _saveEditedLeg(index, editedOption),
        ),
      ),
    );
  }

  Future<void> _persistLegs() async {
    try {
      await _transportController.saveTransportPlan(widget.planId, _legs);
    } catch (error) {
      debugPrint(
        '[SavedTripPlanDetailPage] re-saving transport plan failed: '
            '$error',
      );
    }
  }

  void _replaceLeg(int index, PlannedPlanLeg updated) {
    if (index < 0 || index >= _legs.length) return;

    final newLegs = List<PlannedPlanLeg>.from(_legs);
    newLegs[index] = updated;

    final newByKey = Map<String, PlannedPlanLeg>.from(_legsByKey);
    newByKey[_legKey(updated.day, updated.attractionName)] = updated;

    setState(() {
      _legs = newLegs;
      _legsByKey = newByKey;
    });
  }

  Future<void> _saveEditedLeg(int index, RideOption option) async {
    if (index < 0 || index >= _legs.length) return;
    final leg = _legs[index];
    final attraction = _attractionForLeg(leg);
    final plan = SavedTripPlan.fromFirestore(widget.planId, widget.data);
    final dayDate = DateTime.utc(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day + (leg.day - 1),
    );
    final openingAt = attraction?.openingDateTime(dayDate);
    final newVisitStart =
        (openingAt != null && option.arriveTime.isBefore(openingAt))
        ? openingAt
        : option.arriveTime;
    final visitMinutes =
        attraction?.recommendedVisitMinutes ??
        leg.visitEnd.difference(leg.visitStart).inMinutes;
    final newVisitEnd = newVisitStart.add(Duration(minutes: visitMinutes));

    // Editing this leg's transport can move its arrival time - shift
    // every later leg on the same day by the same amount so their
    // planned visit windows (and the routes leading to them) stay
    // consistent with the edit instead of silently going stale.
    final updatedLegs = applyEditedLegAndCascade(
      legs: _legs,
      editedIndex: index,
      newOption: option,
      newVisitStart: newVisitStart,
      newVisitEnd: newVisitEnd,
    );
    setState(() {
      _legs = updatedLegs;
      _legsByKey = {
        for (final updated in updatedLegs)
          _legKey(updated.day, updated.attractionName): updated,
      };
    });
    await _persistLegs();
  }

  /// Rebuilds the SavedTripPlanAttraction this leg was planned for, so
  /// retryPlanLeg can be called for just this one stop instead of
  /// recomputing the whole itinerary.
  SavedTripPlanAttraction? _attractionForLeg(PlannedPlanLeg leg) {
    final plan = SavedTripPlan.fromFirestore(widget.planId, widget.data);
    for (final attraction in plan.attractionsForDay(leg.day)) {
      if (attraction.name == leg.attractionName) return attraction;
    }
    return null;
  }

  Future<PlannedPlanLeg?> _applyRetriedLeg(
      int index,
      LocationPoint from,
      ) async {
    if (index < 0 || index >= _legs.length) return null;
    final leg = _legs[index];
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
        ? _legs[index - 1].visitEnd
        : leg.visitStart.subtract(const Duration(hours: 3));

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
      await _persistLegs();
      return updated;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $error')));
      return null;
    }
  }

  Future<PlannedPlanLeg?> _searchAndRetryLeg(
      int index,
      String query,
      ) async {
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
            "Couldn't get your location - search a starting point "
                'instead.',
          ),
        ),
      );
      return null;
    }
    return _applyRetriedLeg(index, point);
  }

  @override
  Widget build(BuildContext context) {
    final attractions =
    SavedTripPlansPage._attractions(
      widget.data,
    );

    final totalDays =
    ((widget.data['totalDays'] as num?)
        ?.toInt() ??
        1)
        .clamp(1, 365);

    final current = attractions.where(
          (item) {
        final day =
            (item['day'] as num?)
                ?.toInt() ??
                1;

        return day ==
            selectedDay + 1;
      },
    ).toList()
      ..sort(
            (a, b) =>
            _scheduleStart(a)
                .compareTo(
              _scheduleStart(b),
            ),
      );

    final state =
    (widget.data['selectedState'] ??
        'Trip Plan')
        .toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
          ),
        ),
        title: Text(
          '$state Trip',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditSavedTripPlanPage(
                    planId: widget.planId,
                    initialData: widget.data,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: mainGreen,
            ),
            label: const Text(
              'Edit',
              style: TextStyle(
                color: mainGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            26,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _summary(),
              if (_computingTransport) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: mainGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Planning real transportation for this '
                              'trip...',
                          style: TextStyle(
                            fontSize: 11,
                            color: mainGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_transportError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _transportError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9C6B00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount: totalDays,
                  separatorBuilder:
                      (_, __) =>
                  const SizedBox(
                    width: 7,
                  ),
                  itemBuilder:
                      (context, index) {
                    final selected =
                        selectedDay == index;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedDay = index;
                        });
                      },
                      borderRadius:
                      BorderRadius.circular(20),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 15,
                        ),
                        alignment:
                        Alignment.center,
                        decoration:
                        BoxDecoration(
                          color: selected
                              ? mainGreen
                              : Colors.white,
                          border: Border.all(
                            color: selected
                                ? mainGreen
                                : const Color(
                              0xFFE1E1E1,
                            ),
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          'Day ${index + 1}',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(
                              0xFF555555,
                            ),
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (current.isEmpty)
                const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 35,
                  ),
                  child: Center(
                    child: Text(
                      'No attractions for this day.',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(
                  current.length,
                      (index) =>
                      _timelineItem(
                        current[index],
                        index ==
                            current.length - 1,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final data = widget.data;

    final dateSummary =
    (data['dateSummary'] ?? '')
        .toString();

    final travelers =
    (data['travelerSummary'] ?? '')
        .toString();

    final style =
    SavedTripPlansPage
        ._travelStyleSummary(data);

    final budget =
        (data['budget'] as num?)
            ?.toDouble() ??
            0;

    final estimatedCost =
        (data['estimatedAttractionCost']
        as num?)
            ?.toDouble() ??
            SavedTripPlansPage
                ._sumEstimatedFees(
              SavedTripPlansPage
                  ._attractions(data),
            );

    final overBudget =
        budget > 0 &&
            estimatedCost > budget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          _summaryRow(
            Icons.calendar_today_outlined,
            dateSummary,
          ),
          const SizedBox(height: 7),
          _summaryRow(
            Icons.people_outline,
            travelers,
          ),
          const SizedBox(height: 7),
          _summaryRow(
            Icons.auto_awesome_outlined,
            style,
          ),
          const SizedBox(height: 7),
          _summaryRow(
            Icons
                .account_balance_wallet_outlined,
            'Est. Attraction Cost: '
                'RM ${SavedTripPlansPage._money(estimatedCost)} '
                '/ Budget RM ${SavedTripPlansPage._money(budget)}',
          ),
          const SizedBox(height: 8),
          Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              overBudget
                  ? 'Over budget by RM '
                  '${SavedTripPlansPage._money(estimatedCost - budget)}'
                  : 'Within budget • RM '
                  '${SavedTripPlansPage._money((budget - estimatedCost).clamp(0, double.infinity))} remaining',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight:
                FontWeight.w600,
                color: overBudget
                    ? const Color(
                  0xFFE65100,
                )
                    : mainGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      IconData icon,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: mainGreen,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.trim().isEmpty
                ? 'Not available'
                : value,
            style: const TextStyle(
              fontSize: 9.5,
              color: textColor,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timelineItem(
      Map<String, dynamic> attraction,
      bool last,
      ) {
    final legLookupKey = _legKey(
      selectedDay + 1,
      (attraction['name'] ?? '').toString(),
    );
    final leg = _legsByKey[legLookupKey];
    final legIndex = _legIndexByKey[legLookupKey];
    final legOption = leg?.option;

    // Prefer the real leg's own computed arrival time - it accounts
    // for actual travel time, unlike the old saved estimate.
    final start =
        leg?.visitStart ?? _timestamp(attraction['startTime']);

    final end =
    _timestamp(attraction['endTime']);

    final transportMinutes =
    (attraction[
    'transportMinutesBefore']
    as num?)
        ?.toInt();

    final distanceKm =
    (attraction[
    'distanceFromPreviousKm']
    as num?)
        ?.toDouble();

    final usedHere =
        attraction['usedHereRouting'] ==
            true;

    final visitMinutes =
    (attraction['visitMinutes']
    as num?)
        ?.toInt();

    final estimatedFee =
        (attraction['estimatedFee']
        as num?)
            ?.toDouble() ??
            0;

    final timeText =
    start == null
        ? '--:--'
        : _formatClock(start);

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            timeText,
            style: const TextStyle(
              fontSize: 8,
              color: Color(
                0xFF555555,
              ),
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
                  height: 165,
                  color: const Color(
                    0xFFAAAAAA,
                  ),
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
                if (legOption != null)
                  InkWell(
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
                            _dominantLegMode(legOption),
                            size: 12,
                            color: mainGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${formatDuration(legOption.totalDuration)}'
                                ' • '
                                '${legOption.co2Kg.toStringAsFixed(2)} kg CO2',
                            style: const TextStyle(
                              fontSize: 7.5,
                              color: mainGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _dominantLegMode(legOption).label,
                            style: const TextStyle(
                              fontSize: 6.5,
                              color: secondaryText,
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
                  )
                else if (transportMinutes != null &&
                    transportMinutes > 0)
                  Container(
                    margin:
                    const EdgeInsets.only(
                      bottom: 7,
                    ),
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF5F7F5,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .directions_car_outlined,
                          size: 12,
                          color: mainGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$transportMinutes min'
                              '${distanceKm == null ? '' : ' • ${distanceKm.toStringAsFixed(1)} km'}',
                          style:
                          const TextStyle(
                            fontSize: 7.5,
                            color: mainGreen,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          usedHere
                              ? 'HERE'
                              : 'estimated',
                          style:
                          const TextStyle(
                            fontSize: 6.5,
                            color:
                            secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                _savedAttractionCard(
                  attraction,
                  start:
                  start,
                  end:
                  end,
                  visitMinutes:
                  visitMinutes,
                  estimatedFee:
                  estimatedFee,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _savedAttractionCard(
      Map<String, dynamic> attraction, {
        required DateTime? start,
        required DateTime? end,
        required int? visitMinutes,
        required double estimatedFee,
      }) {
    String image =
    (attraction['coverImageUrl'] ?? '')
        .toString()
        .trim();

    if (image.isEmpty) {
      final images =
      attraction['imageUrls'];

      if (images is List &&
          images.isNotEmpty) {
        image = images.first
            .toString()
            .trim();
      }
    }

    final name =
    (attraction['name'] ?? '')
        .toString();

    final area =
    (attraction['area'] ?? '')
        .toString();

    final state =
    (attraction['state'] ?? '')
        .toString();

    final tags =
    _categoryTags(attraction);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _openAttractionDetail(
              attraction,
            ),
        borderRadius:
        BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(10),
            border: Border.all(
              color: const Color(
                0xFFE5E8E5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 112,
                  child: image.isEmpty
                      ? Container(
                    color: lightGreen,
                    child:
                    const Icon(
                      Icons
                          .landscape_outlined,
                      color: mainGreen,
                    ),
                  )
                      : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                        Container(
                          color:
                          lightGreen,
                          child:
                          const Icon(
                            Icons
                                .landscape_outlined,
                            color:
                            mainGreen,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              textColor,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons
                              .chevron_right_rounded,
                          size: 18,
                          color:
                          secondaryText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [area, state]
                          .where(
                            (e) =>
                        e.trim()
                            .isNotEmpty,
                      )
                          .join(', '),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 8,
                        color: mainGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      start != null &&
                          end != null
                          ? '${_formatClock(start)} - ${_formatClock(end)}'
                          '${visitMinutes == null ? '' : ' • $visitMinutes min visit'}'
                          : 'Saved before timeline data was available',
                      style:
                      const TextStyle(
                        fontSize: 8,
                        color:
                        secondaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      attraction[
                      'isFreeEntry'] ==
                          true
                          ? 'Free Entry'
                          : 'Estimated Fee: RM ${SavedTripPlansPage._money(estimatedFee)}',
                      style:
                      const TextStyle(
                        fontSize: 8,
                        color:
                        secondaryText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags
                          .map(
                            (tag) =>
                            _categoryChip(
                              tag,
                            ),
                      )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAttractionDetail(
      Map<String, dynamic> saved,
      ) async {
    final attractionId =
    (saved['id'] ?? '')
        .toString()
        .trim();

    if (attractionId.isEmpty) {
      _showMessage(
        'Attraction details are unavailable.',
      );
      return;
    }

    try {
      final snapshot =
      await FirebaseFirestore.instance
          .collection('attractions')
          .doc(attractionId)
          .get();

      if (!mounted) return;

      if (!snapshot.exists) {
        _showMessage(
          'This attraction is no longer available.',
        );
        return;
      }

      final attraction =
      AttractionModel.fromFirestore(
        snapshot,
      );

      final estimatedFee =
          (saved['estimatedFee'] as num?)
              ?.toDouble() ??
              0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AttractionDetailPage(
                attraction: attraction,
                estimatedFee:
                estimatedFee,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to load attraction details.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mainGreen,
      ),
    );
  }

  List<String> _categoryTags(
      Map<String, dynamic> attraction,
      ) {
    final result = <String>{};

    final raw =
    attraction['categoryNames'];

    if (raw is List) {
      for (final item in raw) {
        final value =
        item.toString().trim();

        if (value.isNotEmpty) {
          result.add(value);
        }
      }
    }

    final primary =
    (attraction['categoryName'] ?? '')
        .toString()
        .trim();

    if (primary.isNotEmpty) {
      result.add(primary);
    }

    return result.isEmpty
        ? ['Attraction']
        : result.toList();
  }

  Widget _categoryChip(
      String value,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFC8E6C9,
          ),
          width: 0.7,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 7,
          color: mainGreen,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  DateTime _scheduleStart(
      Map<String, dynamic> attraction,
      ) {
    return _timestamp(
      attraction['startTime'],
    ) ??
        DateTime(
          2999,
          1,
          1,
        );
  }

  DateTime? _timestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
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
}
