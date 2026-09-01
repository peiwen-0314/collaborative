class TripPlanPreferences {
  String? selectedState;
  DateTime? startDate;
  DateTime? endDate;
  int adults;
  int children;
  int seniors;
  bool wheelchairAccessible;
  bool strollerFriendly;
  bool serviceAnimalFriendly;
  double budget;
  String? travelStyle;

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
    this.travelStyle,
  });

  int get totalTravelers => adults + children + seniors;

  int get totalDays {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  String get travelerSummary {
    final parts = <String>[];
    if (adults > 0) parts.add('$adults Adult${adults == 1 ? '' : 's'}');
    if (children > 0) parts.add('$children Child${children == 1 ? '' : 'ren'}');
    if (seniors > 0) parts.add('$seniors Senior${seniors == 1 ? '' : 's'}');
    return parts.isEmpty ? 'No travelers' : parts.join(', ');
  }

  String get dateSummary {
    if (startDate == null || endDate == null) return 'Select your travel dates';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(startDate!.day)}/${two(startDate!.month)}/${startDate!.year} - ${two(endDate!.day)}/${two(endDate!.month)}/${endDate!.year}';
  }
}
