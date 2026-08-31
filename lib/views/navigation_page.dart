import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import '../widgets/location_row.dart';

/// A single ongoing-leg lookup: which leg is currently "active", how much
/// simulated time is left in it, and its position in the leg list (needed
/// to phrase "walk to your first stop" vs "walk to your destination").
typedef _ActiveLeg = ({TripLeg leg, Duration remainingInLeg, int index});

/// Fixed street-level zoom used the whole time the map is in "navigating"
/// mode - like Google Maps' turn-by-turn view, it stays zoomed in on the
/// live position rather than zooming out to show the whole route.
const _kNavigationZoom = 17.0;

/// Great-circle initial compass bearing (degrees, 0 = north, clockwise)
/// from (lat1,lng1) to (lat2,lng2). Used so the map can rotate to face the
/// direction of travel, the way Google Maps' turn-by-turn view does.
double _bearingBetweenCoords(
  double lat1Deg,
  double lng1Deg,
  double lat2Deg,
  double lng2Deg,
) {
  final lat1 = lat1Deg * math.pi / 180;
  final lat2 = lat2Deg * math.pi / 180;
  final dLng = (lng2Deg - lng1Deg) * math.pi / 180;

  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final bearing = math.atan2(y, x) * 180 / math.pi;
  return (bearing + 360) % 360;
}

