import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/ai_trip_planner_controller.dart';
import 'trip_travel_style_page.dart';

class TripTravelersPage extends StatefulWidget {
  final AiTripPlannerController controller;

  const TripTravelersPage({
    super.key,
    required this.controller,
  });

  @override
  State<TripTravelersPage> createState() =>
      _TripTravelersPageState();
}

class _TripTravelersPageState
    extends State<TripTravelersPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color borderColor = Color(0xFFE2E2E2);
  static const Color textColor = Color(0xFF242424);
  static const Color secondaryText = Color(0xFF777777);

  static const double minBudget = 100;
  static const double maxBudget = 3000;

  late final TextEditingController _budgetController;
  late final FocusNode _budgetFocusNode;

  bool _updatingBudgetText = false;

  @override
  void initState() {
    super.initState();

    _budgetController = TextEditingController(
      text: widget.controller.preferences.budget.toStringAsFixed(0),
    );

    _budgetFocusNode = FocusNode();
    _budgetFocusNode.addListener(_onBudgetFocusChanged);

    widget.controller.addListener(_refreshPage);
  }

  void _refreshPage() {
    if (!mounted) return;

    final String controllerValue =
    widget.controller.preferences.budget.toStringAsFixed(0);

    // When slider changes, update the text field too.
    // Do not overwrite while the user is actively typing.
    if (!_budgetFocusNode.hasFocus &&
        _budgetController.text != controllerValue) {
      _updatingBudgetText = true;
      _budgetController.text = controllerValue;
      _budgetController.selection = TextSelection.collapsed(
        offset: _budgetController.text.length,
      );
      _updatingBudgetText = false;
    }

    setState(() {});
  }

  void _onBudgetFocusChanged() {
    if (!_budgetFocusNode.hasFocus) {
      _commitBudgetInput();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshPage);

    _budgetFocusNode.removeListener(_onBudgetFocusChanged);
    _budgetFocusNode.dispose();
    _budgetController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUDGET
  // ============================================================

  void _onBudgetTextChanged(String value) {
    if (_updatingBudgetText) return;

    final String cleaned = value.replaceAll(',', '').trim();

    if (cleaned.isEmpty) {
      return;
    }

    final double? parsed = double.tryParse(cleaned);

    if (parsed == null) {
      return;
    }

    // While typing, only update controller when value is within range.
    if (parsed >= minBudget && parsed <= maxBudget) {
      widget.controller.setBudget(parsed);
    }
  }

  void _commitBudgetInput() {
    final String cleaned =
    _budgetController.text.replaceAll(',', '').trim();

    double? value = double.tryParse(cleaned);

    if (value == null) {
      value = widget.controller.preferences.budget;
    }

    value = value.clamp(minBudget, maxBudget).toDouble();

    widget.controller.setBudget(value);

    final String normalized = value.toStringAsFixed(0);

    _updatingBudgetText = true;
    _budgetController.text = normalized;
    _budgetController.selection = TextSelection.collapsed(
      offset: normalized.length,
    );
    _updatingBudgetText = false;
  }

  void _onSliderChanged(double value) {
    widget.controller.setBudget(value);

    final String normalized = value.toStringAsFixed(0);

    _updatingBudgetText = true;
    _budgetController.text = normalized;
    _budgetController.selection = TextSelection.collapsed(
      offset: normalized.length,
    );
    _updatingBudgetText = false;
  }

  // ============================================================
  // NEXT
  // ============================================================

  void _next() {
    _commitBudgetInput();

    if (widget.controller.preferences.totalTravelers <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one traveler.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripTravelStylePage(
          controller: widget.controller,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final p = widget.controller.preferences;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeading(),

                    const SizedBox(height: 18),

                    // =====================================================
                    // TRAVELER COUNTERS
                    // =====================================================

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: borderColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _counter(
                            icon: Icons.people_outline,
                            title: 'Adults',
                            subtitle: 'Age 13+',
                            value: p.adults,
                            onMinus: () {
                              widget.controller.setAdults(
                                p.adults - 1,
                              );
                            },
                            onPlus: () {
                              widget.controller.setAdults(
                                p.adults + 1,
                              );
                            },
                          ),

                          _counter(
                            icon: Icons.child_care_outlined,
                            title: 'Children',
                            subtitle: 'Age 2–12',
                            value: p.children,
                            onMinus: () {
                              widget.controller.setChildren(
                                p.children - 1,
                              );
                            },
                            onPlus: () {
                              widget.controller.setChildren(
                                p.children + 1,
                              );
                            },
                          ),

                          _counter(
                            icon: Icons.elderly_outlined,
                            title: 'Senior',
                            subtitle: 'Age 55+',
                            value: p.seniors,
                            onMinus: () {
                              widget.controller.setSeniors(
                                p.seniors - 1,
                              );
                            },
                            onPlus: () {
                              widget.controller.setSeniors(
                                p.seniors + 1,
                              );
                            },
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =====================================================
                    // ACCESSIBILITY
                    // =====================================================

                    const Text(
                      'Accessibility & Special Needs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _access(
                            icon: Icons.accessible_forward_rounded,
                            label: 'Wheelchair\nAccessible',
                            selected: p.wheelchairAccessible,
                            onTap: () {
                              widget.controller.setAccessibility(
                                wheelchair:
                                !p.wheelchairAccessible,
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _access(
                            icon:
                            Icons.baby_changing_station_rounded,
                            label: 'Stroller\nFriendly',
                            selected: p.strollerFriendly,
                            onTap: () {
                              widget.controller.setAccessibility(
                                stroller:
                                !p.strollerFriendly,
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _access(
                            icon: Icons.pets_outlined,
                            label: 'Service\nAnimal',
                            selected:
                            p.serviceAnimalFriendly,
                            onTap: () {
                              widget.controller.setAccessibility(
                                serviceAnimal:
                                !p.serviceAnimalFriendly,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // =====================================================
                    // BUDGET
                    // =====================================================

                    const Text(
                      'Budget (MYR)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        14,
                        16,
                        14,
                        14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: borderColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // =================================================
                          // DIRECT BUDGET INPUT
                          // =================================================

                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(
                                    left: 14,
                                  ),
                                  child: Text(
                                    'MYR',
                                    style: TextStyle(
                                      color: mainGreen,
                                      fontSize: 12,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: TextField(
                                    controller:
                                    _budgetController,
                                    focusNode:
                                    _budgetFocusNode,
                                    keyboardType:
                                    TextInputType.number,
                                    textInputAction:
                                    TextInputAction.done,
                                    textAlign: TextAlign.center,

                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        4,
                                      ),
                                    ],

                                    style: const TextStyle(
                                      color: mainGreen,
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),

                                    decoration:
                                    const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintText: '800',
                                      hintStyle: TextStyle(
                                        color:
                                        Color(0xFF8CB98F),
                                        fontSize: 14,
                                      ),
                                    ),

                                    onChanged:
                                    _onBudgetTextChanged,

                                    onSubmitted: (_) {
                                      _commitBudgetInput();
                                      FocusScope.of(context)
                                          .unfocus();
                                    },

                                    onTapOutside: (_) {
                                      FocusScope.of(context)
                                          .unfocus();
                                    },
                                  ),
                                ),

                                const SizedBox(width: 42),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // =================================================
                          // DRAGGABLE SLIDER
                          // =================================================

                          SliderTheme(
                            data:
                            SliderTheme.of(context).copyWith(
                              activeTrackColor: mainGreen,
                              inactiveTrackColor:
                              const Color(0xFFD9E7DA),
                              thumbColor: mainGreen,
                              overlayColor:
                              mainGreen.withValues(
                                alpha: 0.12,
                              ),
                              trackHeight: 4,
                              thumbShape:
                              const RoundSliderThumbShape(
                                enabledThumbRadius: 9,
                              ),
                              overlayShape:
                              const RoundSliderOverlayShape(
                                overlayRadius: 17,
                              ),
                            ),
                            child: Slider(
                              value: p.budget.clamp(
                                minBudget,
                                maxBudget,
                              ),
                              min: minBudget,
                              max: maxBudget,

                              // No divisions:
                              // slider is continuous and has no small dots.
                              onChanged: _onSliderChanged,
                            ),
                          ),

                          const Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MYR 100',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryText,
                                ),
                              ),
                              Text(
                                'MYR 3,000',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          const Text(
                            'Drag the slider or enter your budget directly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =====================================================
            // NEXT BUTTON
            // =====================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                8,
                14,
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
                      BorderRadius.circular(7),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next: Travel Style',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                      ),
                    ],
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
  // PAGE HEADING
  // ============================================================

  Widget _pageHeading() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: lightGreen,
          child: Icon(
            Icons.people_outline,
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
                'Who’s traveling?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),

              SizedBox(height: 2),

              Text(
                'Tell us who’s joining this trip.',
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COUNTER
  // ============================================================

  Widget _counter({
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    bool last = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: lightGreen,
                child: Icon(
                  icon,
                  color: mainGreen,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 1),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 9,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              _circle(
                icon: Icons.remove,
                onTap: onMinus,
                enabled: value > 0,
              ),

              SizedBox(
                width: 38,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ),

              _circle(
                icon: Icons.add,
                onTap: onPlus,
                enabled: value < 20,
              ),
            ],
          ),
        ),

        if (!last)
          const Divider(
            height: 1,
            indent: 55,
            endIndent: 12,
            color: borderColor,
          ),
      ],
    );
  }

  // ============================================================
  // +/- BUTTON
  // ============================================================

  Widget _circle({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    final Color color =
    enabled
        ? mainGreen
        : const Color(0xFFBDBDBD);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: color,
            width: 1.6,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
    );
  }

  // ============================================================
  // ACCESSIBILITY CARD
  // ============================================================

  Widget _access({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 82,
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? lightGreen : Colors.white,
          border: Border.all(
            color:
            selected ? mainGreen : borderColor,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: mainGreen,
                    size: 24,
                  ),

                  const SizedBox(height: 5),

                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      height: 1.15,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              const Positioned(
                right: 1,
                top: 1,
                child: Icon(
                  Icons.check_circle,
                  color: mainGreen,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
