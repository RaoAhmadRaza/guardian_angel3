import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../models/menu_item.dart';

class MenuRow extends StatefulWidget {
  final MenuItemModel data;
  final VoidCallback onTap;
  final bool isActive;

  const MenuRow({
    super.key,
    required this.data,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      widget.data.stateMachine,
    );
    if (controller != null) {
      artboard.addController(controller);
      widget.data.input = controller.findInput<bool>('active') as SMIBool?;
    }
  }

  void _onMenuPressed() {
    // Trigger animation
    if (widget.data.input != null) {
      widget.data.input!.value = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && widget.data.input != null) {
          widget.data.input!.value = false;
        }
      });
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _onMenuPressed,
      child: Stack(
        children: [
          // Animated background for active state
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: widget.isActive ? 288 - 32 : 0,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF4D7CFE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Menu content
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                // Rive Icon
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Opacity(
                    opacity: widget.isActive ? 1.0 : 0.5,
                    child: RiveAnimation.asset(
                      'assets/RiveAssets/icons.riv',
                      artboard: widget.data.artboard,
                      stateMachines: [widget.data.stateMachine],
                      onInit: _onRiveInit,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    widget.data.title,
                    style: TextStyle(
                      color: widget.isActive 
                          ? const Color(0xFF4D7CFE) 
                          : const Color(0xFF9E9E9E),
                      fontSize: 16,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: 'Inter',
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
}
