import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/transport_data.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';

class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.option,
    required this.onTap,
    this.featured = false,
  });

  final RideOption option;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final leadMode = option.legs.isNotEmpty
        ? option.legs.first.mode
        : TransportMode.other;

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
              _ArrivalInformation(option: option),
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

  @override
  Widget build(BuildContext context) {
    final shownTags = option.tags.take(3).toList();
    final transferChip = transferCountLabel(option.transferCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.routeSummary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: [
            MiniChip(transferChip),
            for (final tag in shownTags)
              MiniChip(tag, warning: tag == kRainBikeTag),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Image.asset(AppAssets.leaf, width: 12, height: 12),
            const SizedBox(width: 3),
            Text(
              option.co2Level,
              style: const TextStyle(fontSize: 8, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Text(
              'CO₂ ${option.co2Kg.toStringAsFixed(2)}kg',
              style: const TextStyle(fontSize: 8, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArrivalInformation extends StatelessWidget {
  const _ArrivalInformation({required this.option});

  final RideOption option;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shown first because it's the number that actually varies between
        // options now - a bus/train doesn't run at any hour you happen to
        // search, so different options can genuinely depart at different
        // real times (sometimes even the next day) rather than all
        // starting the instant you searched.
        const Text(
          'Departs',
          style: TextStyle(fontSize: 6.5, color: AppColors.muted),
        ),
        const SizedBox(height: 3),
        Text(
          formatClockTime(option.departTime),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Est. Arrival',
          style: TextStyle(fontSize: 6.5, color: AppColors.muted),
        ),
        const SizedBox(height: 3),
        Text(
          formatClockTime(option.arriveTime),
          style: const TextStyle(fontSize: 10, color: AppColors.green),
        ),
        const SizedBox(height: 4),
        // totalElapsedFromSearch, NOT totalDuration: the latter only
        // measures this option's own timeline once it starts, which for a
        // real scheduled service that won't run again for a while makes it
        // look deceptively as fast as something you could start on right
        // now. This is the fair, comparable-across-options number - see
        // RideOption.searchDepartAt's doc comment.
        Text(
          formatDuration(option.totalElapsedFromSearch),
          style: const TextStyle(fontSize: 7.5),
        ),
        // Only shown when it's actually worth calling out - a couple of
        // minutes' rounding is normal and not worth a warning line, but a
        // real multi-hour gap before a scheduled service even starts
        // running needs to be visible, not hidden inside a duration number
        // that reads as "fast" at a glance.
        if (option.waitBeforeDeparture > const Duration(minutes: 15))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Waits ${formatDuration(option.waitBeforeDeparture)}',
              style: const TextStyle(fontSize: 6.5, color: AppColors.orange),
            ),
          ),
      ],
    );
  }
}

class MiniChip extends StatelessWidget {
  const MiniChip(this.label, {super.key, this.warning = false});

  final String label;

  /// True for a chip that should stand out as a caution rather than
  /// blend in as a neutral fact (right now, only [kRainBikeTag]) -
  /// styled orange instead of the usual neutral grey so a rainy-day
  /// "don't ideally bike this" warning doesn't read as just another
  /// badge like "Low Carbon" or "Real Bike Station".
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
