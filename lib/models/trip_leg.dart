import 'transport_mode.dart';

/// One segment of a journey timeline, e.g. "KTM Komuter (Rawang -> KL
/// Sentral)" or a transfer/wait between two vehicles.
class TripLeg {
  const TripLeg({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    this.isTransfer = false,
  });

  final TransportMode mode;
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final bool isTransfer;

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'title': title,
    'subtitle': subtitle,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'isTransfer': isTransfer,
  };

  factory TripLeg.fromJson(Map<String, dynamic> json) => TripLeg(
    mode: TransportMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => TransportMode.other,
    ),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    isTransfer: json['isTransfer'] as bool? ?? false,
  );
}
