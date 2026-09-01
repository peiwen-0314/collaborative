import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../core/app_theme.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';

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

  NavigationTravelMode? _googleMode(TransportMode mode) => switch (mode) {
    TransportMode.walk => NavigationTravelMode.walking,
    TransportMode.taxi => NavigationTravelMode.taxi,
    TransportMode.bike => NavigationTravelMode.cycling,
    TransportMode.train ||
    TransportMode.mrt ||
    TransportMode.bus ||
    TransportMode.ferry ||
    TransportMode.other => null,
  };

  Future<void> _startGuidance() async {
    if (_startingGuidance || _guidanceRunning) return;
    final leg = _selectNavigableLeg();
    if (leg == null) {
      _setError(
        'Google Navigation does not provide turn-by-turn guidance for this '
        'public-transport section. The HERE itinerary remains available on '
        'the trip details screen.',
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

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
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
                  actionLabel: _sessionInitialized ? 'Retry' : null,
                  onAction: _sessionInitialized ? _startGuidance : null,
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
