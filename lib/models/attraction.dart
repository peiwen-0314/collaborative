import 'package:cloud_firestore/cloud_firestore.dart';

class AttractionModel {
  final String id;
  final String name;

  // Primary category (kept for old filters/recommendation code)
  final String categoryId;
  final String categoryName;

  // Full multi-category support
  final List<String> categoryIds;
  final List<String> categoryNames;

  final String state;
  final String area;
  final String description;

  final bool isFreeEntry;

  final double malaysianAdultFee;
  final double malaysianChildFee;
  final double malaysianSeniorFee;

  final double nonMalaysianAdultFee;
  final double nonMalaysianChildFee;
  final double nonMalaysianSeniorFee;

  // Old fields kept for backward compatibility
  final String openingTime;
  final String closingTime;

  // New weekly opening-hour structure
  final Map<String, List<String>> openingHours;
  final bool isOpen24Hours;

  final String recommendedDuration;

  final String address;
  final String phoneNumber;
  final String websiteUrl;
  final String googlePlaceId;

  final double latitude;
  final double longitude;

  final List<String> facilities;
  final List<String> highlights;

  final List<String> imageUrls;
  final String coverImageUrl;

  final String status;
  final DateTime createdAt;

  const AttractionModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    this.categoryIds = const <String>[],
    this.categoryNames = const <String>[],
    required this.state,
    required this.area,
    required this.description,
    required this.isFreeEntry,
    required this.malaysianAdultFee,
    required this.malaysianChildFee,
    required this.malaysianSeniorFee,
    required this.nonMalaysianAdultFee,
    required this.nonMalaysianChildFee,
    required this.nonMalaysianSeniorFee,
    this.openingTime = '',
    this.closingTime = '',
    this.openingHours = const <String, List<String>>{},
    this.isOpen24Hours = false,
    required this.recommendedDuration,
    required this.address,
    required this.phoneNumber,
    this.websiteUrl = '',
    this.googlePlaceId = '',
    this.latitude = 0,
    this.longitude = 0,
    required this.facilities,
    required this.highlights,
    required this.imageUrls,
    required this.coverImageUrl,
    required this.status,
    required this.createdAt,
  });

  factory AttractionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};

    double number(String key, {String? fallbackKey}) {
      dynamic value = data[key];

      if (value == null && fallbackKey != null) {
        value = data[fallbackKey];
      }

      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0;
      return 0;
    }

    List<String> stringList(String key) {
      final value = data[key];

      if (value is List) {
        return value
            .where((item) => item != null)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return <String>[];
    }

    Map<String, List<String>> weeklyHours(String key) {
      final raw = data[key];

      if (raw is! Map) {
        return <String, List<String>>{};
      }

      final result = <String, List<String>>{};

      for (final entry in raw.entries) {
        final day = entry.key.toString().trim();
        final value = entry.value;

        if (day.isEmpty) continue;

        if (value is List) {
          result[day] = value
              .where((item) => item != null)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        } else if (value != null) {
          final text = value.toString().trim();
          result[day] = text.isEmpty ? <String>[] : <String>[text];
        } else {
          result[day] = <String>[];
        }
      }

      return result;
    }

    final primaryCategoryId =
    (data['categoryId'] ?? '').toString().trim();
    final primaryCategoryName =
    (data['categoryName'] ?? '').toString().trim();

    final loadedCategoryIds = stringList('categoryIds');
    final loadedCategoryNames = stringList('categoryNames');

    if (loadedCategoryIds.isEmpty && primaryCategoryId.isNotEmpty) {
      loadedCategoryIds.add(primaryCategoryId);
    }

    if (loadedCategoryNames.isEmpty && primaryCategoryName.isNotEmpty) {
      loadedCategoryNames.add(primaryCategoryName);
    }

    final loadedImageUrls = stringList('imageUrls');

    String loadedCoverImageUrl =
    (data['coverImageUrl'] ?? '').toString().trim();

    if (loadedCoverImageUrl.isEmpty && loadedImageUrls.isNotEmpty) {
      loadedCoverImageUrl = loadedImageUrls.first;
    }

    DateTime loadedCreatedAt = DateTime.now();
    final createdAtValue = data['createdAt'];

    if (createdAtValue is Timestamp) {
      loadedCreatedAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      loadedCreatedAt = createdAtValue;
    } else if (createdAtValue is String) {
      loadedCreatedAt =
          DateTime.tryParse(createdAtValue) ?? DateTime.now();
    }

    final loadedOpeningHours = weeklyHours('openingHours');
    final oldOpeningTime =
    (data['openingTime'] ?? '').toString().trim();
    final oldClosingTime =
    (data['closingTime'] ?? '').toString().trim();

    bool loadedOpen24Hours = data['isOpen24Hours'] == true;

    // Backward compatibility for old records.
    if (!loadedOpen24Hours &&
        loadedOpeningHours.isEmpty &&
        oldOpeningTime.isEmpty &&
        oldClosingTime.isEmpty) {
      loadedOpen24Hours = true;
    }

    return AttractionModel(
      id: document.id,
      name: (data['name'] ?? '').toString().trim(),
      categoryId: primaryCategoryId,
      categoryName: primaryCategoryName,
      categoryIds: loadedCategoryIds,
      categoryNames: loadedCategoryNames,
      state: (data['state'] ?? '').toString().trim(),
      area: (data['area'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      isFreeEntry: data['isFreeEntry'] == true,
      malaysianAdultFee:
      number('malaysianAdultFee', fallbackKey: 'adultFee'),
      malaysianChildFee:
      number('malaysianChildFee', fallbackKey: 'childFee'),
      malaysianSeniorFee: number('malaysianSeniorFee'),
      nonMalaysianAdultFee:
      number('nonMalaysianAdultFee', fallbackKey: 'adultFee'),
      nonMalaysianChildFee:
      number('nonMalaysianChildFee', fallbackKey: 'childFee'),
      nonMalaysianSeniorFee: number('nonMalaysianSeniorFee'),
      openingTime: oldOpeningTime,
      closingTime: oldClosingTime,
      openingHours: loadedOpeningHours,
      isOpen24Hours: loadedOpen24Hours,
      recommendedDuration:
      (data['recommendedDuration'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      phoneNumber: (data['phoneNumber'] ?? '').toString().trim(),
      websiteUrl: (data['websiteUrl'] ?? '').toString().trim(),
      googlePlaceId: (data['googlePlaceId'] ?? '').toString().trim(),
      latitude: number('latitude'),
      longitude: number('longitude'),
      facilities: stringList('facilities'),
      highlights: stringList('highlights'),
      imageUrls: loadedImageUrls,
      coverImageUrl: loadedCoverImageUrl,
      status: (data['status'] ?? 'Active').toString().trim(),
      createdAt: loadedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    String finalCoverImageUrl = coverImageUrl.trim();

    if (finalCoverImageUrl.isEmpty && imageUrls.isNotEmpty) {
      finalCoverImageUrl = imageUrls.first;
    }

    final ids = <String>{
      ...categoryIds.map((value) => value.trim()).where((value) => value.isNotEmpty),
      if (categoryId.trim().isNotEmpty) categoryId.trim(),
    }.toList();

    final names = <String>{
      ...categoryNames
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
      if (categoryName.trim().isNotEmpty) categoryName.trim(),
    }.toList();

    return <String, dynamic>{
      'name': name.trim(),
      'categoryId': categoryId.trim(),
      'categoryName': categoryName.trim(),
      'categoryIds': ids,
      'categoryNames': names,
      'state': state.trim(),
      'area': area.trim(),
      'description': description.trim(),
      'isFreeEntry': isFreeEntry,
      'malaysianAdultFee': isFreeEntry ? 0 : malaysianAdultFee,
      'malaysianChildFee': isFreeEntry ? 0 : malaysianChildFee,
      'malaysianSeniorFee': isFreeEntry ? 0 : malaysianSeniorFee,
      'nonMalaysianAdultFee': isFreeEntry ? 0 : nonMalaysianAdultFee,
      'nonMalaysianChildFee': isFreeEntry ? 0 : nonMalaysianChildFee,
      'nonMalaysianSeniorFee': isFreeEntry ? 0 : nonMalaysianSeniorFee,
      'openingTime': openingTime.trim(),
      'closingTime': closingTime.trim(),
      'openingHours': openingHours,
      'isOpen24Hours': isOpen24Hours,
      'recommendedDuration': recommendedDuration.trim(),
      'address': address.trim(),
      'phoneNumber': phoneNumber.trim(),
      'websiteUrl': websiteUrl.trim(),
      'googlePlaceId': googlePlaceId.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'facilities': facilities,
      'highlights': highlights,
      'imageUrls': imageUrls,
      'coverImageUrl': finalCoverImageUrl,
      'status': status.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AttractionModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    List<String>? categoryIds,
    List<String>? categoryNames,
    String? state,
    String? area,
    String? description,
    bool? isFreeEntry,
    double? malaysianAdultFee,
    double? malaysianChildFee,
    double? malaysianSeniorFee,
    double? nonMalaysianAdultFee,
    double? nonMalaysianChildFee,
    double? nonMalaysianSeniorFee,
    String? openingTime,
    String? closingTime,
    Map<String, List<String>>? openingHours,
    bool? isOpen24Hours,
    String? recommendedDuration,
    String? address,
    String? phoneNumber,
    String? websiteUrl,
    String? googlePlaceId,
    double? latitude,
    double? longitude,
    List<String>? facilities,
    List<String>? highlights,
    List<String>? imageUrls,
    String? coverImageUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return AttractionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIds: categoryIds ?? List<String>.from(this.categoryIds),
      categoryNames:
      categoryNames ?? List<String>.from(this.categoryNames),
      state: state ?? this.state,
      area: area ?? this.area,
      description: description ?? this.description,
      isFreeEntry: isFreeEntry ?? this.isFreeEntry,
      malaysianAdultFee: malaysianAdultFee ?? this.malaysianAdultFee,
      malaysianChildFee: malaysianChildFee ?? this.malaysianChildFee,
      malaysianSeniorFee: malaysianSeniorFee ?? this.malaysianSeniorFee,
      nonMalaysianAdultFee:
      nonMalaysianAdultFee ?? this.nonMalaysianAdultFee,
      nonMalaysianChildFee:
      nonMalaysianChildFee ?? this.nonMalaysianChildFee,
      nonMalaysianSeniorFee:
      nonMalaysianSeniorFee ?? this.nonMalaysianSeniorFee,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      openingHours: openingHours ??
          this.openingHours.map(
                (key, value) => MapEntry(key, List<String>.from(value)),
          ),
      isOpen24Hours: isOpen24Hours ?? this.isOpen24Hours,
      recommendedDuration:
      recommendedDuration ?? this.recommendedDuration,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      facilities: facilities ?? List<String>.from(this.facilities),
      highlights: highlights ?? List<String>.from(this.highlights),
      imageUrls: imageUrls ?? List<String>.from(this.imageUrls),
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}