import 'dart:convert';

import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_transit_service.dart';
import 'osm_bike_share_service.dart';

class RouteSearchResult {
  const RouteSearchResult({required this.options, required this.isLive});

  final List<RideOption> options;

  /// True if [options] came from the real HERE API (possibly served from
  /// cache), false if they came from the offline mock generator.
  final bool isLive;
}

/// Single entry point the UI calls to search for rides. Order of attempts:
///
///  1. On-device cache for this exact from/to/hour (avoids burning HERE's
///     free monthly quota while iterating on the UI during development).
///  2. The live HERE Transit API, if a key was supplied via
///     `--dart-define=HERE_API_KEY=...`.
///  3. The offline [MockTransportRepository], used whenever no key is
///     configured, the device is offline, or HERE returns an error - so
///     the transportation module always has something to show.
class TransportService {
  TransportService._internal();

  static final TransportService instance = TransportService._internal();

  final MockTransportRepository _mock = const MockTransportRepository();
  HereTransitService? _here;
  final OsmBikeShareService _osmBike = OsmBikeShareService();

  static const _cacheTtl = Duration(hours: 12);

  Future<RouteSearchResult> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    final cacheKey = _cacheKeyFor(from, to, departAt);

    final cached = await _readCache(cacheKey);
    if (cached != null) return cached;

    // OpenStreetMap's Overpass API is free and keyless, so this real
    // shared-bike lookup runs regardless of whether a HERE key is
    // configured - see OsmBikeShareService's class doc for why this exists
    // alongside HereTransitService.searchBikeShare rather than instead of
    // it (they're independent data sources with different strengths/gaps).
    // Best-effort: never allowed to affect whether the rest of the search
    // succeeds.
    var osmBikeOptions = const <RideOption>[];
    try {
      osmBikeOptions = await _osmBike.searchBikeShare(
        from: from,
        to: to,
        departAt: departAt,
      );
    } catch (_) {
      // Ignore - bike-share is a bonus, not a requirement.
    }

    // A plain point-to-point walk is a genuine mode of its own (the user
    // should be able to compare "just walk" against transit/car/bike, not
    // only see walking as a connector leg inside some other option) and
    // needs no API at all to compute honestly - unlike the bonus lookups
    // above, this can never fail, it's just arithmetic. Returns null for
    // trips too long to sensibly walk (see the cutoff in the method doc).
    final directWalkOption = _directWalkOption(from, to, departAt);

    if (ApiConfig.hasHereApiKey) {
      try {
        _here ??= HereTransitService();
        final here = _here!;
        final options = await here.search(
          from: from,
          to: to,
          departAt: departAt,
        );

        // Best-effort extras: HERE's Public Transit API above only ever
        // returns public-transit + walk combinations - it has no concept
        // of a shared-bike leg or a private car/e-hailing leg at all, so
        // without these two separate calls a live search could never show
        // "car" or "bike" as options no matter how many transit
        // alternatives HERE itself returned. Neither is allowed to affect
        // the transit search's own success/failure - a failure here just
        // means that one bonus option doesn't get added this time.
        var hereBikeOptions = const <RideOption>[];
        try {
          hereBikeOptions = await here.searchBikeShare(
            from: from,
            to: to,
            departAt: departAt,
          );
        } catch (_) {
          // Ignore - bike-share is a bonus, not a requirement.
        }

        RideOption? driveOption;
        try {
          driveOption = await here.searchDrive(
            from: from,
            to: to,
            departAt: departAt,
          );
        } catch (_) {
          // Ignore - a drive option is a bonus, not a requirement.
        }

        final result = RouteSearchResult(
          options: _dedupeByMode([
            ...options,
            ...hereBikeOptions,
            ...osmBikeOptions,
            if (driveOption != null) driveOption,
            if (directWalkOption != null) directWalkOption,
          ]),
          isLive: true,
        );
        await _writeCache(cacheKey, result);
        return result;
      } catch (_) {
        // Fall through to the offline mock below.
      }
    }

