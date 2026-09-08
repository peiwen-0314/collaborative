import 'package:flutter/foundation.dart' show debugPrint;

import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_transit_service.dart';

/// Recomputes a RideOption's title from its actual legs - same
/// mode-label-joining rule HereTransitService._parseRoute uses when
/// building a title from a fresh search (skip walk legs, join the
/// rest's distinct mode labels with ' + ', fall back to 'Walk' if
/// every leg was walking). withLegReplaced/withLegsReplaced below use
/// this instead of carrying the pre-edit option's title forward,
/// which used to leave a stale title (e.g. still "Taxi") after the
/// legs underneath it had actually changed mode.
String titleForLegs(List<TripLeg> legs) {
  final modeLabels = <String>[];
  for (final leg in legs) {
    if (leg.isTransfer || leg.mode == TransportMode.walk) continue;
    modeLabels.add(leg.mode.label);
  }
  return modeLabels.isEmpty ? 'Walk' : modeLabels.toSet().join(' + ');
}

Future<RideOption?> findTransitHop({
  required HereTransitService? here,
  required LocationPoint from,
  required LocationPoint to,
  required DateTime departAt,
  required double plainWalkKm,
}) async {
  if (here == null) return null;
  try {
    final options = await here.search(
      from: from,
      to: to,
      departAt: departAt,
    );
    if (options.isEmpty) {
      debugPrint(
        '[TransitHopFinder] HERE found no real transit route for the '
        '${from.name} -> ${to.name} hop - keeping the walk.',
      );
      return null;
    }
    options.sort(
      (a, b) => a.totalElapsedFromSearch.compareTo(b.totalElapsedFromSearch),
    );

    RideOption? best;
    for (final candidate in options) {
      if (candidate.legs.isEmpty) continue;
      final startsInTime = !candidate.legs.first.start.isBefore(
        departAt.subtract(const Duration(minutes: 2)),
      );
      if (candidate.totalElapsedFromSearch.isNegative || !startsInTime) {
        continue;
      }
      best = candidate;
      break;
    }
    if (best == null) {
      debugPrint(
        '[TransitHopFinder] every HERE alternative for the ${from.name} -> '
        '${to.name} hop had a schedule that does not line up with the '
        'requested time - discarding rather than showing a broken '
        'timeline.',
      );
      return null;
    }

    final hasRealTransitLeg = best.legs.any(
      (leg) => leg.mode != TransportMode.walk,
    );
    if (!hasRealTransitLeg) {
      debugPrint(
        '[TransitHopFinder] HERE\'s best route for the ${from.name} -> '
        '${to.name} hop was pure walking - no real bus/train covers this '
        'stretch, so this is not offered as a separate transit '
        'alternative.',
      );
      return null;
    }

    final plainWalkMinutes = (plainWalkKm / 4.5) * 60;
    final transitMinutes = best.totalElapsedFromSearch.inMinutes;
    if (transitMinutes <= 0) {
      debugPrint(
        '[TransitHopFinder] HERE transit hop for ${from.name} -> '
        '${to.name} came back with an unusable duration '
        '(${transitMinutes}min) - keeping the walk.',
      );
      return null;
    }
    final fasterThanWalk = transitMinutes < plainWalkMinutes - 3;
    debugPrint(
      '[TransitHopFinder] HERE transit hop for ${from.name} -> '
      '${to.name} takes ${transitMinutes}min vs a '
      '${plainWalkMinutes.round()}min walk'
      '${fasterThanWalk ? ' (faster than walking)' : ' (slower than walking, offered as a bus alternative anyway)'}.',
    );
    return best;
  } catch (error) {
    debugPrint('[TransitHopFinder] hop failed: $error');
    return null;
  }
}

List<TripLeg> asLeadingSegment(List<TripLeg> legs) {
  if (legs.isEmpty) return legs;
  final last = legs.last;
  if (last.mode != TransportMode.walk || last.isTransfer) return legs;
  return [
    ...legs.sublist(0, legs.length - 1),
    TripLeg(
      mode: last.mode,
      title: last.title,
      subtitle: _asTransferSubtitle(last.subtitle),
      start: last.start,
      end: last.end,
      isTransfer: true,
      distanceKm: last.distanceKm,
      startPoint: last.startPoint,
      endPoint: last.endPoint,
    ),
  ];
}

