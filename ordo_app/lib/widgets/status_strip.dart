import 'package:flutter/material.dart';
import '../controllers/assistant_controller.dart';
import '../theme/app_theme.dart';

class StatusStrip extends StatelessWidget {
  final AssistantState state;
  final bool isGuest;

  const StatusStrip({
    super.key,
    required this.state,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // State indicator
          _buildStateIndicator(),
          
          // User status
          _buildUserStatus(),
        ],
      ),
    );
  }

  Widget _buildStateIndicator() {
    final (icon, label, color) = _getStateInfo();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isGuest ? 'Guest' : 'User',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withOpacity(0.6),
                ],
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _getStateInfo() {
    switch (state) {
      case AssistantState.idle:
        return (Icons.bolt, 'Idle', AppTheme.primary);
      case AssistantState.listening:
        return (Icons.mic, 'Listening', AppTheme.success);
      case AssistantState.thinking:
        return (Icons.psychology_outlined, 'Thinking', AppTheme.primary);
      case AssistantState.executing:
        return (Icons.settings_outlined, 'Executing', AppTheme.warning);
      case AssistantState.completing:
        return (Icons.check_circle_outline, 'Complete', AppTheme.success);
      case AssistantState.showingPanel:
        return (Icons.dashboard_outlined, 'Active', AppTheme.success);
      case AssistantState.error:
        return (Icons.error_outline, 'Error', AppTheme.error);
    }
  }
}
