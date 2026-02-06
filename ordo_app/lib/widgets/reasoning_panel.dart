import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReasoningStep {
  final String description;
  final String status; // 'completed', 'processing', 'pending'
  final Map<String, dynamic>? data;

  ReasoningStep({
    required this.description,
    required this.status,
    this.data,
  });
}

class ReasoningPanel extends StatefulWidget {
  final String command;
  final List<ReasoningStep> steps;
  final Map<String, dynamic>? metadata;
  final VoidCallback? onDismiss;

  const ReasoningPanel({
    super.key,
    required this.command,
    required this.steps,
    this.metadata,
    this.onDismiss,
  });

  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Command Bar
          _buildCommandBar(),

          // Reasoning Steps
          _buildSteps(),

          // Metadata (if any)
          if (widget.metadata != null) _buildMetadata(),

          // Footer hint
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.memory,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[CPU] THINKING',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ordo LMM-1 Engine Active',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDismiss != null)
            IconButton(
              onPressed: widget.onDismiss,
              icon: Icon(
                Icons.more_horiz,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.command,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Animated progress line
          _buildProgressLine(),
        ],
      ),
    );
  }

  Widget _buildProgressLine() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    left: constraints.maxWidth * _animationController.value -
                        constraints.maxWidth * 0.3,
                    child: Container(
                      width: constraints.maxWidth * 0.3,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.primary,
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Reasoning Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < widget.steps.length; i++)
                  _buildStepItem(widget.steps[i], i == widget.steps.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(ReasoningStep step, bool isLast) {
    final isCompleted = step.status == 'completed';
    final isProcessing = step.status == 'processing';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tree connector
        Text(
          isLast ? '└─' : '├─',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.description,
                style: TextStyle(
                  color: isProcessing ? Colors.white : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: isProcessing ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
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
                    const SizedBox(width: 6),
                    Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ] else if (isProcessing) ...[
                    _buildProcessingDots(),
                    const SizedBox(width: 6),
                    Text(
                      'PROCESSING...',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PENDING',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isLast ? 0 : 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingDots() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = _animationController.value;
        return Row(
          children: [
            _buildDot(value > 0.0 && value < 0.33 ? 1.0 : 0.3),
            const SizedBox(width: 2),
            _buildDot(value >= 0.33 && value < 0.66 ? 1.0 : 0.3),
            const SizedBox(width: 2),
            _buildDot(value >= 0.66 ? 1.0 : 0.3),
          ],
        );
      },
    );
  }

  Widget _buildDot(double opacity) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMetadata() {
    final metadata = widget.metadata!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            if (metadata['slippage'] != null)
              Expanded(
                child: _buildMetadataItem(
                  'Slippage',
                  '${metadata['slippage']}%',
                ),
              ),
            if (metadata['routesFound'] != null)
              Expanded(
                child: _buildMetadataItem(
                  'Routes Found',
                  metadata['routesFound'].toString(),
                ),
              ),
            if (metadata['priceImpact'] != null)
              Expanded(
                child: _buildMetadataItem(
                  'Price Impact',
                  '${metadata['priceImpact']}%',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
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
              color: AppTheme.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Ordo is cross-referencing multiple sources to ensure optimal execution.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 11,
        ),
      ),
    );
  }
}
