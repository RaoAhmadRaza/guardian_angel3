import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class CustomPillBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CustomPillBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const Color kBlue = Color(0xFF1E64F0);
  static const Color kBlueDark = Color(0xFF1B58DD);
  static const Color kWhite = Colors.white;

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    const double horizontalPadding = 18;
    const double capsuleHeight = 46;
    const double iconSize = 22;
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;

    const labelStyle = TextStyle(
      color: kBlue,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    // Compute dynamic capsule width based on selected label text width
    final textPainter = TextPainter(
      text: TextSpan(text: items[selectedIndex].label, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    const double innerHPad = 12; // matches padding used inside capsule
    const double selectedIconSize = 20;
    const double gap = 8;
    final double capsuleWidth =
        textPainter.width + selectedIconSize + gap + innerHPad * 2;

    return LayoutBuilder(builder: (context, constraints) {
      final double fullWidth = constraints.maxWidth;
      final int count = items.length;
      final double usableWidth = fullWidth - (horizontalPadding * 2);
      final double slotWidth = usableWidth / count;

        final double capsuleLeft = horizontalPadding +
          (slotWidth * selectedIndex) +
          (slotWidth - capsuleWidth) / 2;

      return SizedBox(
        height: navHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: kBlue,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: kBlueDark.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(count, (index) {
                    final bool isSelected = index == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => onItemSelected(index),
                        child: SizedBox(
                          height: navHeight,
                          child: Center(
                            child: AnimatedOpacity(
                              duration: duration,
                              curve: curve,
                              opacity: isSelected ? 0.0 : 0.9,
                              child: Icon(
                                items[index].icon,
                                size: iconSize,
                                color: kWhite.withOpacity(0.95),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            AnimatedPositioned(
              duration: duration,
              curve: curve,
              left: capsuleLeft,
              top: (navHeight - capsuleHeight) / 2,
              height: capsuleHeight,
              child: GestureDetector(
                onTap: () {},
                child: AnimatedContainer(
                  duration: duration,
                  curve: curve,
                  width: capsuleWidth,
                  height: capsuleHeight,
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: innerHPad),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Row(
                      key: ValueKey<int>(selectedIndex),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[selectedIndex].icon,
                          size: selectedIconSize,
                          color: kBlue,
                        ),
                        const SizedBox(width: gap),
                        Text(
                          items[selectedIndex].label,
                          style: labelStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              left: horizontalPadding,
              right: horizontalPadding,
              child: Row(
                children: List.generate(count, (index) {
                  return Expanded(
                    child: Center(
                      child: IgnorePointer(
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            items[index].icon,
                            size: 18,
                            color: kWhite.withOpacity(0.18),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    });
  }
}
