import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_transit_service.dart';
import 'osm_bike_share_service.dart';
import 'transit_hop_finder.dart';

class RouteSearchResult {
  const RouteSearchResult({required this.options, required this.isLive});

  final List<RideOption> options;

  final bool isLive;
}

class TransportService {
  TransportService._internal();

  static final TransportService instance = TransportService._internal();

  HereTransitService? _here;
  final OsmBikeShareService _osmBike = OsmBikeShareService();

  static const _cacheTtl = Duration(hours: 12);

  Future<RouteSearchResult> search({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    await ApiConfig.ensureLoaded();
    final cacheKey = _cacheKeyFor(from, to, departAt);

    final cached = await _readCache(cacheKey);
    if (cached != null) return cached;

    if (ApiConfig.hasHereApiKey) {
      try {
        _here ??= HereTransitService();
        final here = _here!;
        var transitOptions = await here.search(
          from: from,
          to: to,
          departAt: departAt,
        );

        try {
          transitOptions = await _withAccessAlternatives(
            transitOptions,
            here: here,
            from: from,
            to: to,
          );
        } catch (_) {
          // Ignore - keep the original transit options as-is.
        }

        var intermodalOptions = const <RideOption>[];
        try {
          intermodalOptions = await here.searchIntermodal(
            from: from,
            to: to,
            departAt: departAt,
          );
        } catch (_) {
          // Ignore - intermodal combinations are a bonus, not a
          // requirement.
        }

        var osmBikeOptions = const <RideOption>[];
        try {
          osmBikeOptions = await _osmBike.searchBikeShare(
            from: from,
            to: to,
            departAt: departAt,
            here: here,
          );
        } catch (_) {
          // Ignore - a different real data source for the same bonus.
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
                ...transitOptions,
                ...intermodalOptions,
                ...osmBikeOptions,
                ?driveOption,
              ])
              .where(
                (option) =>
                    _isBikeShareOption(option) || !_hasExcessiveWalk(option),
              )
              .where((option) => !_hasExcessiveWait(option))
              .map(_tagIfWalkOnlyLong)
              .toList(),
          isLive: true,
        );
        await _writeCache(cacheKey, result);
        return result;
      } catch (_) {
        // Fall through to the calculated-only result below.
      }
    }

    var osmBikeOptions = const <RideOption>[];
    try {
      osmBikeOptions = await _osmBike.searchBikeShare(
        from: from,
        to: to,
        departAt: departAt,
        here: _here,
      );
    } catch (_) {
      // Ignore - bike-share is a bonus, not a requirement.
    }

