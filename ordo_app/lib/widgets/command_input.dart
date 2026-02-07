import 'package:flutter/material.dart';
import '../controllers/assistant_controller.dart';
import '../theme/app_theme.dart';
import 'bouncing_progress.dart';

class CommandInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final AssistantState state;
  final VoidCallback onSubmit;
  final VoidCallback onVoiceInput;

  const CommandInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.state,
    required this.onSubmit,
    required this.onVoiceInput,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: focusNode.hasFocus
                    ? AppTheme.primary.withOpacity(0.3)
                    : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Ordo logo icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/logo_ordo.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Text input
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: const InputDecoration(
                      hintText: 'What do you want to do?',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Voice button with tooltip
                Tooltip(
                  message: 'Long press to speak',
                  preferBelow: false,
                  child: GestureDetector(
                    onTap: () {
                      // Show snackbar hint on single tap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('💡 Long press microphone to speak'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onLongPress: onVoiceInput,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.mic_none,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bouncing loading bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isLoading ? 2 : 0,
            child: isLoading
                ? BouncingProgress(
                    color: _getLoadingColor(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _getLoadingColor() {
    switch (state) {
      case AssistantState.listening:
        return AppTheme.success;
      case AssistantState.thinking:
        return AppTheme.primary;
      case AssistantState.executing:
        return AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }
}
