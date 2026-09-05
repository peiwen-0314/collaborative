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

  /// True if the live HERE API contributed to [options] (possibly served
  /// from cache), false if every option came from the offline calculated
  /// generator and/or OSM.
  final bool isLive;
}

/// Single entry point the UI calls to search for rides.
///
///  1. On-device cache for this exact from/to/hour (avoids burning HERE's
///     free monthly quota while iterating on the UI during development).
///  2. When a live HERE key is configured and the calls succeed, every
///     option comes from real data HERE itself returned for this route:
///     [HereTransitService.search] (its own real transit alternatives -
///     already real multi-leg combinations, e.g. "Bus + Walk" or
///     "Train + Bus" - HERE computed those, not this app),
///     [HereTransitService.searchIntermodal] (a real HERE-computed route
///     that can genuinely combine transit with a real taxi leg or a real
///     *shared* bike leg in ONE coherent route - HERE's Intermodal
///     Routing API v8 has `transit[enable]`/`taxi[enable]`/
///     `rented[enable]` all on by default, so this one call alone can
///     surface a real "Transit + Taxi" or "Transit + Shared Bike" option
///     whenever HERE itself judges one worth offering),
///     [HereTransitService.searchDrive] (a real door-to-door driving/taxi
///     route), and [OsmBikeShareService] (real OpenStreetMap shared-bike
///     *station* data, independent of whether HERE has bike-share
///     operator data for this area). Every one of these is a real API
///     response - this app never recombines or invents a route out of
///     pieces from different real calls.
///
///     Deliberately NOT called here: [HereTransitService.searchBikeAndRide]
///     - HERE's *personal*, non-shared bike mode. This app's "Bike"
///     option is meant to mean bike-*sharing* (a real dock you pick up
///     from and drop off at, per [OsmBikeShareService]/the `rented`
///     sections [searchIntermodal] can return) - a personal bike a rider
///     already owns isn't that, so it's excluded rather than shown
///     alongside real bike-share and risk being mistaken for it.
///  3. No fabricated fallback: when step 2 isn't available at all - no
///     HERE key configured, or every live call above failed outright -
///     this returns whatever real data [OsmBikeShareService] alone could
///     still find (it queries OpenStreetMap directly, independent of
///     HERE), or an empty result if even that found nothing. This used
///     to fall back to MockTransportRepository's calculated/offline
///     generator instead, so the module always showed *something* - but
///     a fabricated route/time looked and got reported as real, which is
///     worse than an honest "no routes found" empty state. That
///     generator is still used elsewhere in the transportation module
///     (see [TransportController.recommendedRideTo]'s doc comment) where
///     there's no real alternative to fall back to at all yet - just not
///     as a silent substitute for a real search here.
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

        // Best-effort: a plain transit option can genuinely start or end
        // with a long walk (HERE simply picked the nearest usable stop) -
        // this offers a real bus/train alternative for that access/egress
        // walk as an ADDITIONAL option, never replacing the original. Any
        // failure here just means fewer alternatives, never breaks the
        // main transit search - same as every other bonus call in this
        // method.
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

        // Best-effort extras: HERE's Public Transit API above only ever
        // returns public-transit + walk combinations - it has no concept
        // of a taxi leg or a bike leg at all, so without these separate
        // real calls a live search could never show "Taxi" or "Bike" (or
        // a real "Transit + Taxi" combination) no matter how many transit
        // alternatives HERE itself returned. None of these are allowed to
        // affect the transit search's own success/failure - a failure
        // here just means that one bonus real option doesn't get added.
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
            // Lets a long walk to/from the bike station be swapped for a
            // real HERE bus/train hop instead - see
            // OsmBikeShareService._buildOptions / findTransitHop.
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
          ]),
          isLive: true,
        );
        await _writeCache(cacheKey, result);
        return result;
      } catch (_) {
        // Fall through to the calculated-only result below.
      }
    }

    // No live key, or every live call above failed outright. Used to
    // fall back to MockTransportRepository's calculated/offline generator
    // here so the module always showed *something* - deliberately
    // removed: fabricated routes/times looked and were reported as real,
    // which is worse than an honest empty result. OsmBikeShareService is
    // kept - it's a real, independent OpenStreetMap query, not a mock -
    // so a genuine real bike-share option can still surface even when
    // HERE itself is unreachable/unconfigured.
    var osmBikeOptions = const <RideOption>[];
    try {
      osmBikeOptions = await _osmBike.searchBikeShare(
        from: from,
        to: to,
        departAt: departAt,
        // `_here` may already be set even on this fallback path (e.g. the
        // live transit call above failed after it was created) - reuse it
        // so the first/last-mile bus check still works; null here just
        // means OsmBikeShareService falls back to plain walk legs.
        here: _here,
      );
    } catch (_) {
      // Ignore - bike-share is a bonus, not a requirement.
    }

    final result = RouteSearchResult(
      options: _dedupeByMode(osmBikeOptions),
      // True only if OsmBikeShareService actually found something real -
      // an empty list here means no real data at all was available for
      // this trip, not "showing something else instead".
      isLive: osmBikeOptions.isNotEmpty,
    );
    await _writeCache(cacheKey, result);
    return result;
  }

  /// For each live transit option (capped to the first
  /// [_maxAccessAlternativeChecks] - each check is a real extra HERE call,
  /// and `alternatives=5` can return several), checks whether its very
  /// first leg (the walk from the real origin to HERE's chosen first
  /// stop) or very last leg (walk from HERE's chosen last stop to the
  /// real destination) is long enough to be worth checking a real bus/
  /// train for instead (see findTransitHop/kLongWalkThresholdKm). A
  /// genuinely usable hop is appended as an ADDITIONAL alternative
  /// option, never replacing the original - see findTransitHop's doc
  /// comment for why a hop slower than walking still counts as a real,
  /// valid choice worth offering rather than a broken one to hide.
  ///
  /// An access (first-leg) swap is only kept when the hop's own real
  /// arrival is still in time to catch the option's next real leg as
  /// HERE scheduled it - otherwise the composed itinerary would show
  /// someone boarding a bus that, in reality, already left. An egress
  /// (last-leg) swap has no such risk: it's queried starting from the
  /// option's own real arrival time, so whatever HERE returns is
  /// inherently reachable from there.
  Future<List<RideOption>> _withAccessAlternatives(
    List<RideOption> options, {
    required HereTransitService here,
    required LocationPoint from,
    required LocationPoint to,
  }) async {
    final result = <RideOption>[];
    var checksLeft = _maxAccessAlternativeChecks;

    // Several of HERE's own raw alternatives can share the exact same
    // "walk from the real origin to stop X" (or "...to the real
    // destination") leg - e.g. four different onward bus continuations
    // that all still begin by walking to the same first stop. Without
    // this, every one of those near-duplicate options spent one of the
    // small [checksLeft] budget re-asking HERE the SAME real question
    // ("is there a bus for this exact walk, at this exact minute?") and
    // getting the SAME answer - which could burn through the whole
    // budget on repeats of one physical hop before ever reaching a
    // later option that has a genuinely different access walk of its
    // own. Keyed on the physical endpoints + the minute queried (the
    // same granularity findTransitHop's own answer depends on), so two
    // options only share a cache entry when they'd genuinely get HERE's
    // same answer anyway - this never changes what any individual
    // lookup returns, it only avoids asking twice for the same thing.
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
        // Restyle this hop's own last leg from "end of a standalone
        // route" to "mid-trip transfer", since it no longer ends the
        // whole itinerary here - see asLeadingSegment's doc comment.
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

      // Walk legs contribute exactly RM0.00 / 0kg CO2 (see
      // kCostPerKmByMode/kCo2PerKmByMode) - swapping one for a real hop
      // never needs subtracting anything, only adding the hop's own
      // real cost/CO2 on top of the original option's totals.
      //
      // Both hops' real bus numbers grouped into ONE "Bus (104 + 11)"
      // segment ahead of the original option's own title, rather than a
      // separate "Bus" word per hop (which used to read as "Bus + Bus
      // + Bus" when the original option was itself already a bus).
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
          // Splicing a hop's own boundary walk next to option's own
          // untouched walk leg (accessHop null but egressHop spliced,
          // or vice versa) can otherwise leave two "Walk" boxes back to
          // back - see mergeAdjacentWalkLegs' doc comment.
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

  /// Real extra HERE calls, capped so one search's `alternatives=5` can't
  /// silently burn 10 extra calls checking access/egress walks for every
  /// single alternative - the first few alternatives HERE returns are
  /// already its own best picks, so checking those covers the case that
  /// actually matters. Now that identical physical hops are deduped via
  /// [hopOrCached] above (several raw alternatives can share the exact
  /// same access walk), this budget is spent on genuinely distinct
  /// checks instead of repeats of the same one - raised from 4 to 6
  /// accordingly, since a repeat no longer costs anything but a
  /// genuinely new access/egress walk still does.
  static const _maxAccessAlternativeChecks = 6;

  /// Every real HERE alternative for one specific leg's own start->end,
  /// at that leg's own real departure time - the manual counterpart to
  /// [findTransitHop]/[_withAccessAlternatives] above: those pick ONE
  /// alternative automatically (the soonest-arriving valid one), this
  /// returns every real alternative HERE has so TripDetailsPage's Edit
  /// feature can let a person choose for themselves (e.g. "I don't want
  /// to walk 29 min for the 101, I'd rather take the 104" - the person's
  /// own preference, not something a "faster/slower than walking" rule
  /// could ever decide for them). Sorted soonest-arriving first, same as
  /// findTransitHop's own ranking. Returns an empty list (never throws)
  /// when there's no live HERE key configured or the call fails for any
  /// reason - the caller (a bottom sheet) shows "no alternatives found"
  /// for that the same way it would show zero results either way.
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
      options.sort(
        (a, b) => a.totalElapsedFromSearch.compareTo(b.totalElapsedFromSearch),
      );
      return options;
    } catch (error) {
      debugPrint('[TransportService] findLegAlternatives failed: $error');
      return const [];
    }
  }

  /// Automatically picks ONE real replacement for a single leg - unlike
  /// [findLegAlternatives] (which returns everything for a person to
  /// choose from), this is for a fully automatic swap where nobody is
  /// present to pick, e.g. SavedListPage's "it's raining near your saved
  /// bike leg, swap it?" prompt: once the person says yes, something
  /// real has to be picked without asking them again. Reuses
  /// [findTransitHop]'s own real-data validity checks (a genuinely
  /// broken/unusable HERE result is never returned) and, importantly,
  /// its rule that a pure-walk result doesn't count as a real
  /// alternative - the whole point of this call is finding something
  /// that ISN'T just walking (or biking) in the rain.
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

  /// Keeps only one option per distinct mode combination - keyed by each
  /// option's actual sequence of non-transfer leg modes (e.g. `bike|mrt`),
  /// not by [RideOption.title]. This matters most because [search] now
  /// calls several real HERE endpoints that can legitimately return
  /// overlapping results for the same real-world trip - e.g. plain
  /// [HereTransitService.search] and [HereTransitService.searchIntermodal]
  /// can both come back with a plain "Bus" route, or `alternatives=5` can
  /// come back with several routes that all use the same modes (three bus
  /// routes that differ only in which road/stop they take) - which reads
  /// as noisy near-duplicates rather than genuinely different ways to
  /// make the trip. Keeps whichever duplicate gets you there soonest
  /// overall (see [RideOption.totalElapsedFromSearch] - NOT
  /// [RideOption.totalDuration], which ignores how long a real scheduled
  /// service might make you wait before it even starts), since that's the
  /// most defensible single "best" representative of a mode combination
  /// to show when only one is going to be shown.
  ///
  /// Final display order still comes from `RouteRecommender.rank` in the
  /// UI layer afterwards - this only controls which options survive to be
  /// ranked, not what order they come out in here.
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

  /// The sequence of actual travel modes in [option], skipping the small
  /// "Wait for ..." / "Transfer" legs in between - two options that use
  /// the same modes in the same order are the same real-world way to make
  /// the trip, whatever each source happened to title them.
  String _modeKey(RideOption option) {
    return option.legs
        .where((leg) => !leg.isTransfer)
        .map((leg) => leg.mode.name)
        .join('|');
  }

  String _cacheKeyFor(LocationPoint from, LocationPoint to, DateTime departAt) {
    // Keyed down to the minute - a coarser key (e.g. by hour) means picking
    // a different time within the same hour would silently return the
    // previous, now-stale result instead of a fresh search.
    //
    // The "v11" here matters: every time what a search *produces* changes
    // shape (new fields, new logic, a whole new option type), old cached
    // entries are stale but would still deserialize "successfully" via
    // RideOption.fromJson - so bumping this version string is what
    // actually invalidates them, forcing a fresh search instead of
    // silently replaying pre-change results. (...; v9->v10 replaced the
    // synthetic "splice two real legs together" step with a proper HERE
    // Intermodal Routing API call (searchIntermodal, transit/taxi/
    // rented-bike at their real default-enabled availability) plus
    // searchBikeAndRide for HERE's *personal*-bike mode; v10->v11 removed
    // searchBikeAndRide from the merged result entirely - this app's
    // "Bike" is meant to mean real bike-*sharing*, and a personal-bike
    // leg risked being mistaken for a real shared-bike station that was
    // never actually asserted; v11->v12 let OsmBikeShareService swap a
    // long walk to/from the bike station for a real HERE bus/train hop,
    // which changes that option's legs/tags shape; v12->v13 lowered the
    // walk-length threshold that triggers that check, and fixed two bugs
    // in it - a broken negative-duration comparison, and a browser-only
    // CORS/User-Agent failure that silently dropped Shared Bike options
    // entirely on web; v13->v14 stopped OsmBikeShareService discarding a
    // real bus/train hop just because it was slower than walking - it's
    // now offered as a second, separate Shared Bike option instead of
    // one option silently choosing for the rider, so a single search can
    // now return two Shared Bike options where it used to return one;
    // v14->v15 added _withAccessAlternatives, which does the same
    // 'offer a real bus for a long walk' check for a plain live transit
    // option's own leading/trailing access or egress walk, not just
    // OsmBikeShareService's bike-station walks - so a single live
    // transit alternative can now also spawn an extra option; v15->v16
    // fixed two bugs in that splicing: a spliced hop's own boundary walk
    // leg kept the isTransfer flag from its own standalone sub-search
    // (wrong once it's a mid-trip transfer - see asLeadingSegment/
    // asTrailingSegment), and the last-mile hop for OsmBikeShareService
    // was anchored to the WALK-only option's timing even when the
    // transit variant's first mile took a different amount of time,
    // which could splice in a last-mile bus at an inconsistent time;
    // v16->v17 fixed the actual root cause behind both of those still
    // showing up - findTransitHop could return a HERE alternative whose
    // own reported schedule didn't line up with the requested time at
    // all (arriving before it 'departed'), which no amount of anchoring
    // upstream could fix; it now discards that alternative outright
    // instead of splicing in a broken absolute timeline. Also fixed the
    // access/egress subtitle on a HERE-parsed walk leg always saying
    // "Transfer" even when it wasn't styled as one; v17->v18 changed how
    // a combined itinerary with more than one real hop shows its route
    // numbers - it used to mention "Bus" once per hop (e.g. "Bus +
    // Shared Bike + Bus (104 + 11)"), now every hop's real numbers are
    // grouped into one segment via the new hopRouteLabels helper (e.g.
    // "Bus (104 + 11) + Shared Bike"), and RideOption.routeSummary no
    // longer double-appends a number that's already baked into the
    // title this way. Also swapped the synthetic "Change here" timeline
    // marker's title/subtitle - it now shows the real route numbers
    // (e.g. "104 -> 101") as its main text and "Transfer" as the small
    // subtitle, matching every other transfer card instead of hiding
    // the numbers in the subtitle; v18->v19 fixed findTransitHop
    // returning a pure-walking "hop" as if it were a real transit
    // alternative when HERE genuinely has no bus/train for that stretch
    // - a caller splicing that in produced a second option that was
    // really just the same walk again, restyled from a green "Walk" box
    // into a white "Transfer" box with a different cost, which read as
    // two options differing only by box color. Such a hop is now
    // treated exactly like "HERE found nothing"; v19->v20 fixed
    // _withAccessAlternatives wasting its small per-search check budget
    // re-asking HERE the exact same access/egress question for several
    // raw alternatives that happen to share the same physical walk
    // (several onward bus continuations can all start with the same
    // walk to the same first stop) - those repeats are now served from
    // an in-memory cache instead of a fresh HERE call, and the budget
    // itself was raised from 4 to 6 real checks per search now that it
    // isn't being spent on repeats. This doesn't change any individual
    // hop's answer, only how many options actually get a chance to be
    // checked before the budget runs out; v20->v21 added
    // mergeAdjacentWalkLegs, called wherever a hop's own boundary walk
    // gets spliced next to an option's existing walk leg (both here and
    // in OsmBikeShareService._composeOption) - without it, two walk
    // legs that are really one continuous walk could show up as two
    // separate "Walk" boxes back to back in the timeline; v21->v22
    // fixed HereTransitService._parseRoute's RM1.50 minimum-fare floor
    // applying even to a route that's genuinely just walking the whole
    // way (no real bus/train leg at all) - that floor exists to guard
    // against an unrealistically tiny fare for a route that DOES ride
    // something real, not to charge a real "Walk only" alternative
    // (see TripDetailsPage's Edit-a-leg picker) money it should never
    // cost.)
    return 'route_cache_v22_${from.name}__${to.name}__'
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
