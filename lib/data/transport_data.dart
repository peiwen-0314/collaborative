import 'dart:math';

import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import '../services/real_transit_stop_service.dart';

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

/// Calculates realistic ride options for [from]/[to] from real data, not a
/// fixed template list: it asks [RealTransitStopService] what bus stops
/// and rail stations OpenStreetMap actually has mapped near both ends
/// (the same real-data approach OsmBikeShareService already uses for
/// shared bikes), only offers "Bus"/"MRT"/"KTM Komuter" when a genuine
/// stop/station is there to use, and then *calculates* each option's
/// duration/cost/CO2 from the known per-mode speed/cost/CO2 constants
/// below - never a network fetch for the numbers themselves, only for
/// figuring out which combinations are real. Taxi has no station
/// dependency (a driver can go door to door) so it's always considered.
/// This is what feeds every search, live HERE key or not - see
/// `TransportService` for how its results get merged with HERE's.
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

    // Best-effort: a failed/slow Overpass lookup just means bus/rail
    // don't get offered this time (falls back to an empty availability,
    // same as "nothing real found nearby") - never something that should
    // block the rest of the search.
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

  /// Calculates every transportation-mode combination that's real for
  /// this specific trip, using [availability] (what
  /// [RealTransitStopService] actually found mapped near [from]/[to]) as
  /// the source of truth for bus and rail - not a distance guess. Taxi
  /// has no station dependency, so it's always included. Bike is
  /// deliberately NOT generated here at all - OsmBikeShareService already
  /// does its own real-station lookup for shared bikes and
  /// `TransportService` merges that result in separately, so calculating
  /// a second, distance-guessed "maybe there's a bike" here would just
  /// undercut the whole point of using real data.
  ///
  /// Every combination this returns still goes through [_buildOption]
  /// exactly as before - its duration/cost/CO2 come from the same
  /// distance-split plus per-mode speed/cost/CO2 constants, calculated,
  /// never fetched from anywhere. What [availability] decides is only
  /// *which* combinations are worth calculating at all.
  ///
  /// Ferry is the one exception still gated on distance alone (> 90km,
  /// same as before) rather than a real-station lookup - Overpass'
  /// coverage of ferry terminals in this region is too sparse to be a
  /// reliable signal, unlike bus stops and rail stations which are
  /// densely and reliably mapped.
  ///
  /// Pure walk is deliberately never generated here - a standalone
  /// "just walk the whole way" option isn't a realistic thing to
  /// recommend comparing against transit/car/bike for most trips this
  /// app models, so this combination generator never produces one.
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

      // The one three-leg case this app models: a long-haul KTM Komuter +
      // bus trip that also needs a ferry crossing. Still requires a real
      // KTM Komuter station at both ends (see above) on top of the
      // distance cut-off.
      if (distanceKm > 90 && railMode == TransportMode.train)
        const [TransportMode.train, TransportMode.bus, TransportMode.ferry],
    ];

    return [
      for (final modes in combos) _RouteTemplate(_titleFor(modes), modes),
    ];
  }

  /// Builds a display title from a generated combination's modes, reusing
  /// [_serviceName] (just [TransportMode.label]) for each mode - so
  /// "MRT + Bus" comes from the same generic naming this class uses for
  /// each leg, just joined together, and matches what a live HERE-derived
  /// option would call the same combination.
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
    // Computed once per option (not per leg) - a single search stays
    // within one region, and Penang/Klang Valley are this app's only two
    // demo areas, so the search's own starting point is enough. See
    // estimateFareRm/isPenangArea's doc comments.
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

  /// Just [TransportMode.label] - "Bus", "Taxi", "Train", etc. This used
  /// to return branded names ("RapidKL Bus"/"Express Bus"/"KTM Komuter"/
  /// "E-hailing") that didn't match what the live HERE-derived options
  /// call the same mode (HERE-derived titles use [TransportMode.label]
  /// directly - see HereTransitService._parseRoute), so the exact same
  /// real-world way to travel could show up under two different names
  /// depending on which source produced it. Kept as its own method
  /// (rather than calling `mode.label` inline everywhere below) so every
  /// call site here stays obviously in sync with the live side.
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

