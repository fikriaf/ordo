import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ThinkingPanel extends StatefulWidget {
  final List<String> steps;

  const ThinkingPanel({
    super.key,
    required this.steps,
  });

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Abstract Visualization
          _buildVisualization(),

          const SizedBox(height: 24),

          // Planning Panel
          _buildPlanningPanel(context),

          const SizedBox(height: 16),

          // Thinking Pulse Text
          _buildPulseText(),
        ],
      ),
    );
  }

  Widget _buildVisualization() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring - pulsing
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 96 + (_pulseController.value * 8),
                  height: 96 + (_pulseController.value * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Inner ring
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            // Icon
            const Icon(
              Icons.psychology,
              size: 40,
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanningPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.insights,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Planning',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Steps with terminal-like style
          ...widget.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == widget.steps.length - 1;
            final isCompleted = step.toLowerCase().contains('completed') ||
                step.toLowerCase().contains('done') ||
                step.toLowerCase().contains('✓');
            final isProcessing = step.toLowerCase().contains('processing') ||
                step.toLowerCase().contains('...') ||
                step.toLowerCase().contains('receiving');

            return _buildStep(
              context,
              step,
              isLast: isLast,
              isCompleted: isCompleted,
              isProcessing: isProcessing,
            );
          }),

          // Stats Row
          if (widget.steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Slippage', '0.5%'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Routes', '128'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    String step, {
    required bool isLast,
    required bool isCompleted,
    required bool isProcessing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree-style prefix
          Text(
            isLast ? '└─' : '├─',
            style: TextStyle(
              fontFamily: 'monospace',
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isProcessing
                            ? Colors.white
                            : Colors.white.withOpacity(0.9),
                        fontWeight:
                            isProcessing ? FontWeight.w500 : FontWeight.normal,
                      ),
                ),
                const SizedBox(height: 4),
                // Status indicator
                Row(
                  children: [
                    if (isCompleted) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (isProcessing) ...[
                      _buildProcessingDots(),
                      const SizedBox(width: 8),
                      Text(
                        'PROCESSING...',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingDots() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity = ((_pulseController.value + delay) % 1.0);
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2 + (opacity * 0.8)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
              letterSpacing: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseText() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(
                    0.5 + (_pulseController.value * 0.5),
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Analyzing liquidity pools...',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