/// Phrases a Waze/Google-Maps-style "what to do right now" instruction for
/// [leg]. Important honest caveat: HERE's Transit API only returns
/// walk/board/alight transit segments, not turn-by-turn street directions
/// - there's no "turn left in 200m" data to show the way a *driving* nav
/// app like Waze would, because this app guides public-transport trips,
/// not car turns. This is the closest transit-guidance equivalent: what to
/// do right now (walk / board / ride) and, for a transit leg, which
/// service to look for - the same idea Google Maps' own transit mode uses.
String _instructionFor(TripLeg leg, int index, int totalLegs) {
  if (leg.mode == TransportMode.walk) {
    if (index == 0) return 'Walk to your first stop';
    if (index == totalLegs - 1) return 'Walk to your destination';
    return 'Walk to your next connection';
  }
  if (leg.mode == TransportMode.taxi) return 'Ride ${leg.title}';
  return 'Board ${leg.title}';
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
  Timer? _timer;
  late Duration _totalDuration;
  late Duration _elapsed;
  late DateTime _eta;
  bool _arrived = false;

  final MapController _mapController = MapController();

  /// Demo playback speed: every real second advances the trip by one
  /// simulated minute, so even a multi-hour itinerary finishes in well
  /// under a minute for demo/testing purposes.
  static const _simulatedMinutesPerTick = 1;

  /// The actual line the simulated position travels along. When the ride
  /// came from the live HERE API and its polyline decoded successfully,
  /// this is the real road/rail geometry (`widget.option.path`) - so the
  /// map follows the actual transportation route instead of a straight
  /// line. For offline/mock options (or if decoding failed) there's no
  /// real geometry to show, so this honestly falls back to a single
  /// straight segment between the origin and destination.
  late final List<LatLng> _routePoints;

  /// Cumulative distance (metres) up to and including each point in
  /// [_routePoints], i.e. `_cumulativeDistances[i]` is the distance
  /// travelled from the start of the route to `_routePoints[i]`. Used to
  /// place the simulated position at the right point along a *bendy* path
  /// by distance-fraction rather than naive index-fraction.
  late final List<double> _cumulativeDistances;

  late final double _totalRouteDistance;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.option.totalDuration;
    _elapsed = Duration.zero;
    _eta = widget.option.arriveTime;
    _arrived = _totalDuration <= Duration.zero;

    final rawPath = widget.option.path;
    _routePoints = rawPath.length >= 2
        ? rawPath.map((p) => LatLng(p.lat, p.lng)).toList()
        : [
            LatLng(widget.from.lat, widget.from.lng),
            LatLng(widget.to.lat, widget.to.lng),
          ];

    const distanceCalculator = Distance();
    _cumulativeDistances = [0.0];
    for (var i = 1; i < _routePoints.length; i++) {
      final segmentMeters = distanceCalculator(
        _routePoints[i - 1],
        _routePoints[i],
      );
      _cumulativeDistances.add(_cumulativeDistances.last + segmentMeters);
    }
    _totalRouteDistance = _cumulativeDistances.last;

    if (!_arrived) {
      _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {
      _elapsed += const Duration(minutes: _simulatedMinutesPerTick);
      if (_elapsed >= _totalDuration) {
        _elapsed = _totalDuration;
        _arrived = true;
        timer.cancel();
      }
    });
    // Keep re-centring (and re-facing) on the live position at a fixed
    // street-level zoom every tick, so the map is always actively
    // "navigating" (following you) rather than a static overview you'd
    // have to manually pan. Wrapped defensively: the controller has
    // nothing to move before the map has laid out at least once.
    try {
      _mapController.moveAndRotate(
        _currentPosition,
        _kNavigationZoom,
        _navigationRotation,
      );
    } catch (_) {
      // Ignore - the map just hasn't attached yet.
    }
  }

  Duration get _remaining => _totalDuration - _elapsed;

  /// How far through the trip we are, 0.0 (just departed) to 1.0 (arrived),
  /// based on real elapsed simulated time.
  double get _progressFraction {
    final totalMinutes = _totalDuration.inMinutes;
    return totalMinutes <= 0
        ? 1.0
        : (_elapsed.inMinutes / totalMinutes).clamp(0.0, 1.0);
  }

  /// Finds which segment of [_routePoints] the given distance-along-route
  /// falls in, and how far through that segment (0.0-1.0). Used so the
  /// simulated position and bearing follow the real (possibly bendy) path
  /// by distance, not just by straight-line index.
  ({int index, double t}) _segmentAt(double targetDistanceMeters) {
    if (_routePoints.length < 2 || _totalRouteDistance <= 0) {
      return (index: 0, t: 0.0);
    }
    for (var i = 0; i < _cumulativeDistances.length - 1; i++) {
      final segStart = _cumulativeDistances[i];
      final segEnd = _cumulativeDistances[i + 1];
      if (targetDistanceMeters <= segEnd ||
          i == _cumulativeDistances.length - 2) {
        final segLength = segEnd - segStart;
        final t = segLength <= 0
            ? 0.0
            : ((targetDistanceMeters - segStart) / segLength).clamp(0.0, 1.0);
        return (index: i, t: t);
      }
    }
    return (index: _cumulativeDistances.length - 2, t: 1.0);
  }

  /// The live simulated position, interpolated along the real route
  /// geometry (when available) by elapsed-time fraction of total distance
  /// - so on a live HERE trip this follows the actual road/rail path
  /// instead of cutting a straight line across the map. Falls back to a
  /// plain two-point straight line for offline/mock trips, since there's
  /// no real geometry to follow for a fabricated demo trip.
  LatLng get _currentPosition {
    if (_routePoints.isEmpty) {
      return LatLng(widget.from.lat, widget.from.lng);
    }
    if (_routePoints.length == 1) return _routePoints.first;
    final seg = _segmentAt(_progressFraction * _totalRouteDistance);
    final p0 = _routePoints[seg.index];
    final p1 = _routePoints[seg.index + 1];
    return LatLng(
      p0.latitude + (p1.latitude - p0.latitude) * seg.t,
      p0.longitude + (p1.longitude - p0.longitude) * seg.t,
    );
  }

  /// The compass bearing of the CURRENT segment of the route (not a single
  /// fixed bearing for the whole trip), so the map's rotation tracks each
  /// bend in a real road/rail path the way Google Maps' turn-by-turn view
  /// does. Falls back to the overall origin→destination bearing when there
  /// is no real multi-point path.
  ///
  /// NOTE: flutter_map's rotation is clockwise from north. Rotating the
  /// map by the *negative* of this bearing is what should put the heading
  /// "up" - but this hasn't been visually checked on a real device/
  /// emulator (this was written in a sandbox with no Flutter SDK to run
  /// it in). If the map's orientation looks backwards/mirrored when you
  /// run it, flip the sign in [_navigationRotation] below (remove the `-`).
  double get _currentBearing {
    if (_routePoints.length < 2) {
      return _bearingBetweenCoords(
        widget.from.lat,
        widget.from.lng,
        widget.to.lat,
        widget.to.lng,
      );
    }
    final seg = _segmentAt(_progressFraction * _totalRouteDistance);
    final p0 = _routePoints[seg.index];
    final p1 = _routePoints[seg.index + 1];
    if (p0.latitude == p1.latitude && p0.longitude == p1.longitude) {
      return _bearingBetweenCoords(
        widget.from.lat,
        widget.from.lng,
        widget.to.lat,
        widget.to.lng,
      );
    }
    return _bearingBetweenCoords(
      p0.latitude,
      p0.longitude,
      p1.latitude,
      p1.longitude,
    );
  }

  double get _navigationRotation => (-_currentBearing) % 360;

  _ActiveLeg? get _activeLeg {
    var acc = Duration.zero;
    final legs = widget.option.legs;
    for (var i = 0; i < legs.length; i++) {
      final legDuration = legs[i].duration;
      if (_elapsed < acc + legDuration) {
        return (
          leg: legs[i],
          remainingInLeg: acc + legDuration - _elapsed,
          index: i,
        );
      }
      acc += legDuration;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeLeg = _activeLeg;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _RouteMap(
            mapController: _mapController,
            from: widget.from,
            to: widget.to,
            routePoints: _routePoints,
            currentPosition: _currentPosition,
            rotationDegrees: _navigationRotation,
          ),
          if (!_arrived && activeLeg != null)
            _TurnBanner(
              activeLeg: activeLeg,
              totalLegs: widget.option.legs.length,
            ),
          _NavigationSummary(
            from: widget.from,
            to: widget.to,
            remaining: _remaining,
            eta: _eta,
            activeLeg: activeLeg,
            arrived: _arrived,
          ),
          _NavigationBackButton(onPressed: () => Navigator.of(context).pop()),
          if (_arrived)
            _ArrivedOverlay(
              destinationLabel: widget.to.name,
              onDone: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
        ],
      ),
    );
  }
}

