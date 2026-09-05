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

    // When the diary first opens, actually filter to TODAY.
    // Previously the timeline visually highlighted today while
    // _selectedDate was still null, so entries from older dates
    // (for example 4 Sep) were also shown.
    final now = DateTime.now();
    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

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

    await _storage.removeFromDiary(entry.documentId);
    await _loadDiary();
  }

  Future<void> _editEntryDate(HeritageDiaryEntry entry) async {
    final current = entry.savedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final initialDate = DateTime(
      current.year,
      current.month,
      current.day,
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(today)
          ? today
          : initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
      helpText: 'Edit diary date',
      confirmText: 'Save Date',
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

    if (pickedDate == null || !mounted) {
      return;
    }

    // Keep the original saved time and only change the calendar date.
    final updatedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );

    final updated =
    await _storage.updateDiarySavedAt(
      entry.documentId,
      updatedDateTime,
    );

    if (!mounted) {
      return;
    }

    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${entry.attraction.name} is already saved '
                'on ${pickedDate.day} '
                '${_months[pickedDate.month - 1]} '
                '${pickedDate.year}.',
          ),
        ),
      );
      return;
    }

    await _loadDiary();

    if (!mounted) {
      return;
    }

    // If the diary was filtered to the old date, move the filter
    // to the newly selected date so the edited entry remains visible.
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Diary date updated to '
              '${pickedDate.day} '
              '${_months[pickedDate.month - 1]} '
              '${pickedDate.year}.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }


  Future<void> _editStory(HeritageDiaryEntry entry) async {
    final savedStory = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _StoryEditorDialog(
          attractionName: entry.attraction.name,
          initialStory: entry.story,
        );
      },
    );

    if (savedStory == null || !mounted) {
      return;
    }

    final cleanStory = savedStory.trim();

    if (cleanStory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story cannot be empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _storage.updateDiaryStory(
      entry.documentId,
      cleanStory,
    );

    await _loadDiary();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Your story has been saved.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

    final firstAllowedDate = DateTime(2020, 1, 1);

    // Future dates are not allowed.
    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    if (initialDate.isBefore(firstAllowedDate)) {
      initialDate = firstAllowedDate;
    }

    DateTime visibleMonth = DateTime(
      initialDate.year,
      initialDate.month,
      1,
    );

    DateTime selectedInDialog = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final firstDayOfMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              1,
            );

            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;

            // DateTime.weekday: Monday = 1 ... Sunday = 7.
            final leadingEmptyCells = firstDayOfMonth.weekday - 1;

            final totalGridCells =
                ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;

            final canGoPrevious = visibleMonth.isAfter(
              DateTime(
                firstAllowedDate.year,
                firstAllowedDate.month,
                1,
              ),
            );

            final canGoNext =
                visibleMonth.year < today.year ||
                    (visibleMonth.year == today.year &&
                        visibleMonth.month < today.month);

            final selectedCount =
            _heritageCountForDate(selectedInDialog);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 28,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 390,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: green,
                            size: 23,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Heritage Calendar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'The number under each date shows how many heritage places are saved that day.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 9,
                            height: 1.35,
                          ),
                        ),
                      ),

                      const SizedBox(height: 13),

                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: canGoPrevious
                                ? () {
                              setDialogState(() {
                                visibleMonth = DateTime(
                                  visibleMonth.year,
                                  visibleMonth.month - 1,
                                  1,
                                );
                              });
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_left,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${_fullMonthName(visibleMonth.month)} '
                                  '${visibleMonth.year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: canGoNext
                                ? () {
                              setDialogState(() {
                                visibleMonth = DateTime(
                                  visibleMonth.year,
                                  visibleMonth.month + 1,
                                  1,
                                );
                              });
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_right,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      const Row(
                        children: [
                          _CalendarWeekdayLabel('Mon'),
                          _CalendarWeekdayLabel('Tue'),
                          _CalendarWeekdayLabel('Wed'),
                          _CalendarWeekdayLabel('Thu'),
                          _CalendarWeekdayLabel('Fri'),
                          _CalendarWeekdayLabel('Sat'),
                          _CalendarWeekdayLabel('Sun'),
                        ],
                      ),

                      const SizedBox(height: 5),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: totalGridCells,
                        itemBuilder: (context, index) {
                          final dayNumber =
                              index - leadingEmptyCells + 1;

                          if (dayNumber < 1 ||
                              dayNumber > daysInMonth) {
                            return const SizedBox.shrink();
                          }

                          final date = DateTime(
                            visibleMonth.year,
                            visibleMonth.month,
                            dayNumber,
                          );

                          final disabled =
                              date.isAfter(today) ||
                                  date.isBefore(firstAllowedDate);

                          final selected =
                          _sameDay(date, selectedInDialog);

                          final isToday = _sameDay(date, today);

                          final heritageCount =
                          _heritageCountForDate(date);

                          return Padding(
                            padding: const EdgeInsets.all(2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: disabled
                                  ? null
                                  : () {
                                setDialogState(() {
                                  selectedInDialog = date;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? green
                                      : Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(9),
                                  border: Border.all(
                                    color: selected
                                        ? green
                                        : isToday
                                        ? const Color(
                                      0xFF8DBA8A,
                                    )
                                        : const Color(
                                      0xFFE5E5E5,
                                    ),
                                    width: isToday && !selected
                                        ? 1.4
                                        : 1,
                                  ),
                                ),
                                child: heritageCount == 0
                                    ? Center(
                                  child: Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      color: disabled
                                          ? Colors.black26
                                          : selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),
                                )
                                    : Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNumber',
                                      style: TextStyle(
                                        color: disabled
                                            ? Colors.black26
                                            : selected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white.withValues(
                                          alpha: 0.20,
                                        )
                                            : lightGreen,
                                        borderRadius:
                                        BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        '$heritageCount',
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : green,
                                          fontSize: 7,
                                          fontWeight:
                                          FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_outlined,
                              color: green,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                selectedCount == 0
                                    ? 'No heritage place saved on '
                                    '${selectedInDialog.day} '
                                    '${_months[selectedInDialog.month - 1]} '
                                    '${selectedInDialog.year}.'
                                    : '$selectedCount '
                                    '${selectedCount == 1 ? 'heritage place' : 'heritage places'} '
                                    'saved on ${selectedInDialog.day} '
                                    '${_months[selectedInDialog.month - 1]} '
                                    '${selectedInDialog.year}.',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: green,
                                side: const BorderSide(
                                  color: green,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                  selectedInDialog,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: green,
                              ),
                              child: const Text('View Date'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

  int _heritageCountForDate(DateTime date) {
    return _entries.where((entry) {
      return _sameDay(
        entry.savedAt.toLocal(),
        date,
      );
    }).length;
  }

  String _fullMonthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return names[month - 1];
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
              attraction.state.toLowerCase().contains(query) ||
              entry.story.toLowerCase().contains(query);

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
                  'My Heritage Diary',
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
    final hasStory = entry.story.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),

        // Tap card = Heritage details.
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

        // Long press = remove.
        onLongPress: () => _removeEntry(entry),

        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================================
              // LEFT: BIG IMAGE
              // ============================================================
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: HeritageImage(
                  imageUrl: attraction.imageUrl,
                  width: 94,
                  height: 136,
                ),
              ),

              const SizedBox(width: 10),

              // ============================================================
              // RIGHT: TITLE + INFO + STORY
              // ============================================================
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // Title only reserves space for the edit button.
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 34,
                          ),
                          child: Text(
                            attraction.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.8,
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),

                        const SizedBox(height: 1),

                        // Type / Category.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius:
                            BorderRadius.circular(5),
                          ),
                          child: Text(
                            attraction.category,
                            style: const TextStyle(
                              color: green,
                              fontSize: 7.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Location.
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _locationText(attraction),
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 7.3,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Date.
                        InkWell(
                          borderRadius:
                          BorderRadius.circular(6),
                          onTap: () =>
                              _editEntryDate(entry),
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 1,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 11,
                                  color: green,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    _formatDateTime(
                                      entry.savedAt,
                                    ),
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 7.1,
                                      color:
                                      Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 7),

                        // Story.
                        InkWell(
                          borderRadius:
                          BorderRadius.circular(8),
                          onTap: () => _editStory(entry),
                          child: Container(
                            width: double.infinity,
                            height: 74,
                            padding:
                            const EdgeInsets.fromLTRB(
                              9,
                              7,
                              8,
                              7,
                            ),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFF4FAF3),
                              borderRadius:
                              BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                const Color(0xFFDDECDD),
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Header elements stay at the TOP.
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_stories_outlined,
                                        size: 14,
                                        color: green,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hasStory
                                              ? 'My Story'
                                              : 'Add My Story',
                                          style: const TextStyle(
                                            color: green,
                                            fontSize: 8.0,
                                            fontWeight:
                                            FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        hasStory
                                            ? 'Tap to view'
                                            : 'Tap to add',
                                        style: const TextStyle(
                                          color: Colors.black38,
                                          fontSize: 5.9,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        hasStory
                                            ? Icons.open_in_new_rounded
                                            : Icons.add_circle_outline,
                                        color: green,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),

                                // Keep the actual story content around
                                // its current middle position.
                                Positioned(
                                  left: 20,
                                  right: 4,
                                  top: 26,
                                  child: Text(
                                    hasStory
                                        ? entry.story
                                        : 'Write about what you saw, learned or enjoyed here...',
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: hasStory
                                          ? Colors.black54
                                          : Colors.black38,
                                      fontSize: 7.0,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Overlay edit button so it does not create
                    // extra vertical space under the title.
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Tooltip(
                        message: 'Edit diary date',
                        child: InkWell(
                          borderRadius:
                          BorderRadius.circular(20),
                          onTap: () =>
                              _editEntryDate(entry),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration:
                            const BoxDecoration(
                              color: lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_calendar_outlined,
                              size: 14,
                              color: green,
                            ),
                          ),
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


class _StoryEditorDialog extends StatefulWidget {
  const _StoryEditorDialog({
    required this.attractionName,
    required this.initialStory,
  });

  final String attractionName;
  final String initialStory;

  @override
  State<_StoryEditorDialog> createState() =>
      _StoryEditorDialogState();
}

class _StoryEditorDialogState
    extends State<_StoryEditorDialog> {
  static const Color green = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE6F4E5);

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  // Always open in view mode first.
  bool _isEditing = false;

  String? _storyError;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialStory,
    );

    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _storyError = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _backToView() {
    _focusNode.unfocus();

    setState(() {
      // Discard unsaved changes.
      _controller.text = widget.initialStory;
      _isEditing = false;
      _storyError = null;
    });
  }

  void _save() {
    final story = _controller.text.trim();

    if (story.isEmpty) {
      setState(() {
        _storyError = 'Story cannot be empty.';
      });

      _focusNode.requestFocus();
      return;
    }

    Navigator.pop(
      context,
      story,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasStory = widget.initialStory.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // ==========================================================
              // HEADER
              // ==========================================================
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
                      color: green,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Story',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 17,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.attractionName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // X closes the popup without saving unsaved edits.
                  InkWell(
                    onTap: () =>
                        Navigator.pop(context),
                    customBorder:
                    const CircleBorder(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFFF3F3F3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                          const Color(0xFFE2E2E2),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ==========================================================
              // VIEW MODE - this is shown FIRST
              // ==========================================================
              if (!_isEditing) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your Experience',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),

                    FilledButton.icon(
                      onPressed: _startEditing,
                      style:
                      FilledButton.styleFrom(
                        backgroundColor: green,
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize:
                        MaterialTapTargetSize
                            .shrinkWrap,
                      ),
                      icon: Icon(
                        hasStory
                            ? Icons.edit_outlined
                            : Icons.add,
                        size: 14,
                      ),
                      label: Text(
                        hasStory
                            ? 'Edit'
                            : 'Add Story',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  constraints:
                  const BoxConstraints(
                    minHeight: 105,
                  ),
                  padding:
                  const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFF8FBF8),
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                      color:
                      const Color(0xFFDCE7DC),
                    ),
                  ),
                  child: hasStory
                      ? Text(
                    widget.initialStory,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  )
                      : const Center(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .auto_stories_outlined,
                          color:
                          Colors.black26,
                          size: 28,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'No story added yet.',
                          style: TextStyle(
                            color:
                            Colors.black38,
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tap Add Story to write about your experience.',
                          textAlign:
                          TextAlign.center,
                          style: TextStyle(
                            color:
                            Colors.black38,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ==========================================================
              // EDIT MODE - only shown AFTER pressing Edit/Add Story
              // ==========================================================
              if (_isEditing) ...[
                const Text(
                  'Edit your experience',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (value) {
                    if (_storyError != null &&
                        value.trim().isNotEmpty) {
                      setState(() {
                        _storyError = null;
                      });
                    }
                  },
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 500,
                  textCapitalization:
                  TextCapitalization.sentences,
                  textInputAction:
                  TextInputAction.newline,
                  decoration: InputDecoration(
                    errorText: _storyError,
                    hintText:
                    'What did you see, learn, feel, or enjoy here?',
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 10,
                    ),
                    filled: true,
                    fillColor:
                    const Color(0xFFF8FBF8),
                    contentPadding:
                    const EdgeInsets.all(13),
                    enabledBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                      borderSide:
                      const BorderSide(
                        color:
                        Color(0xFFDCE7DC),
                      ),
                    ),
                    focusedBorder:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                      borderSide:
                      const BorderSide(
                        color: green,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    if (widget.initialStory
                        .trim()
                        .isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                        ),
                        label:
                        const Text('Clear'),
                        style:
                        TextButton.styleFrom(
                          foregroundColor:
                          Colors.black54,
                        ),
                      ),

                    const Spacer(),

                    TextButton(
                      onPressed: _backToView,
                      child:
                      const Text('Back'),
                    ),

                    const SizedBox(width: 6),

                    FilledButton.icon(
                      onPressed: _save,
                      style:
                      FilledButton.styleFrom(
                        backgroundColor: green,
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                      ),
                      icon: const Icon(
                        Icons.check,
                        size: 16,
                      ),
                      label:
                      const Text('Save Story'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekdayLabel extends StatelessWidget {
  const _CalendarWeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black45,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}