import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_storage_service.dart';
import '../widgets/heritage_image.dart';
import 'heritage_detail_page.dart';

class HeritageDiaryPage extends StatefulWidget {
  const HeritageDiaryPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<HeritageDiaryPage> createState() => _HeritageDiaryPageState();
}

class _HeritageDiaryPageState extends State<HeritageDiaryPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE6F4E5);
  static const Color borderColor = Color(0xFFE2E2E2);

  final HeritageStorageService _storage = HeritageStorageService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _timelineController = ScrollController();

  bool _loading = true;
  bool _newestFirst = true;

  DateTime? _selectedDate;

  List<HeritageDiaryEntry> _entries = const [];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _loadDiary() async {
    final entries = await _storage.loadDiaryEntries();

    if (!mounted) return;

    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openMap(HeritageAttraction attraction) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
          '${attraction.latitude},${attraction.longitude}',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _removeEntry(HeritageDiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from diary?'),
          content: Text(
            'Remove ${entry.attraction.name} from your travel diary?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: green,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _storage.removeFromDiary(entry.attraction.id);
    await _loadDiary();
  }

  Future<void> _openCalendar() async {
    DateTime initialDate;

    if (_selectedDate != null) {
      initialDate = _selectedDate!;
    } else if (_entries.isNotEmpty) {
      initialDate = _entries.first.savedAt.toLocal();
    } else {
      initialDate = DateTime.now();
    }

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Future dates are not allowed.
    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: green,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final pickedDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );

    setState(() {
      _selectedDate = pickedDate;
    });

    // Make the chosen calendar date visible in the horizontal timeline.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timelineController.hasClients) return;

      final dayDifference = today.difference(pickedDate).inDays;

      // Each timeline item has a fixed width of 66.
      const itemWidth = 66.0;

      final viewportWidth =
          _timelineController.position.viewportDimension;

      // Place the selected day roughly in the middle of the visible timeline.
      final targetOffset =
          (dayDifference * itemWidth) -
              ((viewportWidth - itemWidth) / 2);

      final safeOffset = targetOffset
          .clamp(
        0.0,
        _timelineController.position.maxScrollExtent,
      )
          .toDouble();

      _timelineController.animateTo(
        safeOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _locationText(HeritageAttraction attraction) {
    final city = attraction.city.trim();
    final state = attraction.state.trim();

    if (city.isEmpty) {
      return '$state, Malaysia';
    }

    if (city.toLowerCase() == state.toLowerCase()) {
      return '$state, Malaysia';
    }

    return '$city, $state, Malaysia';
  }

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${_months[date.month - 1]} ${date.year}'
        ' · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _entries.where((entry) {
      final attraction = entry.attraction;
      final saved = entry.savedAt.toLocal();

      final matchesSearch =
          query.isEmpty ||
              attraction.name.toLowerCase().contains(query) ||
              attraction.city.toLowerCase().contains(query) ||
              attraction.state.toLowerCase().contains(query);

      final matchesDate =
          _selectedDate == null ||
              (saved.year == _selectedDate!.year &&
                  saved.month == _selectedDate!.month &&
                  saved.day == _selectedDate!.day);

      return matchesSearch && matchesDate;
    }).toList();

    filtered.sort(
          (a, b) => _newestFirst
          ? b.savedAt.compareTo(a.savedAt)
          : a.savedAt.compareTo(b.savedAt),
    );

    final page = Column(
      children: [
        _buildHeader(),
        _buildTimeline(),
        _buildSearchBar(),
        _buildJourneyHeader(),
        Expanded(
          child: _loading
              ? const Center(
            child: CircularProgressIndicator(
              color: green,
            ),
          )
              : filtered.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            color: green,
            onRefresh: _loadDiary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                8,
                0,
                8,
                24,
              ),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildDiaryCard(filtered[index]);
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: Colors.white,
        child: page,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: page,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 10, 7),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.chevron_left,
                size: 25,
                color: Colors.black87,
              ),
            ),

          const SizedBox(width: 2),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Travel Diary',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Your Journey. Your Story.',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: _openCalendar,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: green,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget _buildTimeline() {
    final now = DateTime.now();

    // Today is always the newest/right-most date.
    final anchorDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Match the date picker's first available date.
    final firstTimelineDate = DateTime(2020, 1, 1);

    // Generate every day from 1 Jan 2020 until today.
    final totalDays =
        anchorDate.difference(firstTimelineDate).inDays + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diary Timeline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 9),

          SizedBox(
            height: 58,
            child: ListView.builder(
              controller: _timelineController,
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemCount: totalDays,
              itemBuilder: (context, index) {
                final date = anchorDate.subtract(
                  Duration(days: index),
                );

                final count = _entries.where((entry) {
                  final saved = entry.savedAt.toLocal();
                  return _sameDay(saved, date);
                }).length;

                final selected = _selectedDate != null
                    ? _sameDay(_selectedDate!, date)
                    : index == 0;

                return SizedBox(
                  width: 66,
                  child: _buildTimelineItem(
                    date: date,
                    count: count,
                    selected: selected,
                    showLeftLine: index != totalDays - 1,
                    showRightLine: index != 0,
                    onTap: () {
                      setState(() {
                        if (_selectedDate != null &&
                            _sameDay(_selectedDate!, date)) {
                          _selectedDate = null;
                        } else {
                          _selectedDate = date;
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required DateTime date,
    required int count,
    required bool selected,
    required bool showLeftLine,
    required bool showRightLine,
    required VoidCallback onTap,
  }) {
    const Color lineColor = Color(0xFFA9C9A5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(
            width: 66,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Connecting line behind the circles.
                Positioned(
                  left: showLeftLine ? 0 : 33,
                  right: showRightLine ? 0 : 33,
                  top: 16,
                  child: Container(
                    height: 1.4,
                    color: lineColor,
                  ),
                ),

                // Date circle.
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? green : Colors.white,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(
                      color: const Color(0xFFD0D0D0),
                    ),
                  ),
                  child: Text(
                    '${date.day}\n${_months[date.month - 1]}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 7.5,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '$count ${count == 1 ? 'place' : 'places'}',
            style: TextStyle(
              color: selected ? green : Colors.black54,
              fontSize: 7.5,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 13),
      child: SizedBox(
        height: 27,
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 9,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search your locations...',
            hintStyle: const TextStyle(
              fontSize: 8,
              color: Colors.black45,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 15,
              color: Colors.black38,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 27,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFD8D8D8),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFD8D8D8),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: green,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // JOURNEY HEADER
  // ============================================================

  Widget _buildJourneyHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
      child: Row(
        children: [
          const Text(
            'Your Journey',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const Spacer(),

          PopupMenuButton<bool>(
            padding: EdgeInsets.zero,
            onSelected: (value) {
              setState(() {
                _newestFirst = value;
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: true,
                child: Text('Newest First'),
              ),
              PopupMenuItem(
                value: false,
                child: Text('Oldest First'),
              ),
            ],
            child: Row(
              children: [
                Text(
                  _newestFirst
                      ? 'Newest First'
                      : 'Oldest First',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.black54,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIARY CARD
  // ============================================================

  Widget _buildDiaryCard(HeritageDiaryEntry entry) {
    final attraction = entry.attraction;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),

        // Tap card = Heritage details
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeritageDetailPage(
                attraction: attraction,
              ),
            ),
          );
        },

        // Long press = remove (alternative to delete icon)
        onLongPress: () => _removeEntry(entry),

        child: Container(
          height: 92,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            children: [
              // IMAGE
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: HeritageImage(
                  imageUrl: attraction.imageUrl,
                  width: 54,
                  height: 80,
                ),
              ),

              const SizedBox(width: 9),

              // INFORMATION
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            attraction.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),


                      ],
                    ),

                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        attraction.category,
                        style: const TextStyle(
                          color: green,
                          fontSize: 5.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 8,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            _locationText(attraction),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 5.8,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 8,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            _formatDateTime(entry.savedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 5.4,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // MAP PREVIEW
              _buildMiniMap(attraction),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MINI MAP
  // ============================================================

  Widget _buildMiniMap(HeritageAttraction attraction) {
    return GestureDetector(
      onTap: () => _openMap(attraction),
      child: Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5F2),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: const Color(0xFFE6E6E6),
          ),
        ),
        child: Stack(
          children: [
            // Small map-like lines
            Positioned(
              left: 6,
              right: -5,
              top: 18,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  height: 2,
                  color: Colors.white,
                ),
              ),
            ),

            Positioned(
              left: 28,
              top: -5,
              child: Transform.rotate(
                angle: 0.15,
                child: Container(
                  width: 2,
                  height: 65,
                  color: const Color(0xFFD9E6EA),
                ),
              ),
            ),

            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Icon(
                  Icons.location_on,
                  color: green,
                  size: 17,
                ),
              ),
            ),

            Positioned(
              left: 5,
              right: 5,
              bottom: 4,
              child: Container(
                height: 10,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  'View On Map',
                  style: TextStyle(
                    fontSize: 5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final filtering = _selectedDate != null ||
        _searchController.text.trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 45,
            color: Colors.black26,
          ),
          const SizedBox(height: 8),
          Text(
            filtering
                ? 'No matching diary entries.'
                : 'No saved heritage places yet.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (filtering) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                  _searchController.clear();
                });
              },
              child: const Text(
                'Clear Filters',
                style: TextStyle(
                  color: green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
