import 'package:flutter/material.dart';

import '../controllers/ai_trip_planner_controller.dart';
import 'trip_travelers_page.dart';

class TripLocationDatePage extends StatefulWidget {
  final AiTripPlannerController controller;

  const TripLocationDatePage({
    super.key,
    required this.controller,
  });

  @override
  State<TripLocationDatePage> createState() =>
      _TripLocationDatePageState();
}

class _TripLocationDatePageState extends State<TripLocationDatePage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color borderColor = Color(0xFFE1E1E1);
  static const Color textColor = Color(0xFF242424);
  static const Color secondaryText = Color(0xFF777777);

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedState;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();

    _startDate = widget.controller.preferences.startDate;
    _endDate = widget.controller.preferences.endDate;
    _selectedState = widget.controller.preferences.selectedState;

    final DateTime initial =
        _startDate ?? DateTime.now();

    _visibleMonth = DateTime(
      initial.year,
      initial.month,
      1,
    );
  }

  // ============================================================
  // MONTH NAVIGATION
  // ============================================================

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        1,
      );
    });
  }

  // ============================================================
  // DATE RANGE SELECTION
  // ============================================================

  void _selectDate(DateTime date) {
    final DateTime today = _dateOnly(DateTime.now());

    if (_dateOnly(date).isBefore(today)) {
      return;
    }

    setState(() {
      if (_startDate == null ||
          (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
        return;
      }

      if (date.isBefore(_startDate!)) {
        _startDate = date;
        _endDate = null;
        return;
      }

      _endDate = date;
    });
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }

    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool _isInSelectedRange(DateTime date) {
    if (_startDate == null || _endDate == null) {
      return false;
    }

    final DateTime value = _dateOnly(date);
    final DateTime start = _dateOnly(_startDate!);
    final DateTime end = _dateOnly(_endDate!);

    return value.isAfter(start) && value.isBefore(end);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ============================================================
  // NEXT
  // ============================================================

  void _next() {
    if (_selectedState == null ||
        _selectedState!.trim().isEmpty) {
      _showMessage(
        'Please select your travel location.',
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showMessage(
        'Please select your travel date range.',
      );
      return;
    }

    widget.controller.setStateSelection(
      _selectedState,
    );

    widget.controller.setDates(
      _startDate!,
      _endDate!,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripTravelersPage(
          controller: widget.controller,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final List<String> states =
        widget.controller.availableStates;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            _appBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  18,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _pageHeading(),

                    const SizedBox(height: 20),

                    _locationCard(states),

                    const SizedBox(height: 12),

                    _calendarCard(),

                    const SizedBox(height: 10),

                    _selectedPeriodCard(),
                  ],
                ),
              ),
            ),

            _nextButton(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  Widget _appBar() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
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
                color: textColor,
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ============================================================
  // HEADING
  // ============================================================

  Widget _pageHeading() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: lightGreen,
          child: Icon(
            Icons.calendar_month_rounded,
            color: mainGreen,
            size: 24,
          ),
        ),

        SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Select travel location & dates',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Choose the location & dates for your travels',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryText,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Widget _locationCard(List<String> states) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Travel Location',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),

          const SizedBox(height: 9),

          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: borderColor,
              ),
              borderRadius:
              BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: mainGreen,
                  size: 19,
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: states.contains(
                        _selectedState,
                      )
                          ? _selectedState
                          : null,
                      isExpanded: true,
                      icon: const Icon(
                        Icons
                            .keyboard_arrow_down_rounded,
                        size: 20,
                        color: mainGreen,
                      ),
                      hint: const Text(
                        'Search destination',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryText,
                        ),
                      ),
                      items: states
                          .map(
                            (state) =>
                            DropdownMenuItem<String>(
                              value: state,
                              child: Text(
                                state,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style:
                                const TextStyle(
                                  fontSize: 11,
                                  color: textColor,
                                ),
                              ),
                            ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  Widget _calendarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          _monthHeader(),

          const SizedBox(height: 14),

          _weekHeader(),

          const SizedBox(height: 5),

          _calendarGrid(),
        ],
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        InkWell(
          onTap: _previousMonth,
          borderRadius: BorderRadius.circular(30),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              Icons.chevron_left_rounded,
              color: mainGreen,
              size: 23,
            ),
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Text(
                '${_visibleMonth.year}',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: mainGreen,
                ),
              ),

              const SizedBox(height: 1),

              Text(
                _monthName(
                  _visibleMonth.month,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: mainGreen,
                ),
              ),
            ],
          ),
        ),

        InkWell(
          onTap: _nextMonth,
          borderRadius: BorderRadius.circular(30),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              Icons.chevron_right_rounded,
              color: mainGreen,
              size: 23,
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekHeader() {
    const List<String> weekdays = [
      'Su',
      'Mo',
      'Tu',
      'We',
      'Th',
      'Fr',
      'Sa',
    ];

    return Row(
      children: weekdays
          .map(
            (day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 8,
                color: secondaryText,
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _calendarGrid() {
    final int year = _visibleMonth.year;
    final int month = _visibleMonth.month;

    final DateTime firstDay =
    DateTime(year, month, 1);

    // Dart: Monday = 1 ... Sunday = 7.
    // Calendar: Sunday = 0 ... Saturday = 6.
    final int leadingDays =
        firstDay.weekday % 7;

    final DateTime gridStart =
    firstDay.subtract(
      Duration(days: leadingDays),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final DateTime date =
        gridStart.add(
          Duration(days: index),
        );

        return _calendarDay(
          date,
          month,
        );
      },
    );
  }

  Widget _calendarDay(
      DateTime date,
      int visibleMonthNumber,
      ) {
    final bool inCurrentMonth =
        date.month == visibleMonthNumber;

    final DateTime today =
    _dateOnly(DateTime.now());

    final bool isPast =
    _dateOnly(date).isBefore(today);

    final bool isStart =
    _isSameDate(date, _startDate);

    final bool isEnd =
    _isSameDate(date, _endDate);

    final bool isRange =
    _isInSelectedRange(date);

    final bool isSelected =
        isStart || isEnd;

    Color background = Colors.transparent;
    Color foreground = textColor;

    if (!inCurrentMonth) {
      foreground = const Color(0xFFBDBDBD);
    }

    if (isPast) {
      foreground = const Color(0xFFC6C6C6);
    }

    if (isRange) {
      background =
      const Color(0xFFF0F3F0);
      foreground = textColor;
    }

    if (isSelected) {
      background = mainGreen;
      foreground = Colors.white;
    }

    return InkWell(
      onTap: isPast
          ? null
          : () {
        _selectDate(date);

        if (date.month !=
            _visibleMonth.month) {
          setState(() {
            _visibleMonth = DateTime(
              date.year,
              date.month,
              1,
            );
          });
        }
      },
      borderRadius: BorderRadius.circular(7),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius:
          BorderRadius.circular(7),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 11,
            color: foreground,
            fontWeight: isSelected
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED PERIOD
  // ============================================================

  Widget _selectedPeriodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: mainGreen,
            size: 20,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Period',
                  style: TextStyle(
                    fontSize: 8,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _dateSummary(),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEXT BUTTON
  // ============================================================

  Widget _nextButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        18,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 47,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: mainGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(6),
            ),
          ),
          child: const Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(
                'Next: Travelers',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _monthName(int month) {
    const List<String> months = [
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

    return months[month - 1];
  }

  String _shortMonth(int month) {
    const List<String> months = [
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

    return months[month - 1];
  }

  String _dateSummary() {
    if (_startDate == null && _endDate == null) {
      return 'Select your travel dates';
    }

    if (_startDate != null && _endDate == null) {
      return '${_shortMonth(_startDate!.month)} '
          '${_startDate!.day}, ${_startDate!.year} - Select end date';
    }

    final DateTime start = _startDate!;
    final DateTime end = _endDate!;

    if (start.year == end.year) {
      return '${_shortMonth(start.month)} ${start.day} - '
          '${_shortMonth(end.month)} ${end.day}, ${end.year}';
    }

    return '${_shortMonth(start.month)} ${start.day}, ${start.year} - '
        '${_shortMonth(end.month)} ${end.day}, ${end.year}';
  }
}
