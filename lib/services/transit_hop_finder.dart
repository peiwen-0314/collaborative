import 'package:flutter/foundation.dart' show debugPrint;

import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';
import 'here_transit_service.dart';

/// Asks HERE's real Public Transit API for a short point-to-point hop - an
/// access/egress leg, e.g. from a rider's real origin to a bike-share
/// station, or to the first usable bus stop for a route that otherwise
/// starts with a long walk - and returns whatever real route HERE has for
/// it, or null if there genuinely isn't one usable. Shared by
/// OsmBikeShareService (first/last mile to a bike station) and
/// TransportService (offering a "take a bus to the stop" alternative when
/// a live transit option starts or ends with a long walk), so both use
/// exactly the same real-data logic and caveats instead of two subtly
/// different copies.
///
/// A hop that's slower than the plain walk it's being compared against is
/// NOT discarded here - it's still a real, valid choice for someone who'd
/// rather ride than walk; callers decide what to do with a slower hop
/// (typically: offer it as a second, separate option rather than silently
/// picking one for the rider - see OsmBikeShareService._buildOptions and
/// TransportService._withAccessAlternatives). Only a genuinely unusable
/// result (no route at all, or a broken/negative duration - see the
/// comment below) returns null.
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

    // Pick the soonest-arriving alternative whose schedule actually lines
    // up with the requested [departAt] - a route whose reported arrival
    // is before departAt (a negative totalElapsedFromSearch), or whose
    // very first leg starts noticeably earlier than departAt, doesn't
    // really correspond to when the rider would be there. Splicing a
    // hop like that into a combined itinerary elsewhere previously
    // produced a timeline that jumped backwards in time (seen in
    // practice, for a real HERE response) - so rather than trying to
    // salvage it, this skips straight to the next alternative.
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

    // HERE's transit search can legitimately answer "just walk" - when
    // there genuinely is no bus/train that covers this specific short
    // hop, its best (sometimes only) alternative is a pure walking
    // route. That's not a real transit alternative at all: spliced in
    // by a caller, it used to show up as a *second*, near-identical
    // option - same walk, same distance, just restyled from a plain
    // green "Walk" box into a white "Transfer" box (and, confusingly, a
    // different cost) - which read as two options that differ only by
    // box color. So a hop with no real (non-walk) leg in it is treated
    // exactly like "HERE found nothing", not like a usable alternative.
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

/// A hop's own boundary walk legs are computed by HERE relative to ITS
/// OWN isolated sub-search (see HereTransitService._parseRoute), so its
/// first and last walk legs are marked as a genuine start/end walk (not
/// a mid-trip "Transfer"), matching the convention for a route that
/// stands on its own. When a hop is spliced into the MIDDLE of a larger
/// itinerary instead - not at the very start or very end of the whole
/// trip - that boundary walk becomes a genuine transfer and needs
/// restyling to match (see TimelineItem/_TimelineCard, which colors a
/// leg white only when [TripLeg.isTransfer] is true). These two helpers
/// do exactly that to one boundary leg, leaving every other leg (and
/// any non-walk boundary leg) untouched.
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

/// Collapses any run of two or more back-to-back walk legs into one
/// walk leg spanning the whole run. Splicing a real hop's own boundary
/// walk (see asLeadingSegment/asTrailingSegment) can otherwise land it
/// directly next to a walk leg that was already there - e.g. editing
/// one leg of a trip whose neighbour is itself a spliced-in boundary
/// walk from an earlier automatic hop - which shows up as two separate
/// "Walk" boxes back to back for what is really just one continuous
/// walk. Called after every splice that can create this situation
/// (OsmBikeShareService._composeOption, TransportService.
/// _withAccessAlternatives, withLegReplaced below) rather than only
/// where it was first noticed, since any of them can produce it.
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

/// A boundary walk leg being restyled to isTransfer:true (see
/// asLeadingSegment/asTrailingSegment above) still carries whatever
/// access/egress-style subtitle it was given as a standalone leg (e.g.
/// "⇄  Walk") - left alone, the text would say "Walk" while the box
/// renders white/"Transfer", which is exactly the text-vs-styling
/// mismatch these two functions exist to fix in the first place. Only
/// swaps a recognized "⇄  ..." walk subtitle; anything else (a
/// mid-route walk that was already "⇄  Transfer", or an unexpected
/// string) is left as-is rather than guessed at.
String _asTransferSubtitle(String subtitle) {
  return subtitle.startsWith('⇄') ? '⇄  Transfer' : subtitle;
}

/// The real route/service numbers a hop actually rides (e.g. ["104"]),
/// skipping walk/transfer legs and any leg HERE couldn't give a more
/// specific name than its generic mode label - same extraction
/// [RideOption.routeSummary] uses, exposed here so callers that splice a
/// hop into a combined itinerary (OsmBikeShareService._composeOption,
/// TransportService._withAccessAlternatives) can group these into one
/// "Bus (104 + 11)"-style title segment instead of a separate "Bus"
/// word per hop, which used to read as "Bus + Shared Bike + Bus".
List<String> hopRouteLabels(RideOption hop) {
  final labels = <String>[];
  for (final leg in hop.legs) {
    if (leg.isTransfer || leg.mode == TransportMode.walk) continue;
    final label = leg.title.trim();
    if (label.isEmpty || label == leg.mode.label) continue;
    if (!labels.contains(label)) labels.add(label);
  }
  return labels;
}


/// Rebuilds [option] with the single leg at [legIndex] swapped for
/// [replacement]'s own real legs - the manual counterpart to
/// findTransitHop/_withAccessAlternatives above: instead of the app
/// silently picking the best real alternative for a long access/egress
/// walk, this lets a person pick ANY leg (not just a boundary walk) and
/// choose from every real alternative HERE has for that exact stretch
/// (see TransportService.findLegAlternatives) - e.g. swapping a "walk 29
/// min to catch the 101" leg for a real "104" bus instead, because
/// that's what they'd rather do, not because one is objectively faster.
///
/// Everything before [legIndex] keeps its own real absolute times
/// untouched. Everything after it shifts by however much the
/// replacement's own end time differs from the original leg's end time -
/// a slower replacement pushes the rest of the trip later, a faster one
/// pulls it earlier, exactly like swapping one leg of a real journey
/// planner's itinerary would.
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

  // Same boundary-restyling as splicing an automatic hop in
  // (asLeadingSegment/asTrailingSegment above) - a replacement's own
  // walk boundary only reads as a genuine start/end-of-trip "Walk" when
  // it's actually replacing the very first or very last leg of the
  // whole itinerary; anywhere in the middle, both of its boundaries are
  // real mid-trip transfers.
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

  // Recomputed from scratch as the real sum of every leg's own fare
  // (see sumRealLegFares/legFareRm) rather than "old total - an
  // estimated removed share + the replacement's own total" - that
  // subtraction trick used a flat per-km rate to guess what the
  // ORIGINAL leg alone had contributed (kCostPerKmByMode, documented as
  // an approximation for bus/train/ferry specifically - see that
  // constant's own doc comment), which could drift away from what each
  // row of the itinerary actually shows once TripDetailsPage started
  // displaying every leg's own real fare (same [legFareRm]) - a trip's
  // header total must always agree with its own rows, never just be in
  // the right ballpark. CO2 keeps the old subtraction approach - there's
  // no per-leg CO2 display for it to visibly disagree with.
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
    // routeSummary re-derives real route numbers straight from [legs]
    // every time it's read (see RideOption.routeSummary), so it already
    // picks up the replacement's real numbers without title itself
    // needing to be rebuilt here.
    title: option.title,
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
