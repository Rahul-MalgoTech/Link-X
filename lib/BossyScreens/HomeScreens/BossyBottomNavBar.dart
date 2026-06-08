import 'package:flutter/material.dart';

class BossyBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BossyBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _items = <_BossyNavItem>[
    _BossyNavItem(Icons.local_fire_department_outlined, 'Home'),
    _BossyNavItem(Icons.explore_outlined, 'Explore'),
    _BossyNavItem(Icons.groups_2_outlined, 'People'),
    _BossyNavItem(Icons.chat_bubble_outline_rounded, 'Chat'),
    _BossyNavItem(Icons.person_outline_rounded, 'User'),
  ];

  @override
  Widget build(BuildContext context) {
    const navWidth = 327.0;
    const navHeight = 64.0;
    const activeSize = 56.0;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 18),
      child: Center(
        child: Container(
          width: navWidth,
          height: navHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A754764),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: _selectedLeft(selectedIndex, navWidth, activeSize),
                top: (navHeight - activeSize) / 2,
                child: Container(
                  width: activeSize,
                  height: activeSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAAE2B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Row(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: Tooltip(
                      message: item.label,
                      child: InkResponse(
                        onTap: () => onTap(index),
                        radius: 28,
                        child: SizedBox(
                          height: navHeight,
                          child: Icon(
                            item.icon,
                            size: index == 2 ? 27 : 26,
                            color: selected
                                ? Colors.white
                                : const Color(0xFFA98CAA),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _selectedLeft(int index, double navWidth, double activeSize) {
    final itemWidth = navWidth / _items.length;
    final clampedIndex = index.clamp(0, _items.length - 1);
    return itemWidth * clampedIndex + (itemWidth - activeSize) / 2;
  }
}

class _BossyNavItem {
  final IconData icon;
  final String label;

  const _BossyNavItem(this.icon, this.label);
}
