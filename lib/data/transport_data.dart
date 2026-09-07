import 'dart:math';

import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import '../services/real_transit_stop_service.dart';

abstract class TransportRepository {
  Future<List<RideOption>> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  });
}

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

    final distanceKm = from.distanceKm(to);
    final seed = Object.hash(from.name, to.name, departAt.year, departAt.month, departAt.day);
    final random = Random(seed);

    RealTransitAvailability availability;
    try {
      availability = await RealTransitStopService().findNearby(from: from, to: to);
    } catch (_) {
      availability = const RealTransitAvailability();
    }

    final templates = _templatesFor(distanceKm, availability);
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

  List<_RouteTemplate> _templatesFor(double distanceKm, RealTransitAvailability availability) {
    final railMode = availability.railMode;

    final combos = <List<TransportMode>>[
      // Taxi is always real - a driver can go door to door regardless of
      // what's mapped nearby.
      const [TransportMode.taxi],

      // Bus/rail solo options only exist when there's a genuine stop/
      // station within walking distance of BOTH ends.
      if (availability.busAvailable) [TransportMode.bus],
      if (railMode != null) [railMode],

      // Two-mode trips, gated the same way - both legs used still have to
      // individually be real for this route.
      if (railMode != null && availability.busAvailable) [railMode, TransportMode.bus],
      if (railMode != null) [railMode, TransportMode.walk],
      if (railMode != null) [railMode, TransportMode.taxi],
      if (availability.busAvailable) [TransportMode.bus, TransportMode.walk],

      if (distanceKm > 90 && railMode == TransportMode.train)
        const [TransportMode.train, TransportMode.bus, TransportMode.ferry],
    ];

    return [
      for (final modes in combos) _RouteTemplate(_titleFor(modes), modes),
    ];
  }

  String _titleFor(List<TransportMode> modes) {
    return modes.map(_serviceName).join(' + ');
  }

  RideOption _buildOption(
    _RouteTemplate template, {
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required double distanceKm,
    required Random random,
  }) {
    final searchIsPenang = isPenangArea(from);

    // Split the total distance across the "real" (non-transfer) legs.
    final legCount = template.modes.length;
    final shareBase = distanceKm / legCount;

    var cursor = departAt;
    final legs = <TripLeg>[];
    var totalCostRm = 0.0;
    var totalCo2Kg = 0.0;

    for (var i = 0; i < legCount; i++) {
      final mode = template.modes[i];

      cursor = _nextAvailableDeparture(cursor, mode);

      final waitRange = _waitMinutesRangeByMode[mode];
      if (waitRange != null) {
        final waitMinutes =
            waitRange.$1 + random.nextInt(waitRange.$2 - waitRange.$1 + 1);
        final waitStart = cursor;
        final waitEnd = waitStart.add(Duration(minutes: waitMinutes));
        legs.add(
          TripLeg(
            mode: mode,
            title: 'Wait for ${_serviceName(mode)}',
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

      final legDistanceKm = mode == TransportMode.walk
          ? min(shareBase, 1.125)
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
          title: _serviceName(mode),
          subtitle: '($originLabel → $destLabel)',
          start: legStart,
          end: legEnd,
        ),
      );
      // Real fares are fixed by the operator, not randomised like
      // this leg's duration jitter above - see estimateFareRm.
      totalCostRm += estimateFareRm(
        mode,
        legDistanceKm,
        isPenangArea: searchIsPenang,
      );
      totalCo2Kg += _co2PerKm[mode]! * legDistanceKm;
      cursor = legEnd;

      final isLastLeg = i == legCount - 1;
      if (!isLastLeg) {
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

  List<RideOption> _tagOptions(List<RideOption> options) {
    if (options.isEmpty) return options;
    final cheapest = options.reduce(
      (a, b) => a.estCostRm <= b.estCostRm ? a : b,
    );
    final greenest = options.reduce((a, b) => a.co2Kg <= b.co2Kg ? a : b);
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

  String _serviceName(TransportMode mode) => mode.label;

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

  static const _co2PerKm = kCo2PerKmByMode;

  static const _waitMinutesRangeByMode = <TransportMode, (int, int)>{
    TransportMode.mrt: (4, 9),
    TransportMode.bus: (8, 18),
    TransportMode.train: (15, 25),
    TransportMode.ferry: (20, 40),
    TransportMode.taxi: (3, 8),
    TransportMode.other: (10, 15),
  };

  static const _serviceWindowByMode = <TransportMode, (int, int)>{
    TransportMode.mrt: (6 * 60, 23 * 60 + 30), // 06:00-23:30
    TransportMode.bus: (6 * 60, 23 * 60), // 06:00-23:00
    TransportMode.train: (6 * 60, 23 * 60), // 06:00-23:00
    TransportMode.ferry: (7 * 60, 19 * 60), // 07:00-19:00
    TransportMode.other: (6 * 60, 23 * 60), // 06:00-23:00
  };

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

const kLongWalkThresholdKm = 0.6;

const kRainBikeTag = 'Rain - Ride Carefully';

const kWalkOnlyLongTag = 'Walk Only - No Other Route Found';

const kHazeOutdoorTag = 'Haze - Limit Outdoor Exposure';

/// Same idea as [kHazeOutdoorTag], for WeatherService's own real-time
/// extreme apparent-temperature check instead of haze.
const kExtremeHeatTag = 'Extreme Heat - Limit Outdoor Exposure';

const kShelteredPickTag = 'Weather-Safe Pick';

const kOverBudgetTag = 'Over Your Budget';

const kOverDurationTag = 'Longer Than You Want';

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

bool isPenangArea(LocationPoint point) {
  return point.lat >= 5.15 &&
      point.lat <= 5.60 &&
      point.lng >= 100.10 &&
      point.lng <= 100.55;
}

bool isInMalaysia(LocationPoint point) {
  final peninsularMalaysia =
      point.lat >= 0.85 &&
      point.lat <= 6.85 &&
      point.lng >= 99.5 &&
      point.lng <= 104.6;
  final eastMalaysia =
      point.lat >= 0.75 &&
      point.lat <= 7.5 &&
      point.lng >= 109.4 &&
      point.lng <= 119.3;
  return peninsularMalaysia || eastMalaysia;
}

const kMaxWalkLegMinutes = 12;

const kMaxWaitBeforeDepartureMinutes = 180;

const kMalaysiaUtcOffset = Duration(hours: 8);

DateTime malaysiaWallClockToInstant(DateTime wallClock) {
  return DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
  ).subtract(kMalaysiaUtcOffset);
}

DateTime instantToMalaysiaWallClock(DateTime instant) {
  return instant.toUtc().add(kMalaysiaUtcOffset);
}

double? legFareRm(TripLeg leg, {required bool isPenangArea}) {
  if (leg.isTransfer || leg.mode == TransportMode.walk) return null;
  final km = leg.distanceKm;
  if (km == null) return null;
  return estimateFareRm(leg.mode, km, isPenangArea: isPenangArea);
}

double sumRealLegFares(List<TripLeg> legs, LocationPoint from) {
  final penang = isPenangArea(from);
  var total = 0.0;
  for (final leg in legs) {
    total += legFareRm(leg, isPenangArea: penang) ?? 0.0;
  }
  return total;
}

double sumLegsCo2Kg(List<TripLeg> legs) {
  var total = 0.0;
  for (final leg in legs) {
    final km = leg.distanceKm;
    if (km == null) continue;
    total += (kCo2PerKmByMode[leg.mode] ?? 0.05) * km;
  }
  return total;
}

double displayCostRm(RideOption option, LocationPoint from) {
  final penang = isPenangArea(from);
  var sum = 0.0;
  var hasRealFare = false;
  for (final leg in option.legs) {
    final fare = legFareRm(leg, isPenangArea: penang);
    if (fare != null) {
      hasRealFare = true;
      sum += fare;
    }
  }
  return hasRealFare ? sum : option.estCostRm;
}

double estimateFareRm(
  TransportMode mode,
  double distanceKm, {
  required bool isPenangArea,
}) {
  switch (mode) {
    case TransportMode.bus:
      return isPenangArea
          ? _rapidPenangBusFare(distanceKm)
          : _rapidKlBusFare(distanceKm);
    case TransportMode.train:
      return _ktmKomuterFare(distanceKm);
    case TransportMode.mrt:
      return _rapidKlRailFare(distanceKm);
    case TransportMode.ferry:
      return 2.00;
    case TransportMode.walk:
      return 0.0;
    case TransportMode.taxi:
      return 3.00 + kCostPerKmByMode[TransportMode.taxi]! * distanceKm;
    case TransportMode.bike:
    case TransportMode.other:
      return kCostPerKmByMode[mode]! * distanceKm;
  }
}

double _rapidPenangBusFare(double km) {
  const bands = <(double, double)>[
    (7, 1.40),
    (14, 2.00),
    (21, 2.70),
    (28, 3.40),
    (35, 4.20),
  ];
  for (final (maxKm, fare) in bands) {
    if (km <= maxKm) return fare;
  }
  return 5.00; // Rapid Penang's published cap for the longest routes.
}

double _rapidKlBusFare(double km) {
  if (km <= 15) return 1.00;
  if (km <= 30) return 2.00;
  return 3.00;
}

double _rapidKlRailFare(double km) {
  const bands = <(double, double)>[
    (3, 1.20),
    (8, 2.50),
    (15, 4.00),
    (25, 6.00),
  ];
  for (final (maxKm, fare) in bands) {
    if (km <= maxKm) return fare;
  }
  return 9.50;
}

double _ktmKomuterFare(double km) {
  const points = <(double, double)>[
    (0, 0.00),
    (6, 1.00),
    (15, 2.30),
    (30, 5.00),
    (35, 5.60),
    (74, 10.60),
  ];
  for (var i = 1; i < points.length; i++) {
    final (prevKm, prevFare) = points[i - 1];
    final (nextKm, nextFare) = points[i];
    if (km <= nextKm) {
      final t = (km - prevKm) / (nextKm - prevKm);
      return prevFare + (nextFare - prevFare) * t;
    }
  }
  // Beyond the longest published anchor point - extrapolate at that last
  // segment's own rate rather than guessing an entirely new one.
  final (secondLastKm, secondLastFare) = points[points.length - 2];
  final (lastKm, lastFare) = points.last;
  final ratePerKm = (lastFare - secondLastFare) / (lastKm - secondLastKm);
  return lastFare + ratePerKm * (km - lastKm);
}

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

