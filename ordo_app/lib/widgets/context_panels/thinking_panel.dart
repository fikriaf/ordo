import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_process_step.dart';

class ThinkingPanel extends StatefulWidget {
  final List<AIProcessStep> processSteps;
  final double progress;
  final String currentPhase;
  final String command;
  final String? completionSummary; // Summary to show when completing
  final bool isCompleting; // Whether we're in completing state
  
  // Legacy support
  final List<String>? steps;

  const ThinkingPanel({
    super.key,
    this.processSteps = const [],
    this.progress = 0.0,
    this.currentPhase = '',
    this.command = '',
    this.completionSummary,
    this.isCompleting = false,
    this.steps, // Legacy
  });

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _lastProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    
    _progressController.forward();
  }

  @override
  void didUpdateWidget(ThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _lastProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0.0);
      _lastProgress = widget.progress;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Brain Visualization with Progress
          _buildAIVisualization(),

          const SizedBox(height: 24),

          // Command being processed
          if (widget.command.isNotEmpty) ...[
            _buildCommandCard(),
            const SizedBox(height: 16),
          ],

          // Process Steps Panel
          _buildProcessPanel(context),

          const SizedBox(height: 16),

          // Current Phase Status
          _buildCurrentPhase(),
        ],
      ),
    );
  }

  Widget _buildAIVisualization() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withOpacity(0.15),
            AppTheme.primary.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Animated Brain Icon
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 100 + (_pulseController.value * 12),
                    height: 100 + (_pulseController.value * 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2 + (_pulseController.value * 0.1)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Progress ring
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                    ),
                  );
                },
              ),
              // Inner circle with icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surface,
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress percentage
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Text(
                '${(_progressAnimation.value * 100).toInt()}%',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              );
            },
          ),
          
          const SizedBox(height: 4),
          
          // Show summary when completing, otherwise show "Processing"
          if (widget.isCompleting && widget.completionSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.success.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.completionSummary!,
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Text(
              'Processing',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.command,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessPanel(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/logo_ordo.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Process',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              // Step counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.processSteps.where((s) => s.status == StepStatus.completed).length}/${widget.processSteps.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Steps
          if (widget.processSteps.isEmpty)
            _buildEmptyState()
          else
            ...widget.processSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == widget.processSteps.length - 1;

              return _buildProcessStep(
                context,
                step,
                isLast: isLast,
                index: index,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5 + (_pulseController.value * 0.5),
                  child: Icon(
                    Icons.hourglass_empty,
                    size: 32,
                    color: AppTheme.textTertiary,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Initializing...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessStep(
    BuildContext context,
    AIProcessStep step, {
    required bool isLast,
    required int index,
  }) {
    final statusColor = _getStatusColor(step.status);
    final icon = _getStepIcon(step);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Status dot/icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: step.status == StepStatus.running
                    ? _buildRunningIndicator(statusColor)
                    : Icon(
                        icon,
                        size: 16,
                        color: statusColor,
                      ),
              ),
              // Connecting line
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        statusColor.withOpacity(0.5),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: step.status == StepStatus.running
                    ? statusColor.withOpacity(0.08)
                    : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: step.status == StepStatus.running
                      ? statusColor.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      // Step type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(step.type).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(step.type),
                          style: TextStyle(
                            color: _getTypeColor(step.type),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.displayTitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            fontWeight: step.status == StepStatus.running
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      // Status badge
                      _buildStatusBadge(step.status),
                    ],
                  ),
                  
                  // Description
                  if (step.description != null && step.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      step.description!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  
                  // Result preview (if available)
                  if (step.result != null && step.status == StepStatus.completed) ...[
                    const SizedBox(height: 8),
                    _buildResultPreview(step.result!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningIndicator(Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5 + (_pulseController.value * 0.5)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(StepStatus status) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);
    
    if (status == StepStatus.running) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnimatedDots(),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }
    
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAnimatedDots() {
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
                color: AppTheme.primary.withOpacity(0.3 + (opacity * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildResultPreview(Map<String, dynamic> result) {
    // Show a compact preview of the result
    final entries = result.entries.take(2).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: entries.map((e) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.value.toString(),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    if (widget.currentPhase.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(
                    0.5 + (_pulseController.value * 0.5),
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            widget.currentPhase,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return AppTheme.textTertiary;
      case StepStatus.running:
        return AppTheme.primary;
      case StepStatus.completed:
        return AppTheme.success;
      case StepStatus.failed:
        return AppTheme.error;
    }
  }

  String _getStatusLabel(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return 'PENDING';
      case StepStatus.running:
        return 'RUNNING';
      case StepStatus.completed:
        return 'DONE';
      case StepStatus.failed:
        return 'FAILED';
    }
  }

  IconData _getStepIcon(AIProcessStep step) {
    switch (step.status) {
      case StepStatus.completed:
        return Icons.check;
      case StepStatus.failed:
        return Icons.close;
      case StepStatus.pending:
        return Icons.circle_outlined;
      case StepStatus.running:
        return Icons.sync;
    }
  }

  Color _getTypeColor(StepType type) {
    switch (type) {
      case StepType.thinking:
        return Colors.purple;
      case StepType.tool:
        return Colors.blue;
      case StepType.reasoning:
        return Colors.orange;
      case StepType.result:
        return AppTheme.success;
      case StepType.error:
        return AppTheme.error;
    }
  }

  String _getTypeLabel(StepType type) {
    switch (type) {
      case StepType.thinking:
        return 'THINK';
      case StepType.tool:
        return 'TOOL';
      case StepType.reasoning:
        return 'REASON';
      case StepType.result:
        return 'RESULT';
      case StepType.error:
        return 'ERROR';
    }
  }
}