    final mockOptions = await _mock.search(
      from: from,
      to: to,
      departAt: departAt,
    );
    // isLive stays false here even when osmBikeOptions/directWalkOption are
    // non-empty: the banner this drives ("Simulated data - configure a
    // HERE key for real routing") is about the bulk of the results (the
    // mock transit routes), and one or two genuinely-real bonus options
    // shouldn't suppress that honest disclosure. Those options still carry
    // their own tags so they're not mistaken for a mock result. (A drive
    // option isn't added here - the mock generator already has its own
    // "E-hailing" template covering that mode, there's no live HERE call
    // to fall back to without a key anyway.)
    final result = RouteSearchResult(
      options: _dedupeByMode([
        ...mockOptions,
        ...osmBikeOptions,
        if (directWalkOption != null) directWalkOption,
      ]),
      isLive: false,
    );
    await _writeCache(cacheKey, result);
    return result;
  }

  /// A plain walk from [from] straight to [to], with no API dependency -
  /// this is just arithmetic on the great-circle distance, always
  /// available and always honest about how long it'd actually take.
  /// Returns null above the walking cutoff (6km, ~80 minutes at this
  /// app's assumed 4.5km/h walking speed - see
  /// `transport_data.dart`'s `_speedKmh`) since a multi-hour "walk
  /// the whole way" card isn't a real option anyone would compare against
  /// transit/car/bike, it would just be clutter.
  RideOption? _directWalkOption(LocationPoint from, LocationPoint to, DateTime departAt) {
    const walkSpeedKmh = 4.5;
    const maxWalkableKm = 6.0;

    const distanceCalculator = ll.Distance();
    final km = distanceCalculator(
          ll.LatLng(from.lat, from.lng),
          ll.LatLng(to.lat, to.lng),
        ) /
        1000.0;
    if (km > maxWalkableKm) return null;

    final minutes = ((km / walkSpeedKmh) * 60).clamp(1, 999).round();
    final start = departAt;
    final end = start.add(Duration(minutes: minutes));

    return RideOption(
      id: 'walk-${from.name}-${to.name}-${departAt.millisecondsSinceEpoch}'.hashCode.toString(),
      title: 'Walk',
      legs: [
        TripLeg(
          mode: TransportMode.walk,
          title: 'Walk to destination',
          subtitle: '(${from.name} → ${to.name})',
          start: start,
          end: end,
        ),
      ],
      estCostRm: 0,
      co2Kg: 0,
      isLiveData: true,
      searchDepartAt: departAt,
      tags: const ['Zero Emission'],
    );
  }

  /// Keeps only one option per distinct mode combination. [RideOption.title]
  /// already encodes this - every source (HereTransitService, the offline
  /// [MockTransportRepository], [OsmBikeShareService]) builds it the same
  /// way: the set of non-walk modes used in that trip, joined together
  /// (e.g. "MRT + Bus", "Walk", "Shared Bike") - so it's a ready-made
  /// dedupe key without needing to inspect each leg again here.
  ///
  /// This matters most for HERE: asking for `alternatives=5` can come back
  /// with several routes that all use the same modes (e.g. three "Bus"
  /// options that differ only in which road/stop they take), which reads
  /// as noisy near-duplicates rather than genuinely different ways to make
  /// the trip. Keeps whichever duplicate gets you there soonest overall
  /// (see [RideOption.totalElapsedFromSearch] - NOT [RideOption.totalDuration],
  /// which ignores how long a real scheduled service might make you wait
  /// before it even starts), since that's the most defensible single
  /// "best" representative of a mode to show when only one is going to be
  /// shown.
  ///
  /// Final display order still comes from `RouteRecommender.rank` in the
  /// UI layer afterwards - this only controls which options survive to be
  /// ranked, not what order they come out in here.
  List<RideOption> _dedupeByMode(List<RideOption> options) {
    final bestByTitle = <String, RideOption>{};
    for (final option in options) {
      final existing = bestByTitle[option.title];
      if (existing == null ||
          option.totalElapsedFromSearch < existing.totalElapsedFromSearch) {
        bestByTitle[option.title] = option;
      }
    }
    return bestByTitle.values.toList();
  }

  String _cacheKeyFor(LocationPoint from, LocationPoint to, DateTime departAt) {
    // Keyed down to the minute - a coarser key (e.g. by hour) means picking
    // a different time within the same hour would silently return the
    // previous, now-stale result instead of a fresh search.
    //
    // The "v7" here matters: every time what a search *produces* changes
    // shape (new fields, new logic, a whole new option type like shared
    // bikes), old cached entries are stale but would still deserialize
    // "successfully" via RideOption.fromJson - so bumping this version
    // string is what actually invalidates them, forcing a fresh search
    // instead of silently replaying pre-change results. (v1->v2 was for
    // the minute-granularity fix; v2->v3 was for the shared-bike addition
    // and the realistic-wait/operating-hours rework; v3->v4 was for adding
    // the OpenStreetMap-based bike-share lookup; v4->v5 was for the
    // dedupe-by-mode pass; v5->v6 was for adding the live HERE driving
    // option and the always-on direct-walk option; v6->v7 is for adding
    // RideOption.searchDepartAt (fixing options with a long real wait
    // before departure looking deceptively fast) - without this, anyone
    // who already searched a given from/to/time combo before that change
    // would keep seeing the old cached result with the wait-time bug.)
    return 'route_cache_v7_${from.name}__${to.name}__'
        '${departAt.year}-${departAt.month}-${departAt.day}-'
        '${departAt.hour}-${departAt.minute}';
  }

  Future<RouteSearchResult?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(decoded['cachedAt'] as String);
      if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;

      final options = (decoded['options'] as List)
          .map((json) => RideOption.fromJson(json as Map<String, dynamic>))
          .toList();
      return RouteSearchResult(
        options: options,
        isLive: decoded['isLive'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, RouteSearchResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'cachedAt': DateTime.now().toIso8601String(),
        'isLive': result.isLive,
        'options': result.options.map((o) => o.toJson()).toList(),
      });
      await prefs.setString(key, payload);
    } catch (_) {
      // Caching is a best-effort optimisation; ignore failures.
    }
  }
}