    final filteredOsmBikeOptions = _dedupeByMode(
      osmBikeOptions,
    ).map(_tagIfWalkOnlyLong).toList();
    final result = RouteSearchResult(
      options: filteredOsmBikeOptions,
      isLive: filteredOsmBikeOptions.isNotEmpty,
    );
    await _writeCache(cacheKey, result);
    return result;
  }

  Future<List<RideOption>> _withAccessAlternatives(
    List<RideOption> options, {
    required HereTransitService here,
    required LocationPoint from,
    required LocationPoint to,
  }) async {
    final result = <RideOption>[];
    var checksLeft = _maxAccessAlternativeChecks;

    final hopCache = <String, RideOption?>{};
    String hopCacheKey(LocationPoint a, LocationPoint b, DateTime at) =>
        '${a.name}>${b.name}@${at.year}-${at.month}-${at.day}-'
        '${at.hour}-${at.minute}';

    Future<RideOption?> hopOrCached({
      required LocationPoint hopFrom,
      required LocationPoint hopTo,
      required DateTime hopDepartAt,
      required double hopPlainWalkKm,
    }) async {
      final key = hopCacheKey(hopFrom, hopTo, hopDepartAt);
      if (hopCache.containsKey(key)) return hopCache[key];
      if (checksLeft <= 0) return null;
      checksLeft--;
      final hop = await findTransitHop(
        here: here,
        from: hopFrom,
        to: hopTo,
        departAt: hopDepartAt,
        plainWalkKm: hopPlainWalkKm,
      );
      hopCache[key] = hop;
      return hop;
    }

    for (final option in options) {
      result.add(option);
      if (checksLeft <= 0 || option.legs.length < 3) continue;

      final firstLeg = option.legs.first;
      final lastLeg = option.legs.last;
      final firstIsLongAccessWalk =
          firstLeg.mode == TransportMode.walk &&
          !firstLeg.isTransfer &&
          firstLeg.endPoint != null &&
          (firstLeg.distanceKm ?? 0) > kLongWalkThresholdKm;
      final lastIsLongEgressWalk =
          lastLeg.mode == TransportMode.walk &&
          !lastLeg.isTransfer &&
          lastLeg.startPoint != null &&
          (lastLeg.distanceKm ?? 0) > kLongWalkThresholdKm;
      if (!firstIsLongAccessWalk && !lastIsLongEgressWalk) continue;

      RideOption? accessHop;
      if (firstIsLongAccessWalk) {
        final hop = await hopOrCached(
          hopFrom: from,
          hopTo: firstLeg.endPoint!,
          hopDepartAt: firstLeg.start,
          hopPlainWalkKm: firstLeg.distanceKm!,
        );
        // Only usable if it genuinely arrives in time to catch this
        // option's next real leg as HERE scheduled it.
        if (hop != null && !hop.legs.last.end.isAfter(option.legs[1].start)) {
          accessHop = hop;
        }
      }

      RideOption? egressHop;
      if (lastIsLongEgressWalk) {
        final arrivalBeforeEgress = option.legs[option.legs.length - 2].end;
        egressHop = await hopOrCached(
          hopFrom: lastLeg.startPoint!,
          hopTo: to,
          hopDepartAt: arrivalBeforeEgress,
          hopPlainWalkKm: lastLeg.distanceKm!,
        );
      }

      if (accessHop == null && egressHop == null) continue;

      final legs = <TripLeg>[];
      if (accessHop != null) {
        legs.addAll(asLeadingSegment(accessHop.legs));
      } else {
        legs.add(firstLeg);
      }
      legs.addAll(option.legs.sublist(1, option.legs.length - 1));
      if (egressHop != null) {
        legs.addAll(asTrailingSegment(egressHop.legs));
      } else {
        legs.add(lastLeg);
      }

      final busLabels = <String>[
        if (accessHop != null) ...hopRouteLabels(accessHop),
        if (egressHop != null) ...hopRouteLabels(egressHop),
      ];
      final title = busLabels.isEmpty
          ? option.title
          : 'Bus (${busLabels.join(' + ')}) + ${option.title}';
      final tags = [...option.tags, 'Bus to Stop'];
      final id =
          '${option.id}-accesshop-${accessHop != null}-${egressHop != null}'
              .hashCode
              .toString();

      result.add(
        RideOption(
          id: id,
          title: title,
          legs: mergeAdjacentWalkLegs(legs),
          estCostRm:
              option.estCostRm +
              (accessHop?.estCostRm ?? 0) +
              (egressHop?.estCostRm ?? 0),
          co2Kg:
              option.co2Kg + (accessHop?.co2Kg ?? 0) + (egressHop?.co2Kg ?? 0),
          isLiveData: true,
          searchDepartAt: option.searchDepartAt,
          tags: tags,
          path: option.path,
        ),
      );
    }
    return result;
  }

  static const _maxAccessAlternativeChecks = 6;

  bool _arrivesNextDay(RideOption option, DateTime departAt) {
    if (option.legs.isEmpty) return false;
    final arrival = option.legs.last.end;
    return arrival.year != departAt.year ||
        arrival.month != departAt.month ||
        arrival.day != departAt.day;
  }

  Future<List<RideOption>> findLegAlternatives({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
  }) async {
    if (!ApiConfig.hasHereApiKey) return const [];
    try {
      await ApiConfig.ensureLoaded();
      _here ??= HereTransitService();
      final options = await _here!.search(
        from: from,
        to: to,
        departAt: departAt,
      );
      final sameDayOptions = options
          .where((option) => !_arrivesNextDay(option, departAt))
          .toList();
      sameDayOptions.sort(
        (a, b) => a.totalElapsedFromSearch.compareTo(b.totalElapsedFromSearch),
      );
      return sameDayOptions;
    } catch (error) {
      debugPrint('[TransportService] findLegAlternatives failed: $error');
      return const [];
    }
  }

  Future<RideOption?> findAutomaticLegReplacement({
    required LocationPoint from,
    required LocationPoint to,
    required DateTime departAt,
    required double plainWalkKm,
  }) async {
    if (!ApiConfig.hasHereApiKey) return null;
    try {
      await ApiConfig.ensureLoaded();
      _here ??= HereTransitService();
      return await findTransitHop(
        here: _here,
        from: from,
        to: to,
        departAt: departAt,
        plainWalkKm: plainWalkKm,
      );
    } catch (error) {
      debugPrint(
        '[TransportService] findAutomaticLegReplacement failed: $error',
      );
      return null;
    }
  }

  bool _isPureWalk(RideOption option) {
    return !option.legs.any(
      (leg) => !leg.isTransfer && leg.mode != TransportMode.walk,
    );
  }

  bool _hasOverLimitWalk(RideOption option) {
    return option.legs.any(
      (leg) =>
          leg.mode == TransportMode.walk &&
          leg.duration.inMinutes > kMaxWalkLegMinutes,
    );
  }

  bool _hasExcessiveWalk(RideOption option) {
    return !_isPureWalk(option) && _hasOverLimitWalk(option);
  }

  bool _isBikeShareOption(RideOption option) {
    return option.legs.any((leg) => leg.mode == TransportMode.bike);
  }

  bool _hasExcessiveWait(RideOption option) {
    if (option.waitBeforeDeparture.inMinutes >
        kMaxWaitBeforeDepartureMinutes) {
      return true;
    }
    for (var i = 1; i < option.legs.length; i++) {
      final gap = option.legs[i].start.difference(option.legs[i - 1].end);
      if (gap.inMinutes > kMaxWaitBeforeDepartureMinutes) return true;
    }
    return false;
  }

  RideOption _withTag(RideOption option, String tag) {
    return RideOption(
      id: option.id,
      title: option.title,
      legs: option.legs,
      estCostRm: option.estCostRm,
      co2Kg: option.co2Kg,
      tags: [tag, ...option.tags],
      isLiveData: option.isLiveData,
      path: option.path,
      searchDepartAt: option.searchDepartAt,
      delayEstimate: option.delayEstimate,
    );
  }

  RideOption _tagIfWalkOnlyLong(RideOption option) {
    if (_isPureWalk(option) &&
        _hasOverLimitWalk(option) &&
        !option.tags.contains(kWalkOnlyLongTag)) {
      return _withTag(option, kWalkOnlyLongTag);
    }
    return option;
  }

  List<RideOption> _dedupeByMode(List<RideOption> options) {
    final bestByModeKey = <String, RideOption>{};
    for (final option in options) {
      final key = _modeKey(option);
      final existing = bestByModeKey[key];
      if (existing == null ||
          option.totalElapsedFromSearch < existing.totalElapsedFromSearch) {
        bestByModeKey[key] = option;
      }
    }
    return bestByModeKey.values.toList();
  }

  String _modeKey(RideOption option) {
    return option.legs
        .where((leg) => !leg.isTransfer)
        .map((leg) => leg.mode.name)
        .join('|');
  }

  String _cacheKeyFor(LocationPoint from, LocationPoint to, DateTime departAt) {
    return 'route_cache_v24_${from.name}__${to.name}__'
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
