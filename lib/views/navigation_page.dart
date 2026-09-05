import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../core/app_theme.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';

/// Google Navigation SDK's own travel mode for [mode], or null when the
/// SDK has nothing that matches - it only knows driving/walking/cycling/
/// taxi, with no "public transit" mode at all, so a bus/train/MRT/ferry
/// leg (or anything this app couldn't otherwise classify) always maps to
/// null here. Top-level (not a private method on _NavigationPageState) so
/// [hasGoogleNavigableFirstLeg] below can reuse the exact same mapping
/// from outside this file, rather than TripDetailsPage guessing at its
/// own separate copy of "which modes Google can handle" that could
/// silently drift out of sync with this one.
NavigationTravelMode? googleTravelModeFor(TransportMode mode) =>
    switch (mode) {
      TransportMode.walk => NavigationTravelMode.walking,
      TransportMode.taxi => NavigationTravelMode.taxi,
      TransportMode.bike => NavigationTravelMode.cycling,
      TransportMode.train ||
      TransportMode.mrt ||
      TransportMode.bus ||
      TransportMode.ferry ||
      TransportMode.other => null,
    };

/// Whether [option] even has a shot at Google turn-by-turn guidance -
/// mirrors _NavigationPageState._selectNavigableLeg's own first-leg check
/// (see that method's doc comment for why only the FIRST non-transfer
/// leg matters) without needing a real Google Navigation session or
/// GPS fix just to answer it. Lets TripDetailsPage decide NOT to open
/// this whole full-screen native map in the first place for a trip
/// that starts with a public-transport leg - there's nothing productive
/// to show there but an immediate dead-end error, when staying on the
/// trip details screen (with the real HERE itinerary already visible)
/// is strictly more useful.
bool hasGoogleNavigableFirstLeg(RideOption option) {
  final legs = option.legs.where((leg) => !leg.isTransfer);
  if (legs.isEmpty) return false;
  return googleTravelModeFor(legs.first.mode) != null;
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleNavigationViewController? _viewController;
  bool _sessionInitialized = false;
  bool _startingGuidance = false;
  bool _guidanceRunning = false;
  String? _error;

  // False only for an error _startGuidance can never resolve by simply
  // being called again (see hasGoogleNavigableFirstLeg's doc comment) -
  // every other error here (no GPS fix yet, a transient network hiccup,
  // location permission not granted yet...) is a real "try again" case.
  // Drives whether the error banner below offers "Retry" (which would
  // just reproduce the identical failure, forever) or "Back" instead.
  bool _errorRecoverable = true;
  String? _segmentNotice;

  // Auto-clears _segmentNotice a few seconds after it's shown (see
  // _startGuidance/_dismissSegmentNotice) - it used to sit on screen for
  // as long as this navigation leg lasted, with nothing ever clearing it,
  // which meant it permanently covered the native bottom trip-info panel
  // (the distance/ETA readout GoogleMapsNavigationView draws itself,
  // which Flutter has no layout awareness of - see _NavigationMessage's
  // Positioned bottom offset). A one-time heads-up doesn't need to stay
  // up that whole time.
  Timer? _segmentNoticeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() async {
    if (!_isSupportedPlatform) {
      _setError('Google turn-by-turn navigation requires Android or iOS.');
      return;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError('Turn on device location to start real-time navigation.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setError('Precise location permission is required for navigation.');
        return;
      }

      if (!await GoogleMapsNavigator.areTermsAccepted()) {
        final accepted = await GoogleMapsNavigator.showTermsAndConditionsDialog(
          'Google turn-by-turn navigation',
          'Green Travel Planner',
        );
        if (!accepted) {
          _setError('Accept the navigation terms to start guidance.');
          return;
        }
      }

      await GoogleMapsNavigator.initializeNavigationSession(
        taskRemovedBehavior: TaskRemovedBehavior.continueService,
      );
      await GoogleMapsNavigator.setAudioGuidance(
        NavigationAudioGuidanceSettings(
          isBluetoothAudioEnabled: true,
          isVibrationEnabled: true,
          guidanceType: NavigationAudioGuidanceType.alertsAndGuidance,
        ),
      );

      if (!mounted) return;
      setState(() => _sessionInitialized = true);
    } on SessionInitializationException catch (error) {
      _setError('Google Navigation could not start: $error');
    } catch (error) {
      _setError('Google Navigation could not start. $error');
    }
  }

  Future<void> _onViewCreated(GoogleNavigationViewController controller) async {
    _viewController = controller;
    try {
      await controller.setMyLocationEnabled(true);
      await controller.setNavigationUIEnabled(true);
      await controller.followMyLocation(CameraPerspective.tilted);
      await _startGuidance();
    } on ViewNotFoundException {
      // The user closed the page while the native view was being created.
    } catch (error) {
      _setError('The Google navigation map could not be prepared. $error');
    }
  }

  _GoogleNavigationLeg? _selectNavigableLeg() {
    final legs = widget.option.legs
        .where((leg) => !leg.isTransfer)
        .toList(growable: false);
    if (legs.isEmpty) return null;

    final first = legs.first;
    final travelMode = _googleMode(first.mode);
    if (travelMode == null) return null;

    // A single-mode HERE result can safely use the searched destination. For
    // an intermodal result, navigate only the current first/last-mile section;
    // Google Navigation has no bus/train/ferry travel mode and must not turn a
    // public-transit section into a driving route.
    final sameMode = legs.every((leg) => leg.mode == first.mode);
    final target = sameMode ? widget.to : first.endPoint;
    if (target == null) return null;

    return _GoogleNavigationLeg(
      target: target,
      travelMode: travelMode,
      isPartialJourney: !sameMode,
      title: first.title,
    );
  }

  NavigationTravelMode? _googleMode(TransportMode mode) =>
      googleTravelModeFor(mode);

  Future<void> _startGuidance() async {
    if (_startingGuidance || _guidanceRunning) return;
    final leg = _selectNavigableLeg();
    if (leg == null) {
      _setError(
        'Google Navigation does not provide turn-by-turn guidance for this '
        'public-transport section. The HERE itinerary remains available on '
        'the trip details screen.',
        recoverable: false,
      );
      return;
    }

    setState(() {
      _startingGuidance = true;
      _error = null;
      _segmentNotice = leg.isPartialJourney
          ? 'Navigating ${leg.title} to ${leg.target.name}. HERE continues the remaining itinerary.'
          : null;
    });
    _segmentNoticeTimer?.cancel();
    if (_segmentNotice != null) {
      _segmentNoticeTimer = Timer(
        const Duration(seconds: 6),
        _dismissSegmentNotice,
      );
    }

    NavigationRouteStatus status = NavigationRouteStatus.locationUnavailable;
    try {
      final destinations = Destinations(
        waypoints: [
          NavigationWaypoint.withLatLngTarget(
            title: leg.target.name,
            target: LatLng(latitude: leg.target.lat, longitude: leg.target.lng),
          ),
        ],
        displayOptions: NavigationDisplayOptions(showDestinationMarkers: true),
        routingOptions: RoutingOptions(
          travelMode: leg.travelMode,
          alternateRoutesStrategy: NavigationAlternateRoutesStrategy.one,
          locationTimeoutMs: 15000,
        ),
      );

      // The native SDK needs its own first road-snapped fix. A Geolocator fix
      // alone does not guarantee that setDestinations is ready, so retry only
      // the two documented transient location states.
      for (var attempt = 0; attempt < 12; attempt++) {
        status = await GoogleMapsNavigator.setDestinations(destinations);
        if (status != NavigationRouteStatus.locationUnavailable &&
            status != NavigationRouteStatus.locationUnknown) {
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (status != NavigationRouteStatus.statusOk) {
        _setError(_messageForStatus(status, leg.travelMode));
        return;
      }

      await GoogleMapsNavigator.startGuidance();
      await _viewController?.setNavigationUIEnabled(true);
      await _viewController?.followMyLocation(CameraPerspective.tilted);
      if (!mounted) return;
      setState(() => _guidanceRunning = true);
    } catch (error) {
      _setError('Real-time guidance could not start. $error');
    } finally {
      if (mounted) setState(() => _startingGuidance = false);
    }
  }

  String _messageForStatus(
    NavigationRouteStatus status,
    NavigationTravelMode mode,
  ) {
    return switch (status) {
      NavigationRouteStatus.apiKeyNotAuthorized =>
        'The API key is not authorized. Enable Navigation SDK and restrict the key to this Android app.',
      NavigationRouteStatus.quotaExceeded ||
      NavigationRouteStatus.quotaCheckFailed =>
        'The Google Navigation quota is unavailable for this project.',
      NavigationRouteStatus.networkError =>
        'A network connection is required to calculate the live route.',
      NavigationRouteStatus.locationUnavailable ||
      NavigationRouteStatus.locationUnknown =>
        'Waiting for a usable GPS fix timed out. Move outdoors and retry.',
      NavigationRouteStatus.travelModeUnsupported
          when mode == NavigationTravelMode.cycling =>
        'Google cycling navigation is not available in this region. Use the HERE bicycle itinerary instead.',
      NavigationRouteStatus.travelModeUnsupported =>
        'Google Navigation does not support this travel mode here.',
      NavigationRouteStatus.routeNotFound =>
        'Google could not calculate a navigable route to this destination.',
      _ => 'Google Navigation could not start (${status.name}).',
    };
  }

  void _setError(String message, {bool recoverable = true}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _errorRecoverable = recoverable;
      _startingGuidance = false;
    });
  }

  /// Clears the green segment notice, whether from its own auto-dismiss
  /// timer (see _startGuidance) or the person tapping its close button
  /// (see _NavigationMessage's onDismiss).
  void _dismissSegmentNotice() {
    _segmentNoticeTimer?.cancel();
    if (!mounted) return;
    setState(() => _segmentNotice = null);
  }

  Future<void> _close() async {
    try {
      if (_guidanceRunning) await GoogleMapsNavigator.stopGuidance();
    } catch (_) {
      // Closing the screen must still work if the native session has ended.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _segmentNoticeTimer?.cancel();
    if (_sessionInitialized) {
      unawaited(GoogleMapsNavigator.stopGuidance().catchError((_) {}));
      unawaited(GoogleMapsNavigator.cleanup().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF0EC),
        body: Stack(
          children: [
            if (_sessionInitialized)
              Positioned.fill(
                child: GoogleMapsNavigationView(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      latitude: widget.from.lat,
                      longitude: widget.from.lng,
                    ),
                    zoom: 17,
                  ),
                  initialNavigationUIEnabledPreference:
                      NavigationUIEnabledPreference.automatic,
                  initialForceNightMode: NavigationForceNightMode.auto,
                  initialCompassEnabled: true,
                  initialZoomControlsEnabled: false,
                  initialMapToolbarEnabled: false,
                  onViewCreated: _onViewCreated,
                ),
              )
            else
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              left: 10,
              top: MediaQuery.paddingOf(context).top + 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                onPressed: _close,
                icon: const Icon(Icons.close),
              ),
            ),
            if (_segmentNotice != null && _error == null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: _NavigationMessage(
                  message: _segmentNotice!,
                  color: AppColors.green,
                  onDismiss: _dismissSegmentNotice,
                ),
              ),
            if (_error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: _NavigationMessage(
                  message: _error!,
                  color: Colors.red.shade800,
                  // "Retry" only for an error _startGuidance could
                  // genuinely resolve on a second attempt - offering it
                  // for the unrecoverable "this trip starts with a
                  // public-transport leg" case (see
                  // hasGoogleNavigableFirstLeg) would just reproduce the
                  // exact same message every time, so that case gets a
                  // "Back" button (leaves this screen entirely) instead.
                  actionLabel: !_errorRecoverable
                      ? 'Back'
                      : (_sessionInitialized ? 'Retry' : null),
                  onAction: !_errorRecoverable
                      ? _close
                      : (_sessionInitialized ? _startGuidance : null),
                ),
              ),
            if (_startingGuidance)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoogleNavigationLeg {
  const _GoogleNavigationLeg({
    required this.target,
    required this.travelMode,
    required this.isPartialJourney,
    required this.title,
  });

  final LocationPoint target;
  final NavigationTravelMode travelMode;
  final bool isPartialJourney;
  final String title;
}

class _NavigationMessage extends StatelessWidget {
  const _NavigationMessage({
    required this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a small close (X) button when set, so the notice doesn't have
  /// to be waited out - see _dismissSegmentNotice. Left null for the
  /// error variant, which already has its own "Retry" action instead.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// A live, interactive map - not Google's guidance/turn-by-turn session
/// (see NavigationPage for that) - showing [option]'s real route drawn
/// as a polyline (RideOption.path; falls back to a straight line
/// between [from]/[to] when that's empty, same convention that field's
/// own doc comment already promises) plus the person's own live GPS
/// position as the standard "blue dot", following them as they move.
///
/// Opened instead of NavigationPage whenever hasGoogleNavigableFirstLeg
/// is false - Google's routing/guidance engine has no travel mode for a
/// public-transport leg at all, so there is no way to get its spoken
/// turn-by-turn or automatic maneuver detection here, but seeing where
/// you actually are against the real route in real time doesn't need
/// that engine - [GoogleMapsMapView] is Google Navigation SDK's plain
/// map mode, entirely separate from GoogleMapsNavigator's guidance
/// session (no travel mode, no setDestinations/startGuidance call, none
/// of what fails for a bus/train in NavigationPage).
///
/// The route itself always draws regardless of location permission -
/// only the live blue dot needs that, and is best-effort (see
/// _enableLiveLocation) so a person who hasn't granted it yet still sees
/// the real route, just without their own position on it.
class RouteMapPage extends StatefulWidget {
  const RouteMapPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  GoogleMapViewController? _controller;
  String? _error;
  bool _liveLocationOn = false;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _onViewCreated(GoogleMapViewController controller) async {
    _controller = controller;
    try {
      final routePoints = widget.option.path.isNotEmpty
          ? widget.option.path
          : [widget.from, widget.to];
      await controller.addPolylines([
        PolylineOptions(
          points: [
            for (final point in routePoints)
              LatLng(latitude: point.lat, longitude: point.lng),
          ],
          strokeColor: AppColors.green,
          strokeWidth: 5,
        ),
      ]);
    } catch (error) {
      if (mounted) setState(() => _error = 'The route could not be drawn. $error');
    }
    unawaited(_enableLiveLocation());
  }

  /// Turns on the real "blue dot" GPS marker for this plain map view -
  /// entirely separate from NavigationPage's own permission flow (that
  /// one also has to accept Google's navigation terms and initialize a
  /// GoogleMapsNavigator session; this map needs neither, just device
  /// location). Silently does nothing beyond leaving the route-only map
  /// on screen if location is off, permission is denied, or the
  /// platform doesn't support it - see this class's own doc comment for
  /// why that's the right fallback here, not an error blocking the map.
  Future<void> _enableLiveLocation() async {
    if (!_isSupportedPlatform) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      await _controller?.setMyLocationEnabled(true);
      await _controller?.followMyLocation(CameraPerspective.tilted);
      if (mounted) setState(() => _liveLocationOn = true);
    } catch (_) {
      // Best-effort - the drawn route above is still shown either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMapsMapView(
            onViewCreated: _onViewCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(latitude: widget.from.lat, longitude: widget.from.lng),
              zoom: 15,
            ),
          ),
          Positioned(
            left: 10,
            top: MediaQuery.paddingOf(context).top + 8,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          // A one-time heads-up that this map can't spoken-guide the
          // public-transport part of the trip - shown once, not kept
          // permanently on screen like NavigationPage's segment notice,
          // since there's no later moment here where it would need to
          // reappear (unlike a multi-leg automatic hop splice).
          if (!_liveLocationOn && _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: _NavigationMessage(
                message:
                    'Showing the real route. Live location needs device '
                    'GPS - no spoken turn-by-turn for public transport, '
                    'since Google has no routing engine for that.',
                color: AppColors.green,
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: _NavigationMessage(
                message: _error!,
                color: Colors.red.shade800,
              ),
            ),
        ],
      ),
    );
  }
}
