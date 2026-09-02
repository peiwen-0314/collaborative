import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/ai_trip_planner_controller.dart';
import '../models/attraction.dart';
import 'attraction_detail_page.dart';
import 'trip_location_date_page.dart';

class GeneratedTripPage extends StatefulWidget {
  final AiTripPlannerController controller;

  const GeneratedTripPage({
    super.key,
    required this.controller,
  });

  @override
  State<GeneratedTripPage> createState() => _GeneratedTripPageState();
}

class _GeneratedTripPageState extends State<GeneratedTripPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color textGrey = Color(0xFF666666);

  int selectedDay = 0;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _savedPlanId;

  @override
  Widget build(BuildContext context) {
    final int days = widget.controller.preferences.totalDays <= 0
        ? 1
        : widget.controller.preferences.totalDays;

    final List<AttractionModel> list =
    widget.controller.attractionsForDay(selectedDay);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: lightGreen,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: mainGreen,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your trip is ready!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'We’ve crafted a personalized, sustainable itinerary just for you.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF777777),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _summary(),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: days,
                        separatorBuilder: (_, __) => const SizedBox(width: 7),
                        itemBuilder: (context, index) {
                          final bool isSelected = selectedDay == index;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedDay = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? mainGreen : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? mainGreen
                                      : const Color(0xFFE1E1E1),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Day ${index + 1}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF555555),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child: Text('No attractions for this day.'),
                        ),
                      )
                    else
                      ...List.generate(
                        list.length,
                            (index) => _item(
                          list[index],
                          index,
                          index == list.length - 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _bottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
          ),
          const Expanded(
            child: Text(
              'AI Trip Planner',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _summary() {
    final preferences = widget.controller.preferences;
    final int totalDays = preferences.totalDays;
    final double budget = preferences.budget;
    final int places = widget.controller.generatedAttractions.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryBox(
              icon: Icons.calendar_today_outlined,
              value: '$totalDays Days',
              label: 'Total Days',
            ),
          ),
          Expanded(
            child: _summaryBox(
              icon: Icons.account_balance_wallet_outlined,
              value: 'MYR ${_formatMoney(budget)}',
              label: 'Trip Budget',
            ),
          ),
          Expanded(
            child: _summaryBox(
              icon: Icons.location_on_outlined,
              value: '$places ${places == 1 ? 'Place' : 'Places'}',
              label: 'Total Attractions',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: mainGreen),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 6.7,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(AttractionModel attraction, int index, bool last) {
    final String image = attraction.coverImageUrl.trim().isNotEmpty
        ? attraction.coverImageUrl
        : attraction.imageUrls.isNotEmpty
        ? attraction.imageUrls.first
        : '';

    final int hour = 8 + index * 3;
    final String time =
        '${hour > 12 ? hour - 12 : hour}:30 ${hour >= 12 ? 'pm' : 'am'}';

    final double estimatedFee =
    widget.controller.estimateAttractionFee(attraction);
    final String openingHours = _openingHours(attraction);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF555555),
            ),
          ),
        ),
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: mainGreen, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: 140,
                  color: const Color(0xFFAAAAAA),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttractionDetailPage(
                    attraction: attraction,
                    estimatedFee: estimatedFee,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 82,
                      height: 112,
                      child: image.isEmpty
                          ? Container(
                        color: lightGreen,
                        child: const Icon(
                          Icons.image_outlined,
                          color: mainGreen,
                        ),
                      )
                          : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: lightGreen,
                          child: const Icon(
                            Icons.image_outlined,
                            color: mainGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attraction.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: mainGreen,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${attraction.area}, ${attraction.state}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: mainGreen,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 11,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                openingHours,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 11,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                attraction.isFreeEntry
                                    ? 'Free Entry'
                                    : 'Estimated Fee: MYR ${_formatMoney(estimatedFee)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        if (!attraction.isFreeEntry)
                          _feeInformation(attraction),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            attraction.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: mainGreen,
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feeInformation(AttractionModel attraction) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        if (attraction.malaysianAdultFee > 0)
          _feeChip('Adult', attraction.malaysianAdultFee),
        if (attraction.malaysianChildFee > 0)
          _feeChip('Child', attraction.malaysianChildFee),
        if (attraction.malaysianSeniorFee > 0)
          _feeChip('Senior', attraction.malaysianSeniorFee),
      ],
    );
  }

  Widget _feeChip(String label, double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Text(
        '$label RM${_formatMoney(price)}',
        style: const TextStyle(
          fontSize: 6.7,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  Widget _bottomButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _toggleSavePlan,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainGreen,
                  side: const BorderSide(color: mainGreen, width: 1.2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mainGreen,
                  ),
                )
                    : Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 17,
                ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isSaved
                      ? 'Saved'
                      : 'Save Plan',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _regeneratePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Regenerate Plan',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSavePlan() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login before saving your trip plan.',
        isError: true,
      );
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isSaved) {
        final savedId = _savedPlanId;

        if (savedId != null) {
          await FirebaseFirestore.instance
              .collection('saved_trip_plans')
              .doc(savedId)
              .delete();
        }

        if (!mounted) return;

        setState(() {
          _isSaved = false;
          _savedPlanId = null;
        });

        _showMessage('Trip plan removed from saved plans.');
        return;
      }

      if (widget.controller.generatedAttractions.isEmpty) {
        _showMessage(
          'There is no trip plan to save.',
          isError: true,
        );
        return;
      }

      final preferences = widget.controller.preferences;
      final attractions = widget.controller.generatedAttractions;
      final List<Map<String, dynamic>> attractionData = [];

      for (final attraction in attractions) {
        attractionData.add({
          'id': attraction.id,
          'name': attraction.name,
          'categoryId': attraction.categoryId,
          'categoryName': attraction.categoryName,
          'state': attraction.state,
          'area': attraction.area,
          'address': attraction.address,
          'description': attraction.description,
          'coverImageUrl': attraction.coverImageUrl,
          'imageUrls': attraction.imageUrls,
          'isFreeEntry': attraction.isFreeEntry,
          'malaysianAdultFee': attraction.malaysianAdultFee,
          'malaysianChildFee': attraction.malaysianChildFee,
          'malaysianSeniorFee': attraction.malaysianSeniorFee,
          'nonMalaysianAdultFee': attraction.nonMalaysianAdultFee,
          'nonMalaysianChildFee': attraction.nonMalaysianChildFee,
          'nonMalaysianSeniorFee': attraction.nonMalaysianSeniorFee,
          'estimatedFee': widget.controller.estimateAttractionFee(attraction),
          'openingTime': attraction.openingTime,
          'closingTime': attraction.closingTime,
          'recommendedDuration': attraction.recommendedDuration,
          'phoneNumber': attraction.phoneNumber,
          'facilities': attraction.facilities,
          'highlights': attraction.highlights,
          'day': _getAttractionDay(attraction),
        });
      }

      final doc = await FirebaseFirestore.instance
          .collection('saved_trip_plans')
          .add({
        'userId': user.uid,
        'userEmail': user.email,
        'selectedState': preferences.selectedState,
        'startDate': preferences.startDate == null
            ? null
            : Timestamp.fromDate(preferences.startDate!),
        'endDate': preferences.endDate == null
            ? null
            : Timestamp.fromDate(preferences.endDate!),
        'totalDays': preferences.totalDays,
        'dateSummary': preferences.dateSummary,
        'adults': preferences.adults,
        'children': preferences.children,
        'seniors': preferences.seniors,
        'totalTravelers': preferences.totalTravelers,
        'travelerSummary': preferences.travelerSummary,
        'wheelchairAccessible': preferences.wheelchairAccessible,
        'strollerFriendly': preferences.strollerFriendly,
        'serviceAnimalFriendly': preferences.serviceAnimalFriendly,
        'budget': preferences.budget,
        'estimatedAttractionCost':
        widget.controller.estimatedTotalAttractionCost,
        'travelStyle': preferences.travelStyle,
        'totalAttractions': attractions.length,
        'attractions': attractionData,
        'status': 'saved',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isSaved = true;
        _savedPlanId = doc.id;
      });

      _showMessage('Trip plan saved successfully!');
    } catch (e) {
      debugPrint('Toggle save trip plan error: $e');

      if (!mounted) return;

      _showMessage(
        _isSaved
            ? 'Unable to remove saved trip plan.'
            : 'Unable to save trip plan.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  int _getAttractionDay(AttractionModel attraction) {
    final int totalDays = widget.controller.preferences.totalDays <= 0
        ? 1
        : widget.controller.preferences.totalDays;

    for (int day = 0; day < totalDays; day++) {
      final List<AttractionModel> dayAttractions =
      widget.controller.attractionsForDay(day);

      final bool exists = dayAttractions.any(
            (item) => item.id == attraction.id,
      );

      if (exists) {
        return day + 1;
      }
    }

    return 1;
  }

  void _regeneratePlan() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => TripLocationDatePage(
          controller: widget.controller,
        ),
      ),
          (route) => route.isFirst,
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : mainGreen,
      ),
    );
  }

  String _openingHours(AttractionModel attraction) {
    final String opening = _format24HourTime(attraction.openingTime);
    final String closing = _format24HourTime(attraction.closingTime);

    if (opening.isEmpty && closing.isEmpty) {
      return 'Opening hours unavailable';
    }
    if (opening.isEmpty) return closing;
    if (closing.isEmpty) return opening;

    return '$opening-$closing';
  }

  String _format24HourTime(String value) {
    final String input = value.trim();

    if (input.isEmpty) return '';

    final Match? normal24 = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(input);

    if (normal24 != null) {
      final int hour = int.tryParse(normal24.group(1)!) ?? 0;
      final String minute = normal24.group(2)!;
      return '$hour:$minute';
    }

    final Match? twelveHour = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(input);

    if (twelveHour != null) {
      int hour = int.tryParse(twelveHour.group(1)!) ?? 0;
      final String minute = twelveHour.group(2)!;
      final String period = twelveHour.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return '$hour:$minute';
    }

    return input;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}
