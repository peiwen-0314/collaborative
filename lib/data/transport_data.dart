import 'dart:math';

import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';

/// Anything that can turn a From/To/when search into a list of ride
/// options. Implemented by [MockTransportRepository] (always available,
/// works offline) and by the live HERE-backed repository in
/// `lib/services/here_transit_service.dart`.
abstract class TransportRepository {
  Future<List<RideOption>> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  });
}

/// Generates realistic-looking (but entirely offline) ride options, scaled
/// by the great-circle distance between [from] and [to]. This is what the
/// app uses whenever no HERE API key is configured, the network call fails,
/// or the device is offline - so the transportation module always has
/// something sensible to show.
class MockTransportRepository implements TransportRepository {
  const MockTransportRepository();

  @override
  Future<List<RideOption>> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    // Small artificial delay so the UI's loading state is exercised even
    // when running fully offline.
    await Future.delayed(const Duration(milliseconds: 350));

    final distanceKm = _haversineKm(from, to);
    final seed = Object.hash(from.name, to.name, departAt.year, departAt.month, departAt.day);
    final random = Random(seed);

    final templates = _templatesFor(distanceKm);
    final options = [
      for (final template in templates)
        _buildOption(
          template,
          from: from,
          to: to,
          departAt: departAt,
          distanceKm: distanceKm,
          random: random,
        ),
    ];

