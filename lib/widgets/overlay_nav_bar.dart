import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

class OverlayNavBar extends StatelessWidget {
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double iconSize;
  final EdgeInsets padding;
  final List<String>? labels;
  final Color activeColor;
  final Color inactiveColor;
  final Gradient? borderGradient;
  final double blurSigma;
  final bool enableBlur;
  final bool showLabels;
  final double dotSize;
  final bool hideOnScroll; // exposed for architecture; nav remains stateless
  final bool respectSafeArea;
  final double extraBottomPadding;
  final Color? tintColor;
  final Color? labelColor;
  final Color? activeLabelColor;

  const OverlayNavBar({
    super.key,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    this.iconSize = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    this.labels,
    this.activeColor = CupertinoColors.activeBlue,
    this.inactiveColor = Colors.black87,
    this.borderGradient,
    this.blurSigma = 26,
    this.enableBlur = true,
    this.showLabels = false,
    this.dotSize = 7.5,
    this.hideOnScroll = false,
    this.respectSafeArea = true,
    this.extraBottomPadding = 0,
    this.tintColor,
    this.labelColor,
    this.activeLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final double safe = respectSafeArea ? (bottomInset > 0 ? bottomInset : 0) : 0;
    final EdgeInsetsGeometry effectivePadding = padding.add(
      EdgeInsets.only(bottom: safe + extraBottomPadding),
    );

    const double borderRadius = 28.0;
    const double borderWidth = 1.2;
    // animation tuning moved into _NavContent

    return IgnorePointer(
      ignoring: false,
      child: Container(
        color: Colors.transparent,
        padding: effectivePadding,
        child: Container(
          decoration: BoxDecoration(
            gradient: borderGradient ?? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.55),
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.55),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Container(
            margin: const EdgeInsets.all(borderWidth),
            decoration: BoxDecoration(
              color: tintColor ?? Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(borderRadius - borderWidth),
            ),
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - borderWidth),
                child: (enableBlur && blurSigma > 0)
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                        child: _NavContent(
                          selectedIndex: selectedIndex,
                          icons: icons,
                          onSelected: onSelected,
                          iconSize: iconSize,
                          labels: labels,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          dotSize: dotSize,
                          showLabels: showLabels,
                          labelColor: labelColor,
                          activeLabelColor: activeLabelColor,
                        ),
                      )
                    : _NavContent(
                        selectedIndex: selectedIndex,
                        icons: icons,
                        onSelected: onSelected,
                        iconSize: iconSize,
                        labels: labels,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        dotSize: dotSize,
                        showLabels: showLabels,
                        labelColor: labelColor,
                        activeLabelColor: activeLabelColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavContent extends StatelessWidget {
  const _NavContent({
    required this.selectedIndex,
    required this.icons,
    required this.onSelected,
    required this.iconSize,
    required this.labels,
    required this.activeColor,
    required this.inactiveColor,
    required this.dotSize,
    required this.showLabels,
    required this.labelColor,
    required this.activeLabelColor,
  });

  final int selectedIndex;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;
  final double iconSize;
  final List<String>? labels;
  final Color activeColor;
  final Color inactiveColor;
  final double dotSize;
  final bool showLabels;
  final Color? labelColor;
  final Color? activeLabelColor;

  @override
  Widget build(BuildContext context) {
    const double hoverExtraScale = 0.04;
    const double selectedScale = 1.12;
    const double inactiveOpacity = 0.88;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              final next = (selectedIndex + 1).clamp(0, icons.length - 1);
              if (next != selectedIndex) onSelected(next);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final prev = (selectedIndex - 1).clamp(0, icons.length - 1);
              if (prev != selectedIndex) onSelected(prev);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double fullWidth = constraints.maxWidth;
            final int count = icons.length;
            if (count == 0) return const SizedBox.shrink();

            final double dotDiameter = dotSize;
            final double slotWidth = fullWidth / count;
            final double dotLeft = slotWidth * selectedIndex + (slotWidth / 2) - (dotDiameter / 2);

            final double minHit = iconSize + 24;
            final double rowHeight = minHit < 56 ? 56 : minHit;
            final double labelHeight = showLabels ? 20 : 0;
            final double baseRowHeight = iconSize + 29 + labelHeight;
            final double containerHeight = (rowHeight + labelHeight) > baseRowHeight ? (rowHeight + labelHeight) : baseRowHeight;

            return SizedBox(
              height: containerHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(count, (index) {
                      final bool isSelected = index == selectedIndex;
                      return Expanded(
                        key: ValueKey('nav_expanded_$index'),
                        child: Center(
                          child: RepaintBoundary(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (index != selectedIndex) {
                                  HapticFeedback.lightImpact();
                                }
                                onSelected(index);
                              },
                              child: Semantics(
                                button: true,
                                selected: isSelected,
                                label: () {
                                  final base = (labels != null && index < (labels!.length)) ? labels![index] : 'Tab';
                                  return '$base, tab ${index + 1} of $count';
                                }(),
                                child: SizedBox(
                                  height: rowHeight + labelHeight,
                                  child: showLabels
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _HoverIcon(
                                              key: ValueKey('icon_$index'),
                                              icon: icons[index],
                                              size: iconSize,
                                              selected: isSelected,
                                              activeColor: activeColor,
                                              inactiveColor: inactiveColor,
                                              selectedScale: selectedScale,
                                              hoverExtraScale: hoverExtraScale,
                                              inactiveOpacity: inactiveOpacity,
                                            ),
                                            if (labels != null && index < labels!.length) ...[
                                              const SizedBox(height: 6),
                                              AnimatedOpacity(
                                                duration: const Duration(milliseconds: 160),
                                                opacity: 1.0,
                                                child: Text(
                                                  labels![index],
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? (activeLabelColor ?? activeColor)
                                                        : (labelColor ?? inactiveColor.withOpacity(0.9)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      : Tooltip(
                                          message: (labels != null && index < (labels!.length)) ? labels![index] : '',
                                          preferBelow: false,
                                          verticalOffset: 22,
                                          waitDuration: const Duration(milliseconds: 300),
                                          showDuration: const Duration(milliseconds: 1200),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: (isSelected ? activeColor : inactiveColor).withOpacity(0.92),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.18),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                          child: _HoverIcon(
                                            key: ValueKey('icon_$index'),
                                            icon: icons[index],
                                            size: iconSize,
                                            selected: isSelected,
                                            activeColor: activeColor,
                                            inactiveColor: inactiveColor,
                                            selectedScale: selectedScale,
                                            hoverExtraScale: hoverExtraScale,
                                            inactiveOpacity: inactiveOpacity,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Cubic(0.2, 0.9, 0.25, 1.0),
                    left: dotLeft,
                    bottom: 4,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      scale: 1.0,
                      child: Container(
                        width: dotDiameter,
                        height: dotDiameter,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HoverIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final double selectedScale;
  final double hoverExtraScale;
  final double inactiveOpacity;

  const _HoverIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.selectedScale,
    required this.hoverExtraScale,
    required this.inactiveOpacity,
  });

  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late AnimationController _scaleCtl; // unbounded controller to drive spring scale

  @override
  void initState() {
    super.initState();
    final initialScale = (widget.selected ? widget.selectedScale : 1.0) + (_hover ? widget.hoverExtraScale : 0.0);
    _scaleCtl = AnimationController.unbounded(vsync: this, value: initialScale);
  }

  @override
  void didUpdateWidget(covariant _HoverIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animateTo(_targetScale());
  }

  double _targetScale() => (widget.selected ? widget.selectedScale : 1.0) + (_hover ? widget.hoverExtraScale : 0.0);

  void _animateTo(double target) {
    const mass = 1.0;
    const stiffness = 300.0;
    const damping = 22.0;
    final sim = SpringSimulation(SpringDescription(mass: mass, stiffness: stiffness, damping: damping), _scaleCtl.value, target, 0);
    _scaleCtl.animateWith(sim);
  }

  @override
  void dispose() {
    _scaleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = widget.selected ? 1.0 : widget.inactiveOpacity;
    final Color color = widget.selected ? widget.activeColor : widget.inactiveColor;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        _animateTo(_targetScale());
      },
      onExit: (_) {
        setState(() => _hover = false);
        _animateTo(_targetScale());
      },
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0, end: _hover ? -3.0 : 0.0),
        builder: (context, dy, child) => Transform.translate(
          offset: Offset(0, dy),
          child: AnimatedBuilder(
            animation: _scaleCtl,
            builder: (context, child) => Transform.scale(scale: _scaleCtl.value, child: child),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: opacity,
              child: Icon(
                widget.icon,
                size: widget.size,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

