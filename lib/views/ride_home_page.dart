import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../services/location_service.dart';
import '../widgets/eco_bottom_navigation.dart';
import '../widgets/journey_card.dart';
import '../widgets/ride_card.dart';
import 'saved_list_page.dart';
import 'trip_details_page.dart';
import 'trip_plans_page.dart';
import 'ai_trip_planner_page.dart';
import 'home_page.dart';
import 'community_feed_page.dart';

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

  /// True once a detected "From" has landed outside both of
  /// isInMalaysia's bounding boxes - this app only has real transit
  /// data for Malaysia's own operators, so there's nothing real to
  /// search for from anywhere else. Gates `build` straight to the Saved
  /// List (see `_hasUsableStatus`/`hasDestination` below, both left
  /// false on purpose whenever this is true - see
  /// `_detectFromLocation`) instead of running a real search or
  /// recommendation lookup that could only ever come back empty.
  bool _outsideMalaysia = false;

  /// True once the "only available in Malaysia" notice has been shown
  /// for this page instance - shown at most once (see
  /// `_showOutsideMalaysiaNoticeOnce`) rather than every single time
  /// `_detectFromLocation` re-runs (a manual "Detect My Location" retry,
  /// a swap, ...) and lands outside Malaysia again.
  bool _shownOutsideMalaysiaNotice = false;
  List<RideOption> _rideOptions = const [];

  List<SavedTrip> _savedPreview = const [];

  /// Every saved trip, as last fetched (already newest-saved-first - see
  /// SavedTripsStore.getAll) - kept around so [_recomputeSavedPreview]
  /// can re-rank [_savedPreview] whenever `_from` changes without a
  /// fresh Firestore read each time.
  List<SavedTrip> _allSavedTrips = const [];

  // Null until today's transport status has loaded (or none could be
  // found, e.g. no saved trip plan is running today) - see
  // _loadRecommendation/RecommendedPanel below. This inline panel is
  // separate from the header's "My Trip Plans" shortcut (_openTripPlans)
  // - that one lists every upcoming plan, not just today's single pick,
  // and stays visible even when this is null. Either wraps a
  // [RecommendedRide] (nothing planned yet - the original
  // "recommendation" behaviour) or a [PlannedPlanLeg] (the person
  // already planned and saved today's ride - see
  // TransportController.todaysTransportStatus's doc comment).
  TodaysTransportStatus? _status;

  /// True until we know for sure whether there is (or isn't) something
  /// to put in [_status] - i.e. until [_loadRecommendation] actually
  /// finishes, or we've hit a state where it will never even be called
  /// (no [_from] yet, location permission denied/disabled, or
  /// [_outsideMalaysia]). `build` uses this to hold off on the Saved
  /// List while this is still true, instead of showing it and then
  /// immediately replacing it with a "Recommended For You"/"Today's
  /// Plan" panel the moment the real answer comes back - which used to
  /// read as the page changing its mind right in front of the person.
  bool _recommendationLoading = true;

  /// Whether [_status] actually has something displayable - the
  /// "already planned" branch can carry a leg whose [to]/[option] came
  /// back null (its own transportation couldn't be planned - see
  /// PlannedPlanLeg's doc comment), which has nothing to show here.
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
        // Not _search()/_loadRecommendation() - there's no real transit
        // data for outside Malaysia to search anyway, so `build` just
        // falls through to the Saved List instead (see
        // `_outsideMalaysia`'s own doc comment).
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
      // Respect the user's choice - don't guess a starting point for them,
      // just leave "From" (and "To", already blank) empty so they can pick
      // manually. No `_from` means `_loadRecommendation` will never run,
      // so there's nothing left to wait for either.
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

  /// See `_outsideMalaysia`'s own doc comment - shown at most once per
  /// page instance, same "don't spam it every retry" reasoning as
  /// `_shownOutsideMalaysiaNotice`.
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

  /// Lets the person explicitly ask for their location again - the only
  /// way back to a real auto-detected "From" once detection has failed
  /// (permission denied, GPS off, a failed lookup) or landed outside
  /// Malaysia, short of typing a place by hand every time. Forces
  /// `_fromIsAutoDetected` back on first, since `_detectFromLocation`
  /// itself is a no-op once that's false (e.g. after a manual "From"
  /// pick) - so this doubles as "go back to auto-detecting", not only
  /// "try again after a failure".
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

  /// How close a saved trip's own starting point has to be to `_from`
  /// to count as "matches where the person is right now", rather than
  /// just happening to be the nearest of a bunch of far-away trips -
  /// same bucket ai_trip_planner_controller.dart already treats as
  /// genuinely nearby.
  static const double _nearbyMatchKm = 5.0;

  /// Picks at most 3 of [_allSavedTrips] to preview here on the home
  /// page - see this class's own doc comment on `_savedPreview` for why
  /// this is a small, different-purpose preview from the full Saved
  /// List page. Prefers trips that actually start near `_from` (nearest
  /// first, within [_nearbyMatchKm]) since a bookmark for a journey the
  /// person isn't near right now isn't a useful shortcut; only once
  /// there's genuinely no nearby match (or `_from` itself isn't known
  /// yet) does this fall back to the plain 3 most recently saved -
  /// [_allSavedTrips] is already sorted that way.
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

  /// Best-effort only - see TransportController.todaysTransportStatus's
  /// doc comment. A null result (or an exception) just means _status
  /// stays/becomes null, which hides the inline panel - never shown as
  /// an error to the person, since there was never a "recommendation"
  /// action they took that failed.
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

  /// Opens the real detail page for today's recommended ride directly -
  /// [recommended.option] is already the best real route
  /// TransportController.todaysTransportStatus found for it, so tapping
  /// this shows that route's own detail page straight away, same as
  /// [_openPlannedRide] does for an already-planned leg, instead of
  /// filling "To" and re-running a fresh search that would hand back a
  /// whole list of alternatives to choose between again - the
  /// recommendation IS the pick. Only ever reached when nothing's been
  /// planned for today yet (see TodaysTransportStatus.suggestion) - the
  /// header shortcut opens a full page (see _openTripPlans) instead of a
  /// preview card, so it doesn't call this.
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

  /// Opens the real ride the person already planned and saved for today
  /// (TodaysTransportStatus.alreadyPlanned) - shows the exact real route
  /// that was already saved via PlanTransportPage, same direct-to-detail
  /// shape [_selectRecommended] now uses for a plain suggestion too.
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

  /// Opens the full "My Trip Plans" list (TripPlansPage) - every
  /// upcoming/ongoing saved trip plan, not just today's single pick.
  /// Replaces the old lightbulb bottom-sheet shortcut (which only ever
  /// showed one "today" recommendation and had nowhere to go from
  /// there) with a real page, styled like SavedListPage, that a person
  /// can browse - and from a plan there, plan transportation for the
  /// whole trip (see PlanTransportPage), not just one destination.
  void _openTripPlans() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TripPlansPage()));
  }

  /// Swaps whatever is in "From" and "To" - previously a no-op unless
  /// BOTH were already filled in, which made the swap icon look
  /// perfectly tappable while actually doing nothing the moment either
  /// field was still empty (e.g. right after auto-detecting "From" but
  /// before typing a destination - exactly the common case). Only truly
  /// nothing to swap when NEITHER field has a value yet; every other
  /// combination is a real swap, including one side ending up null -
  /// _search/_loadRecommendation/_recomputeSavedPreview all already
  /// handle a null "From" or "To" on their own (they just don't run the
  /// part that needs it), so nothing extra needs guarding here.
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
      // Color(0xFFF8FAF8) - the exact same value HomePage.pageBackground
      // uses (lib/views/home_page.dart) for its own Scaffold, at the
      // person's own request to match it here. This page had no
      // backgroundColor override at all before, so it was falling back
      // to the app theme's plain Colors.white (see buildAppTheme's
      // scaffoldBackgroundColor) - close to HomePage's near-white tint
      // but not quite it, hence the visible mismatch between the two
      // tabs. Hardcoded here (matching HomePage's own approach) rather
      // than pulled from a shared constant, since HomePage isn't part
      // of this module.
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
                        Image.asset(
                          AppAssets.logo,
                          height: 55,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        // Always visible - unlike the old lightbulb
                        // shortcut, this doesn't depend on today
                        // specifically having a recommendation (see
                        // _openTripPlans/TripPlansPage, which shows its
                        // own empty state when there's nothing upcoming
                        // yet, the same way the bookmark icon below
                        // does for an empty Saved List).
                        IconButton(
                          onPressed: _openTripPlans,
                          tooltip: 'My Trip Plans',
                          icon: const Icon(
                            Icons.event_note_outlined,
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
                      style: Theme.of(
                        context,
                     ).textTheme.headlineSmall?.copyWith(fontSize: 19),
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
                    // No real "From" yet - either detection hasn't
                    // resolved anything (denied/disabled/failed - see
                    // _showLocationFallbackNotice) or the person picked
                    // it away manually and wants auto-detection back.
                    // Typing a place by hand still works via the field
                    // itself, but this is the explicit "try detecting
                    // again" the person can reach for either way.
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
                    // Shown regardless of hasDestination - unlike before,
                    // this doesn't disappear the moment a destination is
                    // typed (that used to need the old lightbulb
                    // bottom-sheet shortcut, which read as an ugly extra
                    // drawer - see _openTripPlans' doc comment for what
                    // that button became instead). Pre-search it's the
                    // full featured panel; once results replace the rest
                    // of this section, it shrinks to a compact pinned
                    // card so it never gets confused for one of the
                    // actual search results below it.
                    // Never shown while `_outsideMalaysia` is true (see its
                    // own doc comment) - `_status`/`_to` should already
                    // be null/unset in that state (_detectFromLocation
                    // skips loading either), but this is the explicit,
                    // can't-drift-out-of-sync guard rather than relying
                    // on that alone.
                    // Only shown pre-search (hasDestination false) - at
                    // the person's own request, this no longer shrinks
                    // to a pinned card once a destination is typed and
                    // real search results take over below (see
                    // _buildResultsSection): a "Today's Trip Plan"
                    // shortcut sitting above results for a different,
                    // just-searched route read as confusing, not
                    // helpful, so it's hidden outright instead.
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
                    // `_outsideMalaysia` means there's genuinely nothing
                    // real this module can search for at all right now -
                    // no recommendation load is coming, so go straight
                    // to the Saved List.
                    else if (_outsideMalaysia) ...[
                      SectionHeading(
                        title: 'Saved List',
                        onTap: _openSavedList,
                      ),
                      const SizedBox(height: 8),
                      ..._buildSavedPreviewSection(),
                    ]
                    // Still checking for a "Recommended For You"/"Today's
                    // Plan" panel - hold off on the Saved List rather
                    // than showing it and then immediately swapping it
                    // out the moment the real answer arrives, which read
                    // as the page changing its mind mid-view.
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
                    // Saved List fills this space whenever there's
                    // nothing more relevant to show above it - a real
                    // "Recommended For You" suggestion/already-planned
                    // ride for today is worth more of the person's
                    // attention right now than a generic saved-trip
                    // shortcut (see _hasUsableStatus), but now that we
                    // know for sure there isn't one.
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
    // Groups the sampled preview trips the same way the full Saved List
    // page does (see groupSavedTrips) - if two of the 3 previewed trips
    // happen to be different route options for the same journey, this
    // still shows one from/to header for them instead of repeating it.
    final groups = groupSavedTrips(_savedPreview);
    return [
      for (final group in groups) ...[
        Text(
          '${shortPlaceName(group.from.name)}  →  ${shortPlaceName(group.to.name)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        for (final trip in group.trips) ...[
          RideCard(option: trip.option, onTap: () => _openSavedTrip(trip)),
          const SizedBox(height: 10),
        ],
      ],
    ];
  }
}

/// The "Recommended For You" panel, shown only while no destination has
/// been picked yet (alongside the Saved List) - a featured ride card in
/// a pale-green panel. Once a destination IS picked and real search
/// results take over below, RideHomePage hides this panel entirely (see
/// its own build method's `!hasDestination` guard) rather than
/// shrinking it to a pinned card - a "Today's Trip Plan" shortcut
/// sitting above results for a different, just-searched route read as
/// confusing rather than helpful.
/// Tapping opens that ride's own detail page directly (see
/// RideHomePage._selectRecommended/_openPlannedRide) - never a fresh
/// search into a list of alternatives, since [option] already IS the
/// one real route being recommended (or, when [alreadyPlanned] is set,
/// the one already saved for today).
///
/// [option] comes from [TransportController.todaysTransportStatus],
/// which is based purely on the signed-in user's own active saved trip
/// plan (the AI Trip Planner module's `saved_trip_plans` - see that
/// method's doc comment) - no invented/offline placeholder anymore.
/// Not shown at all (see RideHomePage's `_hasUsableStatus` check)
/// whenever there's no such plan actually running today.
class RecommendedPanel extends StatelessWidget {
  const RecommendedPanel({
    super.key,
    required this.to,
    required this.option,
    required this.onTap,
    this.alreadyPlanned = false,
  });

  /// The recommended destination itself - shown above [option] so the
  /// panel actually says where it's suggesting a ride TO, not just what
  /// the ride looks like (see this class's own name label right above
  /// it for what kind of recommendation it is).
  final LocationPoint to;
  final RideOption option;
  final VoidCallback onTap;

  /// True when [option] is the ride the person ALREADY planned and
  /// saved for today (TodaysTransportStatus.alreadyPlanned), not a
  /// suggestion to go plan one - swaps the label and hides the
  /// "elapsed since search" line (meaningless once transportation was
  /// already fixed days ago - see RideCard.showElapsedFromSearch's doc
  /// comment).
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
