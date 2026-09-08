import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/transport_data.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';
import '../models/trip_leg.dart';

TransportMode _majorityMode(List<TripLeg> legs) {
  if (legs.isEmpty) return TransportMode.other;
  final totalsByMode = <TransportMode, Duration>{};
  for (final leg in legs) {
    totalsByMode[leg.mode] = (totalsByMode[leg.mode] ?? Duration.zero) + leg.duration;
  }
  var majority = legs.first.mode;
  var majorityDuration = Duration.zero;
  for (final entry in totalsByMode.entries) {
    if (entry.value > majorityDuration) {
      majority = entry.key;
      majorityDuration = entry.value;
    }
  }
  return majority;
}

class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.option,
    required this.onTap,
    this.featured = false,
    this.showElapsedFromSearch = true,
    this.showWaitWarning = true,
  });

  final RideOption option;
  final VoidCallback onTap;
  final bool featured;

  final bool showElapsedFromSearch;

  final bool showWaitWarning;

  @override
  Widget build(BuildContext context) {
    final leadMode = _majorityMode(option.legs);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: featured ? 64 : 55,
                height: featured ? 52 : 55,
                padding: EdgeInsets.all(featured ? 8 : 12),
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: transportModeGlyph(
                  leadMode,
                  size: featured ? 34 : 28,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _RideInformation(option: option)),
              _ArrivalInformation(
                option: option,
                showElapsedFromSearch: showElapsedFromSearch,
                showWaitWarning: showWaitWarning,
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.green,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideInformation extends StatelessWidget {
  const _RideInformation({required this.option});

  final RideOption option;

  static const _hiddenTags = {'AI Recommended', 'Live Route'};

  /// True for a tag that's actually worth a caution - see MiniChip's
  /// own `warning` usage a few lines below for the exact same list.
  static bool _isWarningTag(String tag) =>
      tag == kRainBikeTag ||
      tag == kWalkOnlyLongTag ||
      tag == kHazeOutdoorTag ||
      tag == kExtremeHeatTag ||
      tag == kOverBudgetTag ||
      tag == kOverDurationTag;

  static List<String> _pickShownTags(List<String> tags) {
    final visible = tags.where((tag) => !_hiddenTags.contains(tag)).toList();
    final sorted = [
      ...visible.where(_isWarningTag),
      ...visible.where((tag) => !_isWarningTag(tag)),
    ];
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shownTags = _pickShownTags(option.tags);
    final transferChip = transferCountLabel(option.transferCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(option.routeSummary),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: Text(
            option.routeSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: [
            MiniChip(transferChip),
            if (option.delayEstimate != null)
              MiniChip(option.delayEstimate!.chipLabel, warning: true),
            for (final tag in shownTags)
              MiniChip(
                tag,
                warning:
                    tag == kRainBikeTag ||
                    tag == kWalkOnlyLongTag ||
                    tag == kHazeOutdoorTag ||
                    tag == kExtremeHeatTag ||
                    tag == kOverBudgetTag ||
                    tag == kOverDurationTag,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Image.asset(AppAssets.leaf, width: 12, height: 12),
            const SizedBox(width: 3),
            Text(
              '${option.co2Level} CO₂ · ${option.co2Kg.toStringAsFixed(2)}kg',
              style: const TextStyle(fontSize: 8, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArrivalInformation extends StatelessWidget {
  const _ArrivalInformation({
    required this.option,
    this.showElapsedFromSearch = true,
    this.showWaitWarning = true,
  });

  final RideOption option;
  final bool showElapsedFromSearch;

  /// See RideCard.showWaitWarning's doc comment.
  final bool showWaitWarning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 7, color: AppColors.green),
            const SizedBox(width: 4),
            Text(
              formatClockTime(option.departTime),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Same idea for "Est. Arrival" - the orange pin LocationRow
        // marks its own "To" row with.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              size: 9,
              color: AppColors.orange,
            ),
            const SizedBox(width: 3),
            Text(
              formatClockTime(option.arriveTime),
              style: const TextStyle(fontSize: 10, color: AppColors.green),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (showElapsedFromSearch) ...[
          Text(
            formatDuration(option.totalElapsedFromSearch),
            style: const TextStyle(fontSize: 7.5),
          ),
          if (showWaitWarning &&
              option.waitBeforeDeparture > const Duration(minutes: 15))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Waits ${formatDuration(option.waitBeforeDeparture)}',
                style: const TextStyle(
                  fontSize: 6.5,
                  color: AppColors.orange,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class MiniChip extends StatelessWidget {
  const MiniChip(this.label, {super.key, this.warning = false});

  final String label;

  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF1E0) : AppColors.chip,
        border: Border.all(
          color: warning ? AppColors.orange : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          color: warning ? AppColors.orange : AppColors.muted,
          fontWeight: warning ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}
