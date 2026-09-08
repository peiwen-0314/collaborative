import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../models/attraction.dart';
import '../models/location_point.dart';
import '../models/saved_trip_plan.dart';
import '../services/location_service.dart';
import 'saved_trip_plans_page.dart';

class EditSavedTripPlanPage extends StatefulWidget {
  const EditSavedTripPlanPage({
    super.key,
    required this.planId,
    required this.initialData,
  });

  final String planId;
  final Map<String, dynamic> initialData;

  @override
  State<EditSavedTripPlanPage> createState() =>
      _EditSavedTripPlanPageState();
}

class _EditSavedTripPlanPageState extends State<EditSavedTripPlanPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TransportController _transportController = TransportController();
  final LocationService _locationService = const LocationService();

  late Map<String, dynamic> _data;
  late List<Map<String, dynamic>> _attractions;

  int _selectedDay = 0;
  bool _saving = false;

  int get _totalDays =>
      ((_data['totalDays'] as num?)?.toInt() ?? 1).clamp(1, 365);

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
    _attractions = _readAttractions(widget.initialData);
  }

  List<Map<String, dynamic>> _readAttractions(
    Map<String, dynamic> data,
  ) {
    final raw = data['attractions'];
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _forDay(int day) {
    return _attractions
        .where((item) => ((item['day'] as num?)?.toInt() ?? 1) == day)
        .toList();
  }

  void _replaceDay(int day, List<Map<String, dynamic>> reordered) {
    final result = <Map<String, dynamic>>[];
    var inserted = false;

    for (final item in _attractions) {
      final itemDay = (item['day'] as num?)?.toInt() ?? 1;
      if (itemDay == day) {
        if (!inserted) {
          result.addAll(reordered);
          inserted = true;
        }
      } else {
        result.add(item);
      }
    }

    if (!inserted) result.addAll(reordered);
    _attractions = result;
  }

  Future<void> _showAttractionPicker({int? replaceGlobalIndex}) async {
    final selected = await showModalBottomSheet<AttractionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AttractionPickerSheet(
        selectedState: (_data['selectedState'] ?? '').toString(),
        excludedIds: _attractions
            .map((item) => (item['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet(),
        allowId: replaceGlobalIndex == null
            ? null
            : (_attractions[replaceGlobalIndex]['id'] ?? '').toString(),
      ),
    );

    if (!mounted || selected == null) return;

    final mapped = _mapFromAttraction(
      selected,
      day: _selectedDay + 1,
    );

    setState(() {
      if (replaceGlobalIndex != null) {
        _attractions[replaceGlobalIndex] = mapped;
      } else {
        _attractions.add(mapped);
      }
    });
  }

  Map<String, dynamic> _mapFromAttraction(
    AttractionModel attraction, {
    required int day,
  }) {
    return <String, dynamic>{
      'id': attraction.id,
      'name': attraction.name,
      'categoryId': attraction.categoryId,
      'categoryName': attraction.categoryName,
      'categoryIds': attraction.categoryIds,
      'categoryNames': attraction.categoryNames,
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
      'estimatedFee': _estimatedFee(attraction),
      'openingTime': attraction.openingTime,
      'closingTime': attraction.closingTime,
      'recommendedDuration': attraction.recommendedDuration,
      'phoneNumber': attraction.phoneNumber,
      'facilities': attraction.facilities,
      'highlights': attraction.highlights,
      'day': day,
    };
  }

  double _estimatedFee(AttractionModel attraction) {
    if (attraction.isFreeEntry) return 0;

    final adults = (_data['adults'] as num?)?.toInt() ?? 0;
    final children = (_data['children'] as num?)?.toInt() ?? 0;
    final seniors = (_data['seniors'] as num?)?.toInt() ?? 0;

    return adults * attraction.malaysianAdultFee +
        children * attraction.malaysianChildFee +
        seniors * attraction.malaysianSeniorFee;
  }

  int _globalIndexOf(Map<String, dynamic> target) {
    return _attractions.indexWhere((item) => identical(item, target));
  }

  void _removeAttraction(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _attractions.length) return;

    final name =
        (_attractions[globalIndex]['name'] ?? 'this attraction').toString();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove attraction?'),
        content: Text('Remove $name from Day ${_selectedDay + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _attractions.removeAt(globalIndex));
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_saving) return;

    if (_attractions.isEmpty) {
      _message('Your trip needs at least one attraction.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final cleanAttractions = _attractions.map((item) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('startTime');
        copy.remove('endTime');
        copy.remove('visitMinutes');
        copy.remove('transportMinutesBefore');
        copy.remove('distanceFromPreviousKm');
        copy.remove('usedHereRouting');
        return copy;
      }).toList();

      final estimatedCost = cleanAttractions.fold<double>(
        0,
        (sum, item) =>
            sum + ((item['estimatedFee'] as num?)?.toDouble() ?? 0),
      );

      final workingData = Map<String, dynamic>.from(_data)
        ..['attractions'] = cleanAttractions
        ..['totalAttractions'] = cleanAttractions.length
        ..['estimatedAttractionCost'] = estimatedCost
        ..['updatedAt'] = Timestamp.now();

      final plan = SavedTripPlan.fromFirestore(
        widget.planId,
        workingData,
      );

      final locationResult = await _locationService.detectCurrentLocation();
      if (!mounted) return;

      final LocationPoint? startingFrom = locationResult.point;
      if (startingFrom == null) {
        _message(
          "Couldn't detect your location. Please enable location and try again.",
          error: true,
        );
        return;
      }

      final legs = await _transportController.planTransportationForPlan(
        plan,
        startingFrom: startingFrom,
      );

      final queues = <String, List<int>>{};
      for (var i = 0; i < cleanAttractions.length; i++) {
        final item = cleanAttractions[i];
        final key =
            '${(item['day'] as num?)?.toInt() ?? 1}::${item['name']}';
        queues.putIfAbsent(key, () => <int>[]).add(i);
      }

      double totalTransportCost = 0;
      double totalTransportCo2 = 0;

      for (final leg in legs) {
        final key = '${leg.day}::${leg.attractionName}';
        final indices = queues[key];
        if (indices == null || indices.isEmpty) continue;

        final index = indices.removeAt(0);
        final item = cleanAttractions[index];

        item['startTime'] = Timestamp.fromDate(leg.visitStart);
        item['endTime'] = Timestamp.fromDate(leg.visitEnd);
        item['visitMinutes'] =
            leg.visitEnd.difference(leg.visitStart).inMinutes;

        final option = leg.option;
        if (option != null) {
          item['transportMinutesBefore'] = option.totalDuration.inMinutes;
          totalTransportCost += option.estCostRm ?? 0;
          totalTransportCo2 += option.co2Kg;
        }
      }

      workingData['attractions'] = cleanAttractions;
      workingData['totalTransportCostRm'] = totalTransportCost;
      workingData['totalTransportCo2Kg'] = totalTransportCo2;

      await _firestore
          .collection('saved_trip_plans')
          .doc(widget.planId)
          .update(workingData);

      await _transportController.saveTransportPlan(widget.planId, legs);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const SavedTripPlansPage(),
        ),
        (route) => false,
      );
    } catch (error) {
      debugPrint('[EditSavedTripPlanPage] save failed: $error');
      if (!mounted) return;
      _message(
        'Unable to save the updated trip plan. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : mainGreen,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDay + 1;
    final current = _forDay(day);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: textColor),
        ),
        title: const Text(
          'Customize Trip',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveChanges,
            child: Text(
              _saving ? 'Saving...' : 'Save',
              style: const TextStyle(
                color: mainGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drag attractions to change the sequence.',
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalDays,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (_, index) {
                      final selected = _selectedDay == index;
                      return InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _selectedDay = index),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? mainGreen : Colors.white,
                            border: Border.all(
                              color: selected
                                  ? mainGreen
                                  : const Color(0xFFE1E1E1),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Day ${index + 1}',
                            style: TextStyle(
                              color: selected
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
              ],
            ),
          ),
          Expanded(
            child: current.isEmpty
                ? _emptyDay()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                    itemCount: current.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      if (_saving) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered =
                            List<Map<String, dynamic>>.from(current);
                        final moved = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, moved);
                        _replaceDay(day, reordered);
                      });
                    },
                    itemBuilder: (_, index) {
                      final attraction = current[index];
                      final globalIndex = _globalIndexOf(attraction);
                      return _editableCard(
                        key: ValueKey(
                          '${attraction['id']}-${attraction['name']}-$index',
                        ),
                        attraction: attraction,
                        index: index,
                        globalIndex: globalIndex,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showAttractionPicker(),
        backgroundColor: mainGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Attraction',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _emptyDay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 42,
            color: Color(0xFFAAAAAA),
          ),
          const SizedBox(height: 10),
          Text(
            'No attractions on Day ${_selectedDay + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add an attraction to build this day.',
            style: TextStyle(fontSize: 11, color: secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _editableCard({
    required Key key,
    required Map<String, dynamic> attraction,
    required int index,
    required int globalIndex,
  }) {
    String image = (attraction['coverImageUrl'] ?? '').toString().trim();
    if (image.isEmpty) {
      final images = attraction['imageUrls'];
      if (images is List && images.isNotEmpty) {
        image = images.first.toString();
      }
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E6E2)),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 18),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Color(0xFF888888),
              ),
            ),
          ),
          const SizedBox(width: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 62,
              height: 62,
              child: image.isEmpty
                  ? Container(
                      color: lightGreen,
                      child: const Icon(
                        Icons.place_outlined,
                        color: mainGreen,
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: lightGreen,
                        child: const Icon(
                          Icons.place_outlined,
                          color: mainGreen,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (attraction['name'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (attraction['area'] ?? attraction['state'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Position ${index + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: mainGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Edit attraction',
            onSelected: (value) {
              if (value == 'replace') {
                _showAttractionPicker(replaceGlobalIndex: globalIndex);
              } else if (value == 'remove') {
                _removeAttraction(globalIndex);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'replace',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18),
                    SizedBox(width: 9),
                    Text('Replace Attraction'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'Remove Attraction',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttractionPickerSheet extends StatefulWidget {
  const _AttractionPickerSheet({
    required this.selectedState,
    required this.excludedIds,
    this.allowId,
  });

  final String selectedState;
  final Set<String> excludedIds;
  final String? allowId;

  @override
  State<_AttractionPickerSheet> createState() =>
      _AttractionPickerSheetState();
}

class _AttractionPickerSheetState extends State<_AttractionPickerSheet> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);

  final TextEditingController _searchController = TextEditingController();

  List<AttractionModel> _all = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('attractions').get();

      var attractions = snapshot.docs
          .map(AttractionModel.fromFirestore)
          .where(
            (item) => item.status.trim().toLowerCase() == 'active',
          )
          .toList();

      final state = widget.selectedState.trim().toLowerCase();
      if (state.isNotEmpty) {
        attractions = attractions
            .where((item) => item.state.trim().toLowerCase() == state)
            .toList();
      }

      attractions.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _all = attractions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<AttractionModel> get _filtered {
    final q = _query.trim().toLowerCase();

    return _all.where((item) {
      final excluded =
          widget.excludedIds.contains(item.id) && item.id != widget.allowId;
      if (excluded) return false;

      if (q.isEmpty) return true;

      return item.name.toLowerCase().contains(q) ||
          item.area.toLowerCase().contains(q) ||
          item.categoryName.toLowerCase().contains(q) ||
          item.categoryNames.any(
            (name) => name.toLowerCase().contains(q),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5D5D5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose Attraction',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search attraction...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: mainGreen),
                    )
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            'No available attractions found.',
                            style: TextStyle(color: Color(0xFF777777)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final attraction = results[index];
                            final image = attraction.coverImageUrl.trim();

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 5),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: image.isEmpty
                                      ? Container(
                                          color: lightGreen,
                                          child: const Icon(
                                            Icons.place_outlined,
                                            color: mainGreen,
                                          ),
                                        )
                                      : Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: lightGreen,
                                            child: const Icon(
                                              Icons.place_outlined,
                                              color: mainGreen,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                attraction.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  attraction.area,
                                  attraction.categoryName,
                                ]
                                    .where((text) => text.trim().isNotEmpty)
                                    .join(' • '),
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: mainGreen,
                              ),
                              onTap: () =>
                                  Navigator.pop(context, attraction),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
