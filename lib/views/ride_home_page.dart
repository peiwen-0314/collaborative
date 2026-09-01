import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/api_config.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../services/location_service.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/journey_card.dart';
import '../widgets/ride_card.dart';
import 'saved_list_page.dart';
import 'trip_details_page.dart';
import 'ai_trip_planner_page.dart';
import 'home_page.dart';

class TransportationPage extends StatefulWidget {
  const TransportationPage({super.key});

  @override
  State<TransportationPage> createState() => _TransportationPageState();
}

class _TransportationPageState extends State<TransportationPage> {
  final TransportController _controller = TransportController();
  /// Null while we're still detecting the user's current location.
  LocationPoint? _from;

  /// Null until the user picks a destination. Ride options and the
  /// inline Saved List only show once one of these two states resolves -
  /// see `_buildResultsSection` / the destination prompt in `build`.
  LocationPoint? _to;

  late DateTime _departAt;

  /// True as long as `_from` was set automatically and the user hasn't
  /// overridden it - so a slow location fix doesn't clobber a manual pick.
  bool _fromIsAutoDetected = true;

  /// Shown in the "From" field while `_from` is null - either because
  /// detection is still running, or because it failed/was denied and we're
  /// deliberately leaving it blank for the user to fill in themselves.
  String _fromPlaceholder = 'Detecting your location…';

  bool _loading = false;
  String? _error;
  List<RideOption> _rideOptions = const [];
  bool _isLiveData = false;

  List<SavedTrip> _savedPreview = const [];

