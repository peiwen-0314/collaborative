import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../services/location_service.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/journey_card.dart';
import '../widgets/ride_card.dart';
import '../widgets/travel_preferences_sheet.dart';
import 'saved_list_page.dart';
import 'trip_details_page.dart';
import 'ai_trip_planner_page.dart';
import 'home_page.dart';
import 'community_feed_page.dart';
import 'profile_page.dart';

class TransportationPage extends StatefulWidget {
  const TransportationPage({super.key});

  @override
  State<TransportationPage> createState() => _TransportationPageState();
}

class _TransportationPageState extends State<TransportationPage> {
  final TransportController _controller = TransportController();
  /// Null while we're still detecting the user's current location.
  LocationPoint? _from;

  LocationPoint? _to;

  late DateTime _departAt;

  /// True until the person explicitly picks a date/time via _pickDate -
  /// see _search's own doc comment for the bug this exists to prevent.
  bool _departAtIsAutoNow = true;

  /// True as long as `_from` was set automatically and the user hasn't
  /// overridden it - so a slow location fix doesn't clobber a manual pick.
  bool _fromIsAutoDetected = true;

  String _fromPlaceholder = 'Detecting your location…';

  bool _loading = false;
  String? _error;

  bool _outsideMalaysia = false;

  bool _shownOutsideMalaysiaNotice = false;
  List<RideOption> _rideOptions = const [];

  List<SavedTrip> _savedPreview = const [];

  List<SavedTrip> _allSavedTrips = const [];

  TodaysTransportStatus? _status;

  bool _recommendationLoading = true;

  bool get _hasUsableStatus {
    final status = _status;
    if (status == null) return false;
    if (status.isAlreadyPlanned) {
      final leg = status.plannedLeg;
      return leg != null && leg.to != null && leg.option != null;
    }
    return status.suggestion != null;
  }

  @override
  void initState() {
    super.initState();
    _departAt = DateTime.now();
    _initializeTransportation();
  }

  Future<void> _initializeTransportation() async {
    await ApiConfig.ensureLoaded();
    if (!mounted) return;
    await Future.wait([_detectFromLocation(), _loadSavedPreview()]);
  }

  Future<void> _detectFromLocation() async {
    final result = await _controller.detectCurrentLocation();
    if (!mounted || !_fromIsAutoDetected) return;

    if (result.status == LocationLookupStatus.success && result.point != null) {
      final point = result.point!;
      setState(() => _from = point);

      if (!isInMalaysia(point)) {
        setState(() {
          _outsideMalaysia = true;
          _recommendationLoading = false;
        });
        _showOutsideMalaysiaNoticeOnce();
        _recomputeSavedPreview();
        return;
      }

      setState(() {
        _outsideMalaysia = false;
        _recommendationLoading = true;
      });
      _search();
      _loadRecommendation();
      _recomputeSavedPreview();
      return;
    }

    if (result.status == LocationLookupStatus.permissionDenied ||
        result.status == LocationLookupStatus.serviceDisabled) {
      setState(() {
        _fromPlaceholder = 'Tap to select your location';
        _recommendationLoading = false;
      });
      _showLocationFallbackNotice(result.status);
      return;
    }

    // Never invent a fixed origin. A failed GPS lookup leaves the field
    // empty so the user can retry or choose a real searched place.
    setState(() {
      _fromPlaceholder = 'Tap to select your location';
      _recommendationLoading = false;
    });
    _showLocationFallbackNotice(result.status);
  }

  void _showOutsideMalaysiaNoticeOnce() {
    if (_shownOutsideMalaysiaNotice || !mounted) return;
    _shownOutsideMalaysiaNotice = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This transportation feature is only available for locations '
          'in Malaysia.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _retryDetectLocation() {
    _fromIsAutoDetected = true;
    setState(() => _fromPlaceholder = 'Detecting your location…');
    _detectFromLocation();
  }

