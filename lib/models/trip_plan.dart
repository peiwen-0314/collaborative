class TripPlanPreferences {
  String? selectedState;
  DateTime? startDate;
  DateTime? endDate;

  int adults;
  int children;
  int seniors;

  // Kept for compatibility with your existing saved-plan structure.
  // The current traveler UI no longer asks for these values.
  bool wheelchairAccessible;
  bool strollerFriendly;
  bool serviceAnimalFriendly;

  double budget;

  /// User can select multiple travel styles.
  /// Recommended limit in the UI/controller: 1 to 3 styles.
  final List<String> travelStyles;

  TripPlanPreferences({
    this.selectedState,
    this.startDate,
    this.endDate,
    this.adults = 2,
    this.children = 0,
    this.seniors = 0,
    this.wheelchairAccessible = false,
    this.strollerFriendly = false,
    this.serviceAnimalFriendly = false,
    this.budget = 800,
    List<String>? travelStyles,
  }) : travelStyles = travelStyles ?? <String>[];

  // ============================================================
  // TRAVELERS
  // ============================================================

  int get totalTravelers =>
      adults + children + seniors;

  String get travelerSummary {
    final parts = <String>[];

    if (adults > 0) {
      parts.add(
        '$adults Adult${adults == 1 ? '' : 's'}',
      );
    }

    if (children > 0) {
      parts.add(
        '$children ${children == 1 ? 'Child' : 'Children'}',
      );
    }

    if (seniors > 0) {
      parts.add(
        '$seniors Senior${seniors == 1 ? '' : 's'}',
      );
    }

    return parts.isEmpty
        ? 'No travelers'
        : parts.join(', ');
  }

  // ============================================================
  // DATES
  // ============================================================

  int get totalDays {
    if (startDate == null ||
        endDate == null) {
      return 0;
    }

    return endDate!
        .difference(startDate!)
        .inDays +
        1;
  }

  String get dateSummary {
    if (startDate == null ||
        endDate == null) {
      return 'Select your travel dates';
    }

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(startDate!.day)}/'
        '${two(startDate!.month)}/'
        '${startDate!.year}'
        ' - '
        '${two(endDate!.day)}/'
        '${two(endDate!.month)}/'
        '${endDate!.year}';
  }

  // ============================================================
  // TRAVEL STYLES
  // ============================================================

  bool get hasTravelStyles =>
      travelStyles.isNotEmpty;

  int get selectedTravelStyleCount =>
      travelStyles.length;

  bool hasTravelStyle(String style) {
    return travelStyles.contains(style);
  }

  String get travelStyleSummary {
    if (travelStyles.isEmpty) {
      return 'Choose your travel styles';
    }

    return travelStyles.join(', ');
  }
}