  // Null until a real recommendation has loaded (or none could be found) -
  // see _loadRecommendation/RecommendedPanel below. Also reachable after a
  // search via the header shortcut (see _showRecommendedSheet), since the
  // panel itself is normally replaced by the results list once a
  // destination is picked.
  RecommendedRide? _recommended;

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
      setState(() => _from = result.point);
      _search();
      _loadRecommendation();
      return;
    }

    if (result.status == LocationLookupStatus.permissionDenied ||
        result.status == LocationLookupStatus.serviceDisabled) {
      // Respect the user's choice - don't guess a starting point for them,
      // just leave "From" (and "To", already blank) empty so they can pick
      // manually.
      setState(() => _fromPlaceholder = 'Tap to select your location');
      _showLocationFallbackNotice(result.status);
      return;
    }

    // Never invent a fixed origin. A failed GPS lookup leaves the field
    // empty so the user can retry or choose a real searched place.
    setState(() => _fromPlaceholder = 'Tap to select your location');
    _showLocationFallbackNotice(result.status);
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
      _loading = true;
      _error = null;
    });
    try {
      // TransportController.searchRides already ranks the results with the
      // trained RouteRecommender model and badges the top pick - see that
      // method's doc comment (and train_route_recommender.py) for what
      // "trained" means here.
      final result = await _controller.searchRides(
        from: from,
        to: to,
        departAt: _departAt,
      );
      if (!mounted) return;
      setState(() {
        _rideOptions = result.options;
        _isLiveData = result.isLive;
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
    setState(() => _savedPreview = all.take(3).toList());
  }

  /// Best-effort only - see TransportController.recommendedRideTo's doc
  /// comment. A null result (or an exception) just means _recommended
  /// stays/becomes null, which hides both the inline panel and the
  /// header shortcut - never shown as an error to the person, since
  /// there was never a "recommendation" action they took that failed.
  Future<void> _loadRecommendation() async {
    final from = _from;
    if (from == null) return;
    try {
      final recommended = await _controller.recommendedRideTo(from);
      if (!mounted) return;
      setState(() => _recommended = recommended);
    } catch (error) {
      debugPrint('[TransportationPage] recommendation load failed: $error');
    }
  }

  /// Fills "To" with the recommended destination and runs a fresh search
  /// to it - same as tapping any real place suggestion, whether this was
  /// reached from the inline panel (before a search) or the header
  /// shortcut's bottom sheet (after one) - see _showRecommendedSheet.
  void _selectRecommended(RecommendedRide recommended) {
    setState(() => _to = recommended.to);
    _search();
  }

  /// Re-opens the "Recommended For You" panel after a search, since it's
  /// normally hidden once a destination is picked (replaced by the
  /// results list) and there's no "back" step that brings it back on its
  /// own - see the header's lightbulb button in build().
  void _showRecommendedSheet() {
    final recommended = _recommended;
    if (recommended == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          top: false,
          child: RecommendedPanel(
            option: recommended.option,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _selectRecommended(recommended);
            },
          ),
        ),
      ),
    );
  }

  void _swap() {
    if (_from == null || _to == null) return;
    setState(() {
      final temp = _from!;
      _from = _to;
      _to = temp;
      _fromIsAutoDetected = false;
    });
    _search();
    _loadRecommendation();
  }

  void _handleFromSelected(LocationPoint point) {
    setState(() {
      _from = point;
      _fromIsAutoDetected = false;
    });
    _search();
    _loadRecommendation();
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
    });
    _search();
  }

  void _openDetails(RideOption option) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(from: from, to: to, option: option),
      ),
    )
        .then((_) => _loadSavedPreview());
  }

  void _openSavedTrip(SavedTrip trip) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TripDetailsPage(
          from: trip.from,
          to: trip.to,
          option: trip.option,
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
                        Image.asset(AppAssets.logo, width: 148, height: 42),
                        const Spacer(),
                        // Only appears once a real recommendation has
                        // loaded (see _loadRecommendation) - lets a
                        // person reopen "Recommended For You" after
                        // they've already picked a destination, since
                        // the inline panel below is replaced by the
                        // results list at that point and there's no
                        // "back" step that brings it back on its own.
                        if (_recommended != null)
                          IconButton(
                            onPressed: _showRecommendedSheet,
                            tooltip: 'Recommended for you',
                            icon: const Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.green,
                            ),
                          ),
                        IconButton(
                          onPressed: _openSavedList,
                          tooltip: 'Saved trips',
                          icon: const Icon(
                            Icons.bookmark_border_rounded,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose Your Ride',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Compare the best transportation options for your journey.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    JourneyCard(
                      from: _from,
                      to: _to,
                      fromPlaceholder: _fromPlaceholder,
                      onFromSelected: _handleFromSelected,
                      onToSelected: _handleToSelected,
                      onSwap: _swap,
                    ),
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DateChip(dateTime: _departAt, onTap: _pickDate),
                    ),
                    const SizedBox(height: 14),
                    if (hasDestination)
                      ..._buildResultsSection()
                    else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Search for a real destination above to see ride options.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (_recommended != null) ...[
                        RecommendedPanel(
                          option: _recommended!.option,
                          onTap: () => _selectRecommended(_recommended!),
                        ),
                        const SizedBox(height: 14),
                      ],
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
        onCommunityTap: () {
          _showComingSoon('Community');
        },
        onProfileTap: () {
          _showComingSoon('Profile');
        },
      ),
    );
  }

  List<Widget> _buildResultsSection() {
    if (_from == null) {
      // Can happen for a while after denying location permission - "To" is
      // already picked, but there's still no starting point to search
      // from. Say so instead of spinning forever with no explanation.
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
              OutlinedButton(onPressed: _search, child: const Text('Retry')),
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
      if (!_isLiveData) const _SimulatedDataBanner(),
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
    return [
      for (final trip in _savedPreview) ...[
        Text(
          '${trip.from.name}  --->  ${trip.to.name}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        RideCard(option: trip.option, onTap: () => _openSavedTrip(trip)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// The "Recommended For You" panel, shown only while no destination has
/// been picked yet (alongside the Saved List) - matches the original
/// design (a featured ride card in a pale-green panel), not a bare list.
/// Tapping it fills in "To" with the suggested destination and runs the
/// search immediately.
///
/// [option] is generated by [TransportController.recommendedRideTo] using
/// the same offline generator the rest of the app falls back to - a
/// placeholder until the travel-plan module a teammate is building can
/// supply a real pick.
/// Shown above the ride options whenever they came from the offline mock
/// generator instead of the live HERE API - which is what happens by
/// default, since [ApiConfig.hasHereApiKey] is false unless the app was
/// built/run with a real key. Made deliberately hard to miss (unlike the
/// small grey footnote this replaces) because the times, waits, and even
/// which vehicles are "available" below are an estimate, not a real
/// timetable, until a key is configured.
class _SimulatedDataBanner extends StatelessWidget {
  const _SimulatedDataBanner();


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Simulated routes - no live HERE API key is set up, so these '
                  'times and waits are an estimate, not a real timetable. Run '
                  'with --dart-define=HERE_API_KEY=... for real schedules.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.text,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendedPanel extends StatelessWidget {
  const RecommendedPanel({
    super.key,
    required this.option,
    required this.onTap,
  });

  final RideOption option;
  final VoidCallback onTap;


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
          const Text(
            'Recommended For you',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const Text(
            'Based on your travel plan and preferences.',
            style: TextStyle(fontSize: 8, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          RideCard(option: option, onTap: onTap, featured: true),
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
