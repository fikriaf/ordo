import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChartToggleButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const ChartToggleButton({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 32,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Center(
          child: AnimatedRotation(
            turns: isOpen ? 0.5 : 0.0, // Rotate 180 degrees when open
            duration: const Duration(milliseconds: 300),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