/// Waze/Google-Maps-style banner pinned to the top of the map: a big mode
/// icon plus the current "what to do now" instruction and a live countdown,
/// so the most urgent piece of guidance sits at the top of the screen the
/// way a real turn-by-turn nav app keeps it, instead of only living in the
/// bottom summary card.
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.activeLeg, required this.totalLegs});

  final _ActiveLeg activeLeg;
  final int totalLegs;

  @override
  Widget build(BuildContext context) {
    final leg = activeLeg.leg;
    final instruction = _instructionFor(leg, activeLeg.index, totalLegs);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(64, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: transportModeGlyph(
                  leg.mode,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instruction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'In ${formatDuration(activeLeg.remainingInLeg)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
}

/// The live map background: OpenStreetMap tiles, the route line (the real
/// road/rail geometry when available, otherwise a straight line between
/// origin and destination), and three markers (origin, destination, and
/// the live simulated position).
class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.mapController,
    required this.from,
    required this.to,
    required this.routePoints,
    required this.currentPosition,
    required this.rotationDegrees,
  });

  final MapController mapController;
  final LocationPoint from;
  final LocationPoint to;
  final List<LatLng> routePoints;
  final LatLng currentPosition;
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(from.lat, from.lng);
    final destination = LatLng(to.lat, to.lng);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        // Start already zoomed into the live position (not an overview of
        // the whole route) and pre-rotated to face the direction of
        // travel - "always navigating", the same as opening Google Maps'
        // turn-by-turn view.
        initialCenter: currentPosition,
        initialZoom: _kNavigationZoom,
        initialRotation: rotationDegrees,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.collab_assignment',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: routePoints,
              strokeWidth: 4,
              color: AppColors.green,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: origin,
              width: 30,
              height: 30,
              child: const Icon(
                Icons.trip_origin,
                color: AppColors.green,
                size: 22,
              ),
            ),
            Marker(
              point: destination,
              width: 34,
              height: 34,
              child: const Icon(
                Icons.location_on,
                color: AppColors.orange,
                size: 32,
              ),
            ),
            Marker(
              point: currentPosition,
              width: 40,
              height: 40,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.navigation, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationBackButton extends StatelessWidget {
  const _NavigationBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: Colors.white70),
            onPressed: onPressed,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationSummary extends StatelessWidget {
  const _NavigationSummary({
    required this.from,
    required this.to,
    required this.remaining,
    required this.eta,
    required this.activeLeg,
    required this.arrived,
  });

  final LocationPoint from;
  final LocationPoint to;
  final Duration remaining;
  final DateTime eta;
  final _ActiveLeg? activeLeg;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final leg = activeLeg;
    final String secondaryLabel;
    if (arrived) {
      secondaryLabel = 'You have arrived';
    } else if (leg != null) {
      secondaryLabel =
          '${formatDuration(leg.remainingInLeg)} on ${leg.leg.title} · ${formatClockTime(eta)}';
    } else {
      secondaryLabel = 'ETA ${formatClockTime(eta)}';
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 12),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    arrived ? 'Arrived' : formatDuration(remaining),
                    style: const TextStyle(
                      fontSize: 23,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      secondaryLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              LocationRow(label: 'From', value: from.name, color: AppColors.green),
              const Divider(height: 18),
              LocationRow(
                label: 'To',
                value: to.name,
                color: AppColors.orange,
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivedOverlay extends StatelessWidget {
  const _ArrivedOverlay({required this.destinationLabel, required this.onDone});

  final String destinationLabel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.green, size: 48),
                const SizedBox(height: 12),
                Text("You've arrived", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  destinationLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
