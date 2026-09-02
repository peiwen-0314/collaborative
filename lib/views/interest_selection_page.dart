import 'package:flutter/material.dart';

import '../controllers/personalization_controller.dart';
import '../models/interest_category.dart';
import 'home_page.dart';

class InterestSelectionPage extends StatefulWidget {
  const InterestSelectionPage({super.key});

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);
  static const Color borderColor = Color(0xFFE1E5E1);

  final PersonalizationController _controller = PersonalizationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.loadCategories();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_controller.selectedInterestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest.')),
      );
      return;
    }

    final success = await _controller.saveInitialInterests();
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ?? 'Unable to save your interests.',
          ),
        ),
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
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
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What interests you?',
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose what you enjoy and we will personalize attraction recommendations for you.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Travel Preferences',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _controller.selectedInterestIds.isEmpty
                          ? 'Select one or more interests'
                          : '${_controller.selectedInterestIds.length} selected',
                      style: const TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 17),
                    _buildContent(),
                  ],
                ),
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoadingCategories) {
      return const SizedBox(
        height: 280,
        child: Center(
          child: CircularProgressIndicator(color: mainGreen),
        ),
      );
    }

    if (_controller.errorMessage != null && _controller.categories.isEmpty) {
      return _buildErrorState();
    }

    if (_controller.categories.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columnCount = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 650
            ? 4
            : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _controller.categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.65,
          ),
          itemBuilder: (context, index) {
            return _buildInterestCard(_controller.categories[index]);
          },
        );
      },
    );
  }

  Widget _buildInterestCard(InterestCategory category) {
    final selected = _controller.isSelected(category.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _controller.toggleInterest(category.id),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? lightGreen : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? mainGreen : borderColor,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const []
                : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (selected)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle,
                    size: 17,
                    color: mainGreen,
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    category.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? mainGreen : textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final hasSelection = _controller.selectedInterestIds.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9ECE9)),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _controller.isSavingInterests ? null : _continue,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: mainGreen,
            disabledBackgroundColor: const Color(0xFFB8C9BA),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _controller.isSavingInterests
              ? const SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
              : Text(
            hasSelection
                ? 'Continue  •  ${_controller.selectedInterestIds.length} selected'
                : 'Continue',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 42,
            color: Color(0xFFAAAAAA),
          ),
          SizedBox(height: 12),
          Text(
            'No interests available',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Active attraction categories will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Text(
            'Unable to load interests.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _controller.loadCategories,
            style: OutlinedButton.styleFrom(
              foregroundColor: mainGreen,
              side: const BorderSide(color: mainGreen),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
