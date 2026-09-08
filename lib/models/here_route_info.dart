class HereRouteInfo {
  final double distanceKm;
  final int durationMinutes;
  final int durationSeconds;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const HereRouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.durationSeconds,
    this.departureTime,
    this.arrivalTime,
  });

  factory HereRouteInfo.fallback({
    required double distanceKm,
    required int durationMinutes,
    DateTime? departureTime,
  }) {
    return HereRouteInfo(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      durationSeconds: durationMinutes * 60,
      departureTime: departureTime,
      arrivalTime: departureTime?.add(
        Duration(minutes: durationMinutes),
      ),
    );
  }
}