    return _tagOptions(options);
  }

  List<_RouteTemplate> _templatesFor(double distanceKm) {
    if (distanceKm <= 12) {
      return [
        const _RouteTemplate('MRT + Walk', [
          TransportMode.mrt,
          TransportMode.walk,
        ]),
        const _RouteTemplate('City Bus', [TransportMode.bus]),
        const _RouteTemplate('E-hailing', [TransportMode.taxi]),
        // Shared bike-share (e.g. LinkBike-style docked bikes) only makes
        // sense for genuinely short, city-centre-scale trips - real
        // bike-share networks don't cover long-haul distances. Capped
        // well below this bracket's own 12km ceiling for that reason.
        if (distanceKm <= 8)
          const _RouteTemplate('Shared Bike', [
            TransportMode.walk,
            TransportMode.bike,
          ]),
      ];
    } else if (distanceKm <= 90) {
      return const [
        _RouteTemplate('MRT + Bus', [TransportMode.mrt, TransportMode.bus]),
        _RouteTemplate('KTM Komuter + Walk', [
          TransportMode.train,
          TransportMode.walk,
        ]),
        _RouteTemplate('E-hailing', [TransportMode.taxi]),
      ];
    }
    return const [
      _RouteTemplate('KTM Komuter + Express Bus + Ferry', [
        TransportMode.train,
        TransportMode.bus,
        TransportMode.ferry,
      ]),
      _RouteTemplate('Express Bus', [TransportMode.bus]),
      _RouteTemplate('Train + E-hailing', [
        TransportMode.train,
        TransportMode.taxi,
      ]),
    ];
  }

  RideOption _buildOption(
    _RouteTemplate template, {
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required double distanceKm,
    required Random random,
  }) {
    // Split the total distance across the "real" (non-transfer) legs.
    final legCount = template.modes.length;
    final shareBase = distanceKm / legCount;

    var cursor = departAt;
    final legs = <TripLeg>[];
    var totalCostRm = 0.0;
    var totalCo2Kg = 0.0;

    for (var i = 0; i < legCount; i++) {
      final mode = template.modes[i];

      // Public transport doesn't run 24 hours a day - searching at 1am
      // for a train that only starts around 6am shouldn't produce an
      // option that boards at 1am. Silently anchor this leg to the next
      // time the mode is actually in service first (no visible "tile" for
      // this - it's just when this option's timeline realistically
      // starts, the same way Google Maps Transit shows several options
      // each beginning at a different real departure time rather than one
      // "departs the moment you searched" result).
      cursor = _nextAvailableDeparture(cursor, mode);

      // A real bus/train/ferry also doesn't appear the instant you're
      // ready to board it even *within* service hours - it runs to a
      // schedule. Rather than pretending you catch it the moment you
      // arrive (which is what made a walk time like "19 min" look like it
      // magically lined up with the next departure), model a realistic
      // wait based on this mode's typical service frequency in the Klang
      // Valley before boarding. This is still an estimate (not a real
      // live timetable lookup - see the note on MockTransportRepository
      // above), but it's an honest one: it shows up as its own "Waiting
      // for ..." step instead of being hidden.
      final waitRange = _waitMinutesRangeByMode[mode];
      if (waitRange != null) {
        final waitMinutes =
            waitRange.$1 + random.nextInt(waitRange.$2 - waitRange.$1 + 1);
        final waitStart = cursor;
        final waitEnd = waitStart.add(Duration(minutes: waitMinutes));
        legs.add(
          TripLeg(
            mode: mode,
            title: 'Wait for ${_serviceName(mode, longHaul: distanceKm > 90)}',
            subtitle: mode == TransportMode.taxi
                ? '⏱  Waiting for driver to arrive'
                : '⏱  Waiting for next departure',
            start: waitStart,
            end: waitEnd,
            isTransfer: true,
          ),
        );
        cursor = waitEnd;
      }

      // Walk legs never carry the bulk of a long trip.
      final legDistanceKm = mode == TransportMode.walk
          ? min(shareBase, 1.5)
          : shareBase;

      final speedKmh = _speedKmh[mode]!;
      final jitter = 0.9 + random.nextDouble() * 0.2; // +/-10%
      final minutes = max(5, (legDistanceKm / speedKmh * 60 * jitter).round());
      final legStart = cursor;
      final legEnd = legStart.add(Duration(minutes: minutes));

      final originLabel = i == 0 ? from.name : _waypointLabel(template.modes[i - 1]);
      final destLabel = i == legCount - 1 ? to.name : _waypointLabel(mode);

      legs.add(
        TripLeg(
          mode: mode,
          title: _serviceName(mode, longHaul: distanceKm > 90),
          subtitle: '($originLabel → $destLabel)',
          start: legStart,
          end: legEnd,
        ),
      );
      totalCostRm += (_costPerKm[mode]! * legDistanceKm) * jitter;
      totalCo2Kg += _co2PerKm[mode]! * legDistanceKm;
      cursor = legEnd;

      final isLastLeg = i == legCount - 1;
      if (!isLastLeg) {
        // Just the walk/interchange between this stop and the next mode's
        // stop - the wait for that *next* vehicle is handled by the
        // "Wait for ..." leg at the top of the next iteration above, so
        // this no longer has to double up as both walking AND waiting.
        final transferMinutes = 3 + random.nextInt(6); // 3-8 min
        final transferStart = cursor;
        final transferEnd = transferStart.add(Duration(minutes: transferMinutes));
        legs.add(
          TripLeg(
            mode: mode,
            title: destLabel,
            subtitle: '⇄  Transfer',
            start: transferStart,
            end: transferEnd,
            isTransfer: true,
          ),
        );
        cursor = transferEnd;
      }
    }

    if (totalCostRm < 1) totalCostRm = 1 + random.nextDouble();

    return RideOption(
      id: '${template.title}-${from.name}-${to.name}-${departAt.millisecondsSinceEpoch}'
          .hashCode
          .toString(),
      title: template.title,
      legs: legs,
      estCostRm: totalCostRm,
      co2Kg: totalCo2Kg,
      tags: const [],
      searchDepartAt: departAt,
    );
  }

  /// Adds relative "Low Carbon" / "Cost Effective" / "On Time" badges once
  /// all options for this search are known, so the badges are meaningful
  /// relative to the alternatives (not just absolute thresholds).
  List<RideOption> _tagOptions(List<RideOption> options) {
    if (options.isEmpty) return options;
    final cheapest = options.reduce(
      (a, b) => a.estCostRm <= b.estCostRm ? a : b,
    );
    final greenest = options.reduce((a, b) => a.co2Kg <= b.co2Kg ? a : b);
    // "Fastest" should mean "gets you there soonest from right now", not
    // just "shortest ride once it starts" - see RideOption.searchDepartAt's
    // doc for why those two aren't the same thing for a real scheduled
    // service.
    final fastest = options.reduce(
      (a, b) => a.totalElapsedFromSearch <= b.totalElapsedFromSearch ? a : b,
    );

    return [
      for (final option in options)
        RideOption(
          id: option.id,
          title: option.title,
          legs: option.legs,
          estCostRm: option.estCostRm,
          co2Kg: option.co2Kg,
          isLiveData: option.isLiveData,
          path: option.path,
          searchDepartAt: option.searchDepartAt,
          tags: [
            if (option.id == greenest.id) 'Low Carbon',
            if (option.id == cheapest.id) 'Cost Effective',
            if (option.id == fastest.id) 'Fastest',
            'On Time',
          ],
        ),
    ];
  }

  String _waypointLabel(TransportMode previousMode) {
    switch (previousMode) {
      case TransportMode.train:
        return 'KTM Interchange';
      case TransportMode.bus:
        return 'Bus Terminal';
      case TransportMode.ferry:
        return 'Ferry Terminal';
      case TransportMode.mrt:
        return 'MRT Interchange';
      case TransportMode.bike:
        return 'Bike Station';
      case TransportMode.walk:
      case TransportMode.taxi:
      case TransportMode.other:
        return 'Transfer Point';
    }
  }

  String _serviceName(TransportMode mode, {required bool longHaul}) {
    switch (mode) {
      case TransportMode.train:
        return 'KTM Komuter';
      case TransportMode.bus:
        return longHaul ? 'Express Bus' : 'RapidKL Bus';
      case TransportMode.ferry:
        return 'Ferry';
      case TransportMode.mrt:
        return 'MRT';
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.taxi:
        return 'E-hailing';
      case TransportMode.bike:
        return 'Shared Bike';
      case TransportMode.other:
        return 'Transit';
    }
  }

  static const _speedKmh = {
    TransportMode.train: 45.0,
    TransportMode.mrt: 33.0,
    TransportMode.bus: 55.0,
    TransportMode.ferry: 24.0,
    TransportMode.walk: 4.5,
    TransportMode.taxi: 38.0,
    // Typical docked-bike-share riding speed in mixed city traffic.
    TransportMode.bike: 15.0,
    TransportMode.other: 30.0,
  };

  static const _costPerKm = kCostPerKmByMode;

  static const _co2PerKm = kCo2PerKmByMode;

  /// Rough (min, max) minutes-to-wait-for-the-next-departure by mode,
  /// loosely based on typical Klang Valley service frequencies - MRT runs
  /// often, KTM Komuter and ferries much less often, e-hailing is usually
  /// a short driver ETA rather than a fixed schedule. There's no real
  /// live timetable behind this (see the class-level note); it exists so
  /// the mock timeline doesn't imply you catch every vehicle the instant
  /// you show up. Walk has no entry - you don't "wait" to walk.
  static const _waitMinutesRangeByMode = <TransportMode, (int, int)>{
    TransportMode.mrt: (4, 9),
    TransportMode.bus: (8, 18),
    TransportMode.train: (15, 25),
    TransportMode.ferry: (20, 40),
    TransportMode.taxi: (3, 8),
    TransportMode.other: (10, 15),
  };

  /// Approximate (first-service, last-service) time-of-day, in minutes
  /// since midnight, for each scheduled mode - loosely typical Klang
  /// Valley operating hours, not the real published timetable for any
  /// specific line. Taxi/e-hailing and walking have no entry here (no
  /// operating-hours restriction: a driver or your own feet are available
  /// any time of day).
  static const _serviceWindowByMode = <TransportMode, (int, int)>{
    TransportMode.mrt: (6 * 60, 23 * 60 + 30), // 06:00-23:30
    TransportMode.bus: (6 * 60, 23 * 60), // 06:00-23:00
    TransportMode.train: (6 * 60, 23 * 60), // 06:00-23:00
    TransportMode.ferry: (7 * 60, 19 * 60), // 07:00-19:00
    TransportMode.other: (6 * 60, 23 * 60), // 06:00-23:00
  };

  /// If [from] falls outside [mode]'s daily service window, returns the
  /// next moment that mode is actually running (today's opening time, or
  /// tomorrow's if [from] is already past closing) - instead of pretending
  /// a scheduled vehicle exists at any hour. Modes with no entry in
  /// [_serviceWindowByMode] (taxi, walk) are always available, so [from]
  /// is returned unchanged.
  DateTime _nextAvailableDeparture(DateTime from, TransportMode mode) {
    final window = _serviceWindowByMode[mode];
    if (window == null) return from;

    final (openMinute, closeMinute) = window;
    final minuteOfDay = from.hour * 60 + from.minute;
    final dayStart = DateTime(from.year, from.month, from.day);

    if (minuteOfDay < openMinute) {
      return dayStart.add(Duration(minutes: openMinute));
    }
    if (minuteOfDay >= closeMinute) {
      final tomorrow = dayStart.add(const Duration(days: 1));
      return tomorrow.add(Duration(minutes: openMinute));
    }
    return from;
  }
}

