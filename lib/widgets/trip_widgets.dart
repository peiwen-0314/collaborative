import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../data/transport_data.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/transport_mode.dart';

class TripSummary extends StatelessWidget {
  const TripSummary({super.key, required this.option, required this.from});

  final RideOption option;

  /// Only used to pick the Penang-vs-Klang-Valley fare tables for
  /// [displayCostRm] - see that function's doc comment.
  final LocationPoint from;

  @override
  Widget build(BuildContext context) {
    final transfers = option.transferCount;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SummaryCell(
              icon: Icons.schedule,
              // totalElapsedFromSearch, not totalDuration - "Total
              // Duration" should mean the real time from searching to
              // arriving, including any wait for a real scheduled service
              // to actually start running (see
              // RideOption.searchDepartAt's doc comment), not just this
              // option's own ride-only window.
              label: 'Total Duration',
              value: formatDuration(option.totalElapsedFromSearch),
            ),
          ),
          Expanded(
            child: SummaryCell(
              icon: Icons.swap_horiz,
              label: transferCountLabel(transfers),
              value: '',
            ),
          ),
          Expanded(
            child: SummaryCell(
              icon: Icons.monetization_on_outlined,
              label: 'Est. Cost',
              value: formatRm(displayCostRm(option, from)),
            ),
          ),
          Expanded(
            child: SummaryCell(
              icon: Icons.eco_outlined,
              label: 'CO₂',
              value: '${option.co2Kg.toStringAsFixed(2)} kg ${option.co2Level}',
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCell extends StatelessWidget {
  const SummaryCell({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 7, color: AppColors.muted),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.duration,
    this.fareLabel,
    this.mode,
    this.transfer = false,
    this.onTap,
  });

  final String start;
  final String end;
  final String title;
  final String subtitle;
  final String duration;

  /// This leg's own real fare (e.g. "RM 1.50"), when known - see
  /// TripDetailsPage's _timelineItems/fareLabel. Null for a walk or
  /// transfer leg (free/not its own fare), or when the underlying leg
  /// has no real distance to price (the offline/mock generator).
  final String? fareLabel;

  /// Transport mode for this leg's icon bubble. Left `null` for transfer
  /// legs, which show no icon (matching the original design).
  final TransportMode? mode;
  final bool transfer;

  /// Set only for a real, editable leg while TripDetailsPage is in Edit
  /// mode (see its onLegTap) - shows a small pencil hint and makes the
  /// whole row tappable to open the "choose a real alternative for this
  /// segment" sheet. Left null for every other row (view mode, or a row
  /// that isn't a real editable leg, like the synthetic "Change here"
  /// marker), which renders exactly as before with no tap affordance.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: transfer ? 55 : 62,
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    start,
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    end,
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          _TimelineRail(transfer: transfer),
          const SizedBox(width: 7),
          Expanded(
            child: _TimelineCard(
              mode: mode,
              title: title,
              subtitle: subtitle,
              duration: duration,
              fareLabel: fareLabel,
              transfer: transfer,
              editable: onTap != null,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: row,
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.transfer});

  final bool transfer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: Column(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: transfer ? AppColors.muted : AppColors.green,
                width: 2,
              ),
            ),
          ),
          Expanded(child: Container(width: 1, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.transfer,
    this.fareLabel,
    this.editable = false,
  });

  final TransportMode? mode;
  final String title;
  final String subtitle;
  final String duration;
  final String? fareLabel;
  final bool transfer;

  /// True while this row is tappable in TripDetailsPage's Edit mode -
  /// shows a small pencil hint next to the duration chip so it's
  /// visually obvious which rows can be swapped for a real alternative,
  /// as opposed to every other row that just looks the same as always.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: transfer ? Colors.white : AppColors.paleGreen,
        border: transfer ? Border.all(color: AppColors.border) : null,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          if (mode != null) ...[
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: transportModeGlyph(mode!, size: 20),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  duration,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ),
              if (fareLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  fareLabel!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (editable) ...[
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14, color: AppColors.green),
          ],
        ],
      ),
    );
  }
}

class DestinationRow extends StatelessWidget {
  const DestinationRow({
    super.key,
    required this.arrivalTimeLabel,
    required this.destinationLabel,
  });

  final String arrivalTimeLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 43,
          child: Text(
            arrivalTimeLabel,
            style: const TextStyle(fontSize: 9, color: AppColors.muted),
          ),
        ),
        const Icon(
          Icons.location_on_outlined,
          color: AppColors.orange,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            destinationLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
