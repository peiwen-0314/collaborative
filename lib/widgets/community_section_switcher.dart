import 'package:flutter/material.dart';

class CommunitySectionSwitcher extends StatelessWidget {
  const CommunitySectionSwitcher({
    super.key,
    required this.showingReviews,
    required this.onCommunityTap,
    required this.onReviewsTap,
  });

  final bool showingReviews;
  final VoidCallback onCommunityTap;
  final VoidCallback onReviewsTap;

  static const Color green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SectionButton(
              label: 'Community Feed',
              icon: Icons.groups_outlined,
              selected: !showingReviews,
              onTap: onCommunityTap,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SectionButton(
              label: 'Attraction Reviews',
              icon: Icons.rate_review_outlined,
              selected: showingReviews,
              onTap: onReviewsTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Color green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? green : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : green,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