class _RouteTemplate {
  const _RouteTemplate(this.title, this.modes);
  final String title;
  final List<TransportMode> modes;
}

/// Rough cost/emissions-per-km assumptions, shared by the offline mock
/// generator and used to *estimate* cost/CO2 for legs coming back from the
/// live HERE API (which doesn't return fare/CO2 data itself).
const kCostPerKmByMode = {
  TransportMode.train: 0.12,
  TransportMode.mrt: 0.16,
  TransportMode.bus: 0.10,
  TransportMode.ferry: 0.25,
  TransportMode.walk: 0.0,
  TransportMode.taxi: 1.35,
  // Rough per-km equivalent of a typical docked-bike-share flat unlock fee
  // plus per-minute charge - cheaper than every motorised option.
  TransportMode.bike: 0.15,
  TransportMode.other: 0.15,
};

const kCo2PerKmByMode = {
  TransportMode.train: 0.020,
  TransportMode.mrt: 0.018,
  TransportMode.bus: 0.055,
  TransportMode.ferry: 0.045,
  TransportMode.walk: 0.0,
  TransportMode.taxi: 0.150,
  // Human-powered - genuinely zero direct emissions, same as walking.
  TransportMode.bike: 0.0,
  TransportMode.other: 0.05,
};

/// Great-circle distance in kilometres between two points.
double _haversineKm(LocationPoint a, LocationPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(b.lat - a.lat);
  final dLng = _degToRad(b.lng - a.lng);
  final lat1 = _degToRad(a.lat);
  final lat2 = _degToRad(b.lat);

  final h =
      sin(dLat / 2) * sin(dLat / 2) +
      sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
  final c = 2 * atan2(sqrt(h), sqrt(1 - h));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;