List<TripLeg> asTrailingSegment(List<TripLeg> legs) {
  if (legs.isEmpty) return legs;
  final first = legs.first;
  if (first.mode != TransportMode.walk || first.isTransfer) return legs;
  return [
    TripLeg(
      mode: first.mode,
      title: first.title,
      subtitle: _asTransferSubtitle(first.subtitle),
      start: first.start,
      end: first.end,
      isTransfer: true,
      distanceKm: first.distanceKm,
      startPoint: first.startPoint,
      endPoint: first.endPoint,
    ),
    ...legs.sublist(1),
  ];
}

List<TripLeg> mergeAdjacentWalkLegs(List<TripLeg> legs) {
  if (legs.length < 2) return legs;
  final merged = <TripLeg>[];
  for (final leg in legs) {
    final last = merged.isEmpty ? null : merged.last;
    if (last != null &&
        last.mode == TransportMode.walk &&
        leg.mode == TransportMode.walk) {
      final bothUnknownDistance = last.distanceKm == null && leg.distanceKm == null;
      merged[merged.length - 1] = TripLeg(
        mode: TransportMode.walk,
        title: 'Walk',
        subtitle: (last.isTransfer || leg.isTransfer) ? '⇄  Transfer' : '⇄  Walk',
        start: last.start,
        end: leg.end,
        isTransfer: last.isTransfer || leg.isTransfer,
        distanceKm: bothUnknownDistance
            ? null
            : (last.distanceKm ?? 0) + (leg.distanceKm ?? 0),
        startPoint: last.startPoint,
        endPoint: leg.endPoint,
      );
    } else {
      merged.add(leg);
    }
  }
  return merged;
}

String _asTransferSubtitle(String subtitle) {
  return subtitle.startsWith('⇄') ? '⇄  Transfer' : subtitle;
}

String? realLegLabel(TripLeg leg) {
  if (leg.isTransfer || leg.mode == TransportMode.walk) return null;
  final label = leg.title.trim();
  if (label.isEmpty || label == leg.mode.label) return null;
  return label;
}

List<String> hopRouteLabels(RideOption hop) {
  final labels = <String>[];
  for (final leg in hop.legs) {
    final label = realLegLabel(leg);
    if (label != null && !labels.contains(label)) labels.add(label);
  }
  return labels;
}

RideOption withTimeShifted(RideOption option, Duration delta) {
  if (delta == Duration.zero) return option;
  final shiftedLegs = option.legs
      .map(
        (leg) => TripLeg(
          mode: leg.mode,
          title: leg.title,
          subtitle: leg.subtitle,
          start: leg.start.add(delta),
          end: leg.end.add(delta),
          isTransfer: leg.isTransfer,
          distanceKm: leg.distanceKm,
          startPoint: leg.startPoint,
          endPoint: leg.endPoint,
        ),
      )
      .toList();
  final id = '${option.id}-shifted-${option.departTime.add(delta).millisecondsSinceEpoch}'
      .hashCode
      .toString();
  return RideOption(
    id: id,
    title: option.title,
    legs: shiftedLegs,
    estCostRm: option.estCostRm,
    co2Kg: option.co2Kg,
    tags: option.tags,
    isLiveData: option.isLiveData,
    searchDepartAt: option.searchDepartAt.add(delta),
    path: option.path,
  );
}

