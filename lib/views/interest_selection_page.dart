import 'package:flutter/material.dart';

import '../controllers/personalization_controller.dart';
import '../models/interest_category.dart';
import 'home_page.dart';

class InterestSelectionPage extends StatefulWidget {
  const InterestSelectionPage({
    super.key,
  });

  @override
  State<InterestSelectionPage> createState() =>
      _InterestSelectionPageState();
}

class _InterestSelectionPageState
    extends State<InterestSelectionPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);

  final PersonalizationController _controller =
      PersonalizationController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(_refresh);
    _controller.loadCategories();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();

    super.dispose();
  }

  Future<void> _continue() async {
    final success =
        await _controller.saveInitialInterests();

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ??
                'Please select at least one interest.',
          ),
        ),
      );

      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  24,
                  22,
                  18,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What interests you?',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Select your interests to personalize your\nSmart EcoTravel experience',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          color: mainGreen,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Travel Preferences',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _content(),
                  ],
                ),
              ),
            ),
            _bottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_controller.isLoadingCategories) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            color: mainGreen,
          ),
        ),
      );
    }

    if (_controller.categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No active attraction categories are available yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryText,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 720 ? 4 : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: _controller.categories.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.08,
          ),
          itemBuilder: (context, index) {
            return _interestCard(
              _controller.categories[index],
            );
          },
        );
      },
    );
  }

  Widget _interestCard(
    InterestCategory category,
  ) {
    final selected =
        _controller.isSelected(category.id);

    return InkWell(
      onTap: () {
        _controller.toggleInterest(category.id);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected
              ? lightGreen
              : Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? mainGreen
                : const Color(0xFFD9D9D9),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.025,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            if (selected)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.check_circle,
                  color: mainGreen,
                  size: 17,
                ),
              ),
            Center(
              child: Text(
                category.name,
                textAlign:
                    TextAlign.center,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton() {
    final count =
        _controller.selectedInterestIds.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        12,
        22,
        18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8E8E8),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed:
              _controller.isSavingInterests
                  ? null
                  : _continue,
          style: ElevatedButton.styleFrom(
            backgroundColor: mainGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
          child: _controller.isSavingInterests
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  count == 0
                      ? 'Continue'
                      : 'Continue  •  $count selected',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
