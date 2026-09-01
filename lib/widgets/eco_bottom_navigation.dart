import 'package:flutter/material.dart';

class EcoBottomNavigation extends StatelessWidget {
  final int currentIndex;

  final VoidCallback? onHomeTap;
  final VoidCallback? onTransportTap;
  final VoidCallback? onPlanTripTap;
  final VoidCallback? onCommunityTap;
  final VoidCallback? onProfileTap;

  const EcoBottomNavigation({
    super.key,
    required this.currentIndex,
    this.onHomeTap,
    this.onTransportTap,
    this.onPlanTripTap,
    this.onCommunityTap,
    this.onProfileTap,
  });

  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color inactiveColor =
  Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.04,
              ),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _navItem(
              index: 0,
              label: 'Home',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              onTap: onHomeTap,
            ),

            _transportItem(),

            _planTripItem(),

            _navItem(
              index: 3,
              label: 'Community',
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              onTap: onCommunityTap,
            ),

            _navItem(
              index: 4,
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NORMAL ITEM
  // ============================================================

  Widget _navItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required VoidCallback? onTap,
  }) {
    final bool selected =
        currentIndex == index;

    final Color color =
    selected ? mainGreen : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? selectedIcon
                    : icon,
                size: 22,
                color: color,
              ),

              const SizedBox(height: 3),

              Text(
                label,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TRANSPORT
  // ============================================================

  Widget _transportItem() {
    final bool selected =
        currentIndex == 1;

    return Expanded(
      child: InkWell(
        onTap: onTransportTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Image.asset(
                selected
                    ? 'assets/images/electric-vehicle (1).png'
                    : 'assets/images/electric-vehicle.png',
                width: 23,
                height: 23,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 3),

              Text(
                'Transport',
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: selected
                      ? mainGreen
                      : inactiveColor,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PLAN TRIP
  // ============================================================

  Widget _planTripItem() {
    final bool selected =
        currentIndex == 2;

    return Expanded(
      child: InkWell(
        onTap: onPlanTripTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Container(
                width: selected ? 37 : 27,
                height: selected ? 37 : 27,
                decoration: BoxDecoration(
                  color: selected
                      ? mainGreen
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.eco,
                  size: selected ? 22 : 23,
                  color: selected
                      ? Colors.white
                      : inactiveColor,
                ),
              ),

              SizedBox(
                height: selected ? 1 : 3,
              ),

              Text(
                'Plan Trip',
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: selected
                      ? mainGreen
                      : inactiveColor,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}