/// How long someone would need to already be willing to walk (one way,
/// at this app's assumed 4.5km/h walking speed - about 8 minutes)
/// before it's worth asking HERE whether a real bus/train covers that
/// same stretch at all - shared by every place that checks this (see
/// findTransitHop's callers: OsmBikeShareService's first/last mile to
/// a bike station, and TransportService's access/egress walk on a
/// plain live transit option). Kept low on purpose: checking is cheap
/// and never makes the walk-only option worse - a real hop only ever
/// becomes an *additional* option, never a forced replacement - so
/// it's better to check an 8-11 minute walk and find nothing than to
/// never check at all.
const kLongWalkThresholdKm = 0.6;

/// Shared tag text used by TransportController.searchRides (real-time
/// rain check via WeatherService, tags a live search result whenever it
/// rides a real bike leg while it's currently raining near the search
/// origin) and SavedListPage (same idea, but per-saved-trip, checked
/// against the bike leg's own real station location - see
/// TransportController.checkSavedTripsForRain). Kept as one shared
/// constant, not two separate literal strings, so RideCard's chip
/// styling (see MiniChip's `warning` flag) reliably recognizes it
/// wherever it was added from.
const kRainBikeTag = 'Rain - Bike Not Ideal';

/// Per-km rate used only for modes that genuinely *are* priced roughly
/// per km in real life (a taxi/e-hailing fare, a bike-share's per-minute
/// charge folded into a per-km equivalent) - see [estimateFareRm] for
/// bus/train/mrt/ferry, none of which real operators price this way (see
/// that function's doc comment for why a flat per-km rate was wrong for
/// them).
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

/// True when [point] falls within the Penang Island / Seberang Perai
/// service area used by Rapid Penang, as opposed to the Klang Valley
/// area used by RapidKL - this app's two demo regions don't overlap, so
/// a simple bounding box on the search's own starting point is enough to
/// tell their (genuinely different) bus fares apart. See
/// [estimateFareRm].
bool isPenangArea(LocationPoint point) {
  return point.lat >= 5.15 &&
      point.lat <= 5.60 &&
      point.lng >= 100.10 &&
      point.lng <= 100.55;
}

/// Real fare structures for the scheduled-service modes this app models,
/// replacing a flat "rate x distance" estimate that every one of these
/// operators' actual published fares contradicts - a Rapid bus, RapidKL
/// train, KTM Komuter or the Penang ferry all charge a
/// distance-*banded* or outright flat fare that plateaus/caps, not a
/// charge that keeps climbing forever the further you go. Sourced from
/// each operator's own published fare information (see the per-table
/// doc comments below for links/anchor points); exact intermediate band
/// boundaries for Rapid Penang and RapidKL rail are interpolated between
/// the boundary fares each operator publishes (not confirmed
/// station-by-station), and any of this can go stale if an operator
/// revises fares - update the tables below rather than reverting to a
/// flat per-km rate, which is a strictly worse approximation for all of
/// them.
/// This leg's own real fare, or null when it has no real fare of its
/// own - a walk/transfer leg (free/not its own fare), or a leg with no
/// known real distance (the offline/mock generator never stores one -
/// see [TripLeg.distanceKm]'s doc comment). The one building block both
/// [sumRealLegFares] (a whole option's accurate total, used after an
/// edit - see withLegReplaced) and TripDetailsPage's per-row fare chip
/// share, so a trip's header total and its own itinerary rows can never
/// disagree with each other the way they could before this existed
/// (see withLegReplaced's old approximate cost-subtraction comment).
double? legFareRm(TripLeg leg, {required bool isPenangArea}) {
  if (leg.isTransfer || leg.mode == TransportMode.walk) return null;
  final km = leg.distanceKm;
  if (km == null) return null;
  return estimateFareRm(leg.mode, km, isPenangArea: isPenangArea);
}

