/// Small, dependency-free formatting helpers shared by the transportation
/// screens (kept local instead of pulling in `intl` to avoid an extra
/// dependency for a student project).

String formatClockTime(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'pm' : 'am';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute$period';
}

/// e.g. "Today, 9:04am", "Tomorrow, 5:30pm", "24 Aug, 8:00am".
String formatFriendlyDateTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = target.difference(today).inDays;

  final String dayLabel;
  if (dayDiff == 0) {
    dayLabel = 'Today';
  } else if (dayDiff == 1) {
    dayLabel = 'Tomorrow';
  } else {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    dayLabel = '${dt.day} ${months[dt.month - 1]}';
  }
  return '$dayLabel, ${formatClockTime(dt)}';
}

/// e.g. Duration(minutes: 45) -> "45 min", Duration(hours: 4, minutes: 38)
/// -> "4h 38m".
String formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String formatRm(double amount) => 'RM ${amount.toStringAsFixed(2)}';

/// e.g. 0 -> "Direct", 1 -> "1 Transfer", 2 -> "2 Transfers". Shared by
/// the results list (RideCard) and the trip details header (TripSummary)
/// so both describe [RideOption.transferCount] the same way.
String transferCountLabel(int transferCount) {
  if (transferCount <= 0) return 'Direct';
  if (transferCount == 1) return '1 Transfer';
  return '$transferCount Transfers';
}

/// A short, human-scannable version of a full geocoded address (e.g.
/// "Guillemard Water Treatment Plant, Mukim 17 Batu Feringgi, Penang,
/// Malaysia" -> "Guillemard Water Treatment Plant") - just the first
/// comma-separated segment, which is the actual place/street name;
/// everything after it is the same kind of area/state/country
/// boilerplate that repeats across almost every entry, and isn't what
/// actually tells two saved trips apart at a glance. Used only for tight,
/// one-line list rows (the Saved List preview and page) - the full
/// [LocationPoint.name] is still what's geocoded with and shown in the
/// From/To fields themselves, where the extra detail is genuinely useful.
///
/// A street address that starts with a bare house/lot number (e.g. "36,
/// Jalan Tanjung Bungah, ...") would otherwise shorten to just "36" -
/// technically the first comma-separated segment, but meaningless on its
/// own. Skips a first segment that's only digits (with optional letter
/// suffix, e.g. a lot number like "36A") and uses the next one instead,
/// so a numbered address still shortens to its actual street/area name.
final _bareNumberSegment = RegExp(r'^\d+[A-Za-z]?$');

String shortPlaceName(String fullName) {
  final segments = fullName.split(',').map((s) => s.trim());
  for (final segment in segments) {
    if (segment.isEmpty) continue;
    if (_bareNumberSegment.hasMatch(segment)) continue;
    return segment;
  }
  return fullName;
}
