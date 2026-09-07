import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:geolocator/geolocator.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../core/app_theme.dart';
import '../data/transport_data.dart' show instantToMalaysiaWallClock;
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import '../services/here_polyline_service.dart';

bool routeMapShowsDefaultNoticeFor(RideOption option) {
  final legs = option.legs.where((leg) => !leg.isTransfer);
  if (legs.isEmpty) return true;
  return legs.first.mode != TransportMode.taxi;
}

List<PolylineOptions> buildRideOptionPolylines(
  RideOption option,
  LocationPoint from,
  LocationPoint to,
) {
  final polylines = <PolylineOptions>[];
  for (final leg in option.legs) {
    var points = <LocationPoint>[];
    final encoded = leg.encodedPolyline;
    if (encoded != null) {
      try {
        final decoded = decodeHereFlexiblePolyline(encoded);
        if (looksLikePlausibleRoute(decoded)) points = decoded;
      } catch (_) {
        // Falls through to the straight-line fallback below.
      }
    }
    if (points.isEmpty) {
      final start = leg.startPoint;
      final end = leg.endPoint;
      if (start == null || end == null) continue;
      if (start.lat == end.lat && start.lng == end.lng) continue;
      points = [start, end];
    }
    polylines.add(
      PolylineOptions(
        points: [
          for (final point in points)
            LatLng(latitude: point.lat, longitude: point.lng),
        ],
        strokeColor: leg.mode.routeColor,
        strokeWidth: 5,
      ),
    );
  }
  if (polylines.isEmpty) {
    polylines.add(
      PolylineOptions(
        points: [
          LatLng(latitude: from.lat, longitude: from.lng),
          LatLng(latitude: to.lat, longitude: to.lng),
        ],
        strokeColor: AppColors.green,
        strokeWidth: 5,
      ),
    );
  }
  return polylines;
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

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
    this.showDefaultNotice = true,
    this.fallbackNotice,
    this.fallbackNoticeIsWarning = false,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  final bool showDefaultNotice;

  final String? fallbackNotice;

  final bool fallbackNoticeIsWarning;

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  GoogleMapViewController? _controller;
  String? _error;
  bool _liveLocationOn = false;

  StreamSubscription<Position>? _positionSubscription;

  Timer? _transferCheckTimer;

  final Set<int> _transferAlertsFired = {};

  String? _transferAlert;
  Timer? _transferAlertDismissTimer;

  static const _transferAlertLeadTime = Duration(minutes: 2);

  static const _transferAlertRadiusMeters = 300.0;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _onViewCreated(GoogleMapViewController controller) async {
    _controller = controller;
    try {
      await controller.addPolylines(_buildLegPolylines());
    } catch (error) {
      if (mounted) setState(() => _error = 'The route could not be drawn. $error');
    }
    unawaited(_enableLiveLocation());
    _transferCheckTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkTransferAlerts(),
    );
  }

  List<PolylineOptions> _buildLegPolylines() =>
      buildRideOptionPolylines(widget.option, widget.from, widget.to);

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
      // Permission is already confirmed above - safe to start
      // _checkTransferAlerts's own real GPS trigger now.
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen(
        (position) => _checkTransferAlerts(
          currentPosition: LocationPoint(
            name: '',
            lat: position.latitude,
            lng: position.longitude,
          ),
        ),
        onError: (_) {},
      );
    } catch (_) {
      // Best-effort - the drawn route above is still shown either way.
    }
  }

  void _checkTransferAlerts({LocationPoint? currentPosition}) {
    if (!mounted) return;
    final legs = widget.option.legs;
    final nowMYT = instantToMalaysiaWallClock(DateTime.now());
    for (var i = 0; i < legs.length; i++) {
      if (_transferAlertsFired.contains(i)) continue;
      final leg = legs[i];
      if (leg.isTransfer || !_isStationBoundMode(leg.mode)) continue;
      final nextTitle = _nextRealLegTitle(i);
      if (nextTitle == null) continue;

      final dueByTime = leg.end.difference(nowMYT) <= _transferAlertLeadTime;

      final endPoint = leg.endPoint;
      final dueByLocation =
          currentPosition != null &&
          endPoint != null &&
          currentPosition.distanceKm(endPoint) * 1000 <=
              _transferAlertRadiusMeters;

      if (dueByTime || dueByLocation) _fireTransferAlert(i, nextTitle);
    }
  }

  bool _isStationBoundMode(TransportMode mode) =>
      mode == TransportMode.train ||
      mode == TransportMode.mrt ||
      mode == TransportMode.bus ||
      mode == TransportMode.ferry;

  String? _nextRealLegTitle(int i) {
    final legs = widget.option.legs;
    for (var j = i + 1; j < legs.length; j++) {
      if (!legs[j].isTransfer) return legs[j].title;
    }
    return null;
  }

  void _fireTransferAlert(int legIndex, String nextTitle) {
    if (_transferAlertsFired.contains(legIndex)) return;
    _transferAlertsFired.add(legIndex);
    unawaited(HapticFeedback.vibrate());
    if (!mounted) return;
    setState(() => _transferAlert = 'Arriving soon - change to $nextTitle.');
    _transferAlertDismissTimer?.cancel();
    _transferAlertDismissTimer = Timer(
      const Duration(seconds: 12),
      _dismissTransferAlert,
    );
  }

  void _dismissTransferAlert() {
    _transferAlertDismissTimer?.cancel();
    if (!mounted) return;
    setState(() => _transferAlert = null);
  }

  @override
  void dispose() {
    _transferCheckTimer?.cancel();
    _transferAlertDismissTimer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
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
          if (_transferAlert != null && _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: _NavigationMessage(
                message: _transferAlert!,
                color: AppColors.orange,
                onDismiss: _dismissTransferAlert,
              ),
            ),
          if (_transferAlert == null &&
              (widget.fallbackNotice != null ||
                  (!_liveLocationOn && widget.showDefaultNotice)) &&
              _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: _NavigationMessage(
                message:
                    widget.fallbackNotice ??
                    'Showing the real route. Live location needs device '
                        'GPS - no spoken turn-by-turn for public transport, '
                        'since Google has no routing engine for that.',
                color: widget.fallbackNoticeIsWarning
                    ? AppColors.orange
                    : AppColors.green,
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
