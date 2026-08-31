import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class EcoBottomNavigation extends StatelessWidget {
  const EcoBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label})>[
      (icon: Icons.home_outlined, label: 'Home'),
      (icon: Icons.commute_outlined, label: 'Transport'),
      (icon: Icons.eco_outlined, label: 'Plan Trip'),
      (icon: Icons.track_changes_outlined, label: 'Dashboard'),
      (icon: Icons.person_outline, label: 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 74,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final selected = index == selectedIndex;
            return InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.green : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        items[index].icon,
                        color: selected ? Colors.white : AppColors.muted,
                        size: 25,
                      ),
                    ),
                    Text(
                      items[index].label,
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
