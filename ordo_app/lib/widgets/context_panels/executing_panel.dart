import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ExecutingPanel extends StatefulWidget {
  final String action;
  final List<String> tools;
  final double progress;
  final String? status;

  const ExecutingPanel({
    super.key,
    required this.action,
    required this.tools,
    this.progress = 0.8,
    this.status,
  });

  @override
  State<ExecutingPanel> createState() => _ExecutingPanelState();
}

class _ExecutingPanelState extends State<ExecutingPanel>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _spinController;
  late AnimationController _lineController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouncing Loading Line
          _buildLoadingLine(),

          const SizedBox(height: 24),

          // Main Execution Panel
          _buildExecutionPanel(context),

          const SizedBox(height: 16),

          // Execution Steps
          _buildExecutionSteps(context),
        ],
      ),
    );
  }

  Widget _buildLoadingLine() {
    return Container(
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(1),
      ),
      child: AnimatedBuilder(
        animation: _lineController,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment(
              -1 + (_lineController.value * 3) - 0.5,
              0,
            ),
            widthFactor: 0.3,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warning.withOpacity(0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExecutionPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glowing accent at top
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 100,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warning.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Header with spinning icon
          Row(
            children: [
              // Spinning settings icon with pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warning.withOpacity(
                            0.1 + (_pulseController.value * 0.2),
                          ),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: RotationTransition(
                      turns: _spinController,
                      child: const Icon(
                        Icons.settings,
                        color: AppTheme.warning,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // Title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Executing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TRANSACTION LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress percentage
              Text(
                '${(widget.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warning,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress bar
          _buildProgressBar(),

          const SizedBox(height: 16),

          // Status labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BROADCASTING',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.warning,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'FINALIZING',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.2),
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Route info
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Route Path',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
                Text(
                  widget.tools.isNotEmpty
                      ? 'Via ${widget.tools.join(" • ")}'
                      : 'Via Jupiter • Raydium',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tool tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolTag('[JUP_AG_V6]', true),
              _buildToolTag('[RAY_AMM_LP]', true),
              _buildToolTag('[ORDO_SAFE_V1]', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: constraints.maxWidth * widget.progress,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [AppTheme.warning, Color(0xFFFBBF24)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(
                              0.1 + (_pulseController.value * 0.1),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolTag(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.warning.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? AppTheme.warning.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? AppTheme.warning : AppTheme.textTertiary,
          letterSpacing: 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildExecutionSteps(BuildContext context) {
    final steps = [
      {'text': 'Route optimization found', 'status': 'done'},
      {'text': 'Transaction simulated', 'status': 'done'},
      {'text': 'Confirming on chain...', 'status': 'loading'},
      {'text': 'Transaction complete', 'status': 'pending'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: steps.map((step) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Status icon
                _buildStepIcon(step['status']!),
                const SizedBox(width: 16),
                // Text
                Text(
                  step['text']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: step['status'] == 'pending'
                        ? Colors.white.withOpacity(0.3)
                        : step['status'] == 'loading'
                            ? Colors.white
                            : Colors.white.withOpacity(0.8),
                    fontWeight: step['status'] == 'loading'
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepIcon(String status) {
    switch (status) {
      case 'done':
        return const Icon(
          Icons.check_circle,
          size: 18,
          color: AppTheme.warning,
        );
      case 'loading':
        return SizedBox(
          width: 18,
          height: 18,
          child: RotationTransition(
            turns: _spinController,
            child: const Icon(
              Icons.refresh,
              size: 18,
              color: AppTheme.warning,
            ),
          ),
        );
      default:
        return Icon(
          Icons.radio_button_unchecked,
          size: 18,
          color: Colors.white.withOpacity(0.2),
        );
    }
  }
}