  void _showLocationFallbackNotice(LocationLookupStatus status) {
    if (!mounted) return;

    final message = switch (status) {
      LocationLookupStatus.permissionDenied =>
      'Location permission denied - tap "From" to pick your starting point.',

      LocationLookupStatus.serviceDisabled =>
      'Location services are off - tap "From" to pick your starting point.',

      _ =>
      "Couldn't get an accurate GPS fix - tap From to search a real place.",
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _search() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;

    setState(() {
      if (_departAtIsAutoNow) _departAt = DateTime.now();
      _loading = true;
      _error = null;
    });
    try {
      final result = await _controller.searchRides(
        from: from,
        to: to,
        departAt: _departAt,
      );
      if (!mounted) return;
      setState(() {
        _rideOptions = result.options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rideOptions = const [];
        _loading = false;
        _error = 'Could not load rides for this trip. Please try again.';
      });
    }
  }

  Future<void> _loadSavedPreview() async {
    final all = await _controller.getSavedTrips();
    if (!mounted) return;
    _allSavedTrips = all;
    _recomputeSavedPreview();
  }

  static const double _nearbyMatchKm = 5.0;

  void _recomputeSavedPreview() {
    final from = _from;
    List<SavedTrip> picked;
    if (from == null || _allSavedTrips.isEmpty) {
      picked = _allSavedTrips.take(3).toList();
    } else {
      final nearby = _allSavedTrips
          .where((trip) => from.distanceKm(trip.from) <= _nearbyMatchKm)
          .toList()
        ..sort(
          (a, b) =>
              from.distanceKm(a.from).compareTo(from.distanceKm(b.from)),
        );
      picked = nearby.isNotEmpty
          ? nearby.take(3).toList()
          : _allSavedTrips.take(3).toList();
    }
    if (!mounted) return;
    setState(() => _savedPreview = picked);
  }

  Future<void> _loadRecommendation() async {
    final from = _from;
    if (from == null) {
      if (mounted) setState(() => _recommendationLoading = false);
      return;
    }
    try {
      final status = await _controller.todaysTransportStatus(from);
      if (!mounted) return;
      setState(() {
        _status = status;
        _recommendationLoading = false;
      });
    } catch (error) {
      debugPrint('[TransportationPage] recommendation load failed: $error');
      if (!mounted) return;
      setState(() => _recommendationLoading = false);
    }
  }

  void _selectRecommended(RecommendedRide recommended) {
    final from = _from;
    if (from == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: from,
          to: recommended.to,
          option: recommended.option,
        ),
      ),
    );
  }

  void _openPlannedRide(PlannedPlanLeg leg) {
    final to = leg.to;
    final option = leg.option;
    if (to == null || option == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: leg.from,
          to: to,
          option: option,
          allowTimeChange: true,
        ),
      ),
    );
  }

  void _swap() {
    if (_from == null && _to == null) return;
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
      _fromIsAutoDetected = false;
      _recommendationLoading = true;
    });
    _search();
    _loadRecommendation();
    _recomputeSavedPreview();
  }

  void _handleFromSelected(LocationPoint point) {
    setState(() {
      _from = point;
      _fromIsAutoDetected = false;
      _recommendationLoading = true;
    });
    _search();
    _loadRecommendation();
    _recomputeSavedPreview();
  }

  void _handleToSelected(LocationPoint point) {
    setState(() => _to = point);
    _search();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departAt),
    );
    if (time == null) return;

    setState(() {
      _departAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _departAtIsAutoNow = false;
    });
    _search();
  }

  void _openDetails(RideOption option) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    unawaited(_controller.recordOptionSelection(option, _rideOptions));
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(from: from, to: to, option: option),
      ),
    )
        .then((_) => _loadSavedPreview());
  }

  Future<void> _openTravelPreferences() async {
    await TravelPreferencesSheet.show(context, _controller);
    if (!mounted) return;
    if (_from != null && _to != null) {
      unawaited(_search());
    } else {
      // No active from/to search - refresh the Recommended panel
      // instead, now that saveTravelPreferences() has cleared its
      // cache, so it re-scores under the preferences just changed
      // rather than keep showing the pre-change suggestion.
      setState(() => _recommendationLoading = true);
      unawaited(_loadRecommendation());
    }
  }

  void _openSavedTrip(SavedTrip trip) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: trip.from,
          to: trip.to,
          option: trip.option,
          isSavedTrip: true,
        ),
      ),
    )
        .then((_) => _loadSavedPreview());
  }

  void _openSavedList() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SavedListPage()))
        .then((_) => _loadSavedPreview());
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
    );
  }

  void _goPlanTrip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AiTripPlannerPage(),
      ),
    );
  }

  void _goCommunity() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CommunityFeedPage(),
      ),
    );
  }

  void _showComingSoon(String page) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$page coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDestination = _to != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _search();
            await _loadSavedPreview();
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-7, 0),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 55,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _openSavedList,
                          tooltip: 'Saved trips',
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            color: AppColors.green,
                          ),
                        ),
                        // Opens TravelPreferencesSheet - see
                        // _openTravelPreferences' own doc comment.
                        IconButton(
                          onPressed: _openTravelPreferences,
                          tooltip: 'Travel Preferences',
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose Your Ride',
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.1,
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    JourneyCard(
                      from: _from,
                      to: _to,
                      fromPlaceholder: _fromPlaceholder,
                      onFromSelected: _handleFromSelected,
                      onToSelected: _handleToSelected,
                      onSwap: _swap,
                    ),
                    if (_from == null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _retryDetectLocation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: const BorderSide(color: AppColors.green),
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          icon: const Icon(Icons.my_location, size: 15),
                          label: const Text(
                            'Detect My Location',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DateChip(dateTime: _departAt, onTap: _pickDate),
                    ),
                    const SizedBox(height: 14),
                    if (!_outsideMalaysia &&
                        _hasUsableStatus &&
                        !hasDestination) ...[
                      _status!.isAlreadyPlanned
                          ? RecommendedPanel(
                              to: _status!.plannedLeg!.to!,
                              option: _status!.plannedLeg!.option!,
                              alreadyPlanned: true,
                              onTap: () =>
                                  _openPlannedRide(_status!.plannedLeg!),
                            )
                          : RecommendedPanel(
                              to: _status!.suggestion!.to,
                              option: _status!.suggestion!.option,
                              onTap: () =>
                                  _selectRecommended(_status!.suggestion!),
                            ),
                      const SizedBox(height: 14),
                    ],
                    if (!_outsideMalaysia && hasDestination)
                      ..._buildResultsSection()
                    else if (_outsideMalaysia) ...[
                      SectionHeading(
                        title: 'Saved List',
                        onTap: _openSavedList,
                      ),
                      const SizedBox(height: 8),
                      ..._buildSavedPreviewSection(),
                    ]
                    else if (_recommendationLoading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ]
                    else if (!_hasUsableStatus) ...[
                      SectionHeading(
                        title: 'Saved List',
                        onTap: _openSavedList,
                      ),
                      const SizedBox(height: 8),
                      ..._buildSavedPreviewSection(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 1,
        onHomeTap: _goHome,
        onTransportTap: () {
          // Already on Transportation page.
        },
        onPlanTripTap: _goPlanTrip,
        onCommunityTap: _goCommunity,
        onProfileTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfilePage(),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildResultsSection() {
    if (_from == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Please also set your starting point above (tap "From").',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ];
    }

    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _search,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }

    if (_rideOptions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No routes found for this trip yet.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ];
    }

    return [
      for (final option in _rideOptions) ...[
        RideCard(option: option, onTap: () => _openDetails(option)),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _buildSavedPreviewSection() {
    if (_savedPreview.isEmpty) {
      return const [
        Text(
          'No saved trips yet. Tap the heart icon on a trip to save it here.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ];
    }
    final groups = groupSavedTrips(_savedPreview);
    return [
      for (final group in groups) ...[
        Tooltip(
          message: '${group.from.name}  →  ${group.to.name}',
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 3),
          child: Text(
            '${shortPlaceName(group.from.name)}  →  ${shortPlaceName(group.to.name)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 5),
        for (final trip in group.trips) ...[
          RideCard(
            option: trip.option,
            onTap: () => _openSavedTrip(trip),
            showWaitWarning: false,
          ),
          const SizedBox(height: 10),
        ],
      ],
    ];
  }
}

class RecommendedPanel extends StatelessWidget {
  const RecommendedPanel({
    super.key,
    required this.to,
    required this.option,
    required this.onTap,
    this.alreadyPlanned = false,
  });

  final LocationPoint to;
  final RideOption option;
  final VoidCallback onTap;

  final bool alreadyPlanned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alreadyPlanned
                ? "Today's Ride Is Planned"
                : 'Recommended For you',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 13,
                color: AppColors.green,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: to.name,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    shortPlaceName(to.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RideCard(
            option: option,
            onTap: onTap,
            featured: true,
            showElapsedFromSearch: !alreadyPlanned,
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
