class HereMatrixResult {
  final int numOrigins;
  final int numDestinations;
  final List<int?> travelTimesSeconds;
  final List<int?> distancesMeters;
  final List<int?> errorCodes;

  const HereMatrixResult({
    required this.numOrigins,
    required this.numDestinations,
    required this.travelTimesSeconds,
    required this.distancesMeters,
    required this.errorCodes,
  });

  int _index(int originIndex, int destinationIndex) {
    if (originIndex < 0 ||
        originIndex >= numOrigins ||
        destinationIndex < 0 ||
        destinationIndex >= numDestinations) {
      throw RangeError(
        'Matrix index out of range: '
        '$originIndex -> $destinationIndex',
      );
    }

    return numDestinations * originIndex + destinationIndex;
  }

  bool isReachable(
    int originIndex,
    int destinationIndex,
  ) {
    final index = _index(
      originIndex,
      destinationIndex,
    );

    final error =
        index < errorCodes.length
            ? errorCodes[index]
            : null;

    if (error != null && error != 0) {
      return false;
    }

    final travelTime =
        index < travelTimesSeconds.length
            ? travelTimesSeconds[index]
            : null;

    return travelTime != null &&
        travelTime >= 0;
  }

  int? durationSeconds(
    int originIndex,
    int destinationIndex,
  ) {
    final index = _index(
      originIndex,
      destinationIndex,
    );

    if (!isReachable(
      originIndex,
      destinationIndex,
    )) {
      return null;
    }

    return index < travelTimesSeconds.length
        ? travelTimesSeconds[index]
        : null;
  }

  int? durationMinutes(
    int originIndex,
    int destinationIndex,
  ) {
    final seconds = durationSeconds(
      originIndex,
      destinationIndex,
    );

    if (seconds == null) {
      return null;
    }

    return (seconds / 60).ceil();
  }

  double? distanceKm(
    int originIndex,
    int destinationIndex,
  ) {
    final index = _index(
      originIndex,
      destinationIndex,
    );

    if (!isReachable(
      originIndex,
      destinationIndex,
    )) {
      return null;
    }

    final meters =
        index < distancesMeters.length
            ? distancesMeters[index]
            : null;

    if (meters == null) {
      return null;
    }

    return meters / 1000.0;
  }
}
