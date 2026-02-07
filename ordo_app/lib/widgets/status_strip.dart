import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/assistant_controller.dart';
import '../services/auth_service.dart';
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
    final authService = context.watch<AuthService>();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // State indicator
          _buildStateIndicator(),
          
          // User status
          _buildUserStatus(authService),
        ],
      ),
    );
  }

  Widget _buildStateIndicator() {
    final (icon, label, color) = _getStateInfo();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
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

  Widget _buildUserStatus(AuthService authService) {
    // Get username from user data, or extract from email, or default to 'Guest'
    String username = 'Guest';
    
    if (authService.user != null) {
      // Try to get username first
      if (authService.user!['username'] != null && authService.user!['username'].toString().isNotEmpty) {
        username = authService.user!['username'];
      } 
      // If no username, extract from email
      else if (authService.user!['email'] != null) {
        final email = authService.user!['email'].toString();
        // Extract part before @
        if (email.contains('@')) {
          username = email.split('@')[0];
        }
      }
    }
    
    final isAuthenticated = authService.isAuthenticated;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            username,
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
                  isAuthenticated ? AppTheme.primary : AppTheme.textSecondary,
                  isAuthenticated 
                    ? AppTheme.primary.withValues(alpha: 0.6)
                    : AppTheme.textSecondary.withValues(alpha: 0.6),
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