RideOption withLegReplaced(
  RideOption option, {
  required int legIndex,
  required RideOption replacement,
  required LocationPoint from,
}) {
  final legs = option.legs;
  final originalLeg = legs[legIndex];
  final isFirstOverall = legIndex == 0;
  final isLastOverall = legIndex == legs.length - 1;

  var replacementLegs = replacement.legs;
  if (!isLastOverall) replacementLegs = asLeadingSegment(replacementLegs);
  if (!isFirstOverall) replacementLegs = asTrailingSegment(replacementLegs);

  final delta = replacementLegs.isEmpty
      ? Duration.zero
      : replacementLegs.last.end.difference(originalLeg.end);
  final shiftedRest = delta == Duration.zero
      ? legs.sublist(legIndex + 1)
      : legs
            .sublist(legIndex + 1)
            .map(
              (leg) => TripLeg(
                mode: leg.mode,
                title: leg.title,
                subtitle: leg.subtitle,
                start: leg.start.add(delta),
                end: leg.end.add(delta),
                isTransfer: leg.isTransfer,
                distanceKm: leg.distanceKm,
                startPoint: leg.startPoint,
                endPoint: leg.endPoint,
              ),
            )
            .toList();

  final newLegs = mergeAdjacentWalkLegs([
    ...legs.sublist(0, legIndex),
    ...replacementLegs,
    ...shiftedRest,
  ]);

  final newCost = sumRealLegFares(newLegs, from);
  final removedCo2 =
      (kCo2PerKmByMode[originalLeg.mode] ?? 0.0) *
      (originalLeg.distanceKm ?? 0.0);
  // Not num.clamp() - it returns `num` even on a double receiver, which
  // wouldn't satisfy RideOption.co2Kg's `double` type below.
  final rawCo2 = option.co2Kg - removedCo2 + replacement.co2Kg;
  final newCo2 = rawCo2 < 0 ? 0.0 : rawCo2;

  final id = '${option.id}-edited-$legIndex-${replacement.id}'
      .hashCode
      .toString();

  return RideOption(
    id: id,
    title: titleForLegs(newLegs),
    legs: newLegs,
    estCostRm: newCost,
    co2Kg: newCo2,
    isLiveData: true,
    searchDepartAt: option.searchDepartAt,
    tags: option.tags.contains('Edited')
        ? option.tags
        : [...option.tags, 'Edited'],
    path: option.path,
  );
}

RideOption withLegsReplaced(
  RideOption option, {
  required Map<int, RideOption> replacements,
  required LocationPoint from,
  Duration initialDelta = Duration.zero,
}) {
  if (replacements.isEmpty) {
    return initialDelta == Duration.zero
        ? option
        : withTimeShifted(option, initialDelta);
  }

  final legs = option.legs;
  final newLegs = <TripLeg>[];
  var carryDelta = initialDelta;

  for (var i = 0; i < legs.length; i++) {
    final originalLeg = legs[i];
    final replacement = replacements[i];

    if (replacement == null) {
      newLegs.add(
        carryDelta == Duration.zero
            ? originalLeg
            : TripLeg(
                mode: originalLeg.mode,
                title: originalLeg.title,
                subtitle: originalLeg.subtitle,
                start: originalLeg.start.add(carryDelta),
                end: originalLeg.end.add(carryDelta),
                isTransfer: originalLeg.isTransfer,
                distanceKm: originalLeg.distanceKm,
                startPoint: originalLeg.startPoint,
                endPoint: originalLeg.endPoint,
              ),
      );
      continue;
    }

    final isFirstOverall = i == 0;
    final isLastOverall = i == legs.length - 1;

    var replacementLegs = replacement.legs;
    if (!isLastOverall) replacementLegs = asLeadingSegment(replacementLegs);
    if (!isFirstOverall) replacementLegs = asTrailingSegment(replacementLegs);

    newLegs.addAll(replacementLegs);

    final originalEndAfterCarry = originalLeg.end.add(carryDelta);
    final newEnd = replacementLegs.isEmpty
        ? originalEndAfterCarry
        : replacementLegs.last.end;
    carryDelta = carryDelta + newEnd.difference(originalEndAfterCarry);
  }

  final mergedLegs = mergeAdjacentWalkLegs(newLegs);
  final newCost = sumRealLegFares(mergedLegs, from);
  final newCo2 = sumLegsCo2Kg(mergedLegs);

  final replacedIds = replacements.entries
      .map((entry) => '${entry.key}:${entry.value.id}')
      .join(',');
  final id = '${option.id}-redated-$replacedIds'.hashCode.toString();

  return RideOption(
    id: id,
    title: titleForLegs(mergedLegs),
    legs: mergedLegs,
    estCostRm: newCost,
    co2Kg: newCo2,
    isLiveData: true,
    searchDepartAt: option.searchDepartAt.add(carryDelta),
    tags: option.tags,
    path: option.path,
  );
}
