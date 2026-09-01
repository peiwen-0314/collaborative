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