/// The accurate total fare for [legs] - just the real per-leg fares
/// ([legFareRm]) summed, computed fresh from each leg's own real
/// distance rather than carried/approximated forward from an earlier
/// total. [from] is only used to decide the Penang-vs-Klang-Valley fare
/// tables (see [isPenangArea]'s doc comment) - the same "the search's
/// own starting point is enough" convention every other per-route cost
/// calculation in this app already uses.
double sumRealLegFares(List<TripLeg> legs, LocationPoint from) {
  final penang = isPenangArea(from);
  var total = 0.0;
  for (final leg in legs) {
    total += legFareRm(leg, isPenangArea: penang) ?? 0.0;
  }
  return total;
}

/// The cost to actually SHOW for [option] - a fresh, accurate recompute
/// (see [sumRealLegFares]) whenever at least one of its legs has a real
/// fare to recompute from, falling back to [RideOption.estCostRm]
/// itself only when none do (a fully offline/mock option, whose legs
/// never carry a real distance - see [TripLeg.distanceKm]'s doc comment
/// - or a genuine walk-only live option, whose stored total is already
/// correctly RM0.00 either way). Used by TripSummary instead of trusting
/// [RideOption.estCostRm] directly, so an already-saved trip whose
/// stored total predates withLegReplaced's fix to compute the same way
/// (see that function's doc comment) self-heals on screen instead of
/// staying stuck showing a stale number that disagrees with its own
/// itinerary rows.
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
      // The Penang ferry (Butterworth <-> George Town) is a single fixed
      // crossing, not a network with distance bands - RM2.00 adult fare
      // as of writing (https://onpenang.com/butterworth-to-penang-island-ferry/).
      return 2.00;
    case TransportMode.walk:
      return 0.0;
    case TransportMode.taxi:
      // Unlike the scheduled services above, a real e-hailing/taxi fare
      // genuinely is close to a flat base charge plus a per-km rate -
      // this one wasn't the inaccurate part.
      return 3.00 + kCostPerKmByMode[TransportMode.taxi]! * distanceKm;
    case TransportMode.bike:
    case TransportMode.other:
      return kCostPerKmByMode[mode]! * distanceKm;
  }
}

/// Rapid Penang bus: distance-banded from RM1.40 for the shortest trips
/// up to RM5.00 for the longest island routes
/// (https://myrapid.com.my/bus-train/rapid-penang/,
/// https://onpenang.com/bus-guide/). The current fare chart isn't
/// published stage-by-stage, so the intermediate bands below are
/// interpolated from Rapid's own older per-km-banded structure, scaled
/// to today's published start/cap fares.
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

/// RapidKL bus: effectively a flat RM1.00 fare on the standard network
/// (https://myrapid.com.my/bus-train/rapid-kl/bus/). Outskirt feeder
/// routes run RM1.00-RM3.00 in reality; approximated here as a small
/// distance-based step for genuinely long feeder-length rides only,
/// rather than modelling every individual feeder route.
double _rapidKlBusFare(double km) {
  if (km <= 15) return 1.00;
  if (km <= 30) return 2.00;
  return 3.00;
}

/// RapidKL rail (LRT/MRT/Monorail): distance-banded, capped at the
/// network's published maximum single-journey fare of RM9.50. Banded by
/// km rather than station count (which is what RapidKL's own fare chart
/// actually uses) at a typical ~1.3km average station spacing, since
/// this app doesn't model individual stations.
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

/// KTM Komuter: distance-banded, linearly interpolated between real
/// published fare/distance points from KL Sentral (Midvalley RM1.00 at
/// ~6km, Subang Jaya RM2.30 at ~15km, Klang RM5.00 at ~30km, Port Klang
/// RM5.60 at ~35km, Tanjung Malim RM10.60 at ~74km).
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
