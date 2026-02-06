import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ApprovalHistoryPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;
  final Function(String action, Map<String, dynamic> params)? onAction;

  const ApprovalHistoryPanel({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onAction,
  });

  @override
  State<ApprovalHistoryPanel> createState() => _ApprovalHistoryPanelState();
}

class _ApprovalHistoryPanelState extends State<ApprovalHistoryPanel> {
  String _selectedFilter = 'all';
  bool _isLoading = false;
  List<Map<String, dynamic>> _approvals = [];

  final List<Map<String, String>> _filters = [
    {'id': 'all', 'label': 'All'},
    {'id': 'approved', 'label': 'Approved'},
    {'id': 'rejected', 'label': 'Rejected'},
    {'id': 'expired', 'label': 'Expired'},
  ];

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  void _loadApprovals() {
    final approvals = widget.data['approvals'] as List?;
    if (approvals != null) {
      _approvals = approvals.map((a) => Map<String, dynamic>.from(a)).toList();
    } else {
      // Demo data
      _approvals = [
        {
          'id': 'apr_1',
          'requestType': 'large_transfer',
          'status': 'approved',
          'estimatedUsdValue': 1575.0,
          'pendingTransaction': {
            'action': 'transfer_sol',
            'amount': 10.5,
            'toAddress': 'ABC...XYZ',
          },
          'agentReasoning': 'Transfer amount (\$1,575) exceeds your approval threshold',
          'approvedAt': '2026-02-04T10:05:00Z',
          'createdAt': '2026-02-04T10:00:00Z',
        },
        {
          'id': 'apr_2',
          'requestType': 'high_risk_token',
          'status': 'rejected',
          'estimatedUsdValue': 750.0,
          'pendingTransaction': {
            'action': 'swap_tokens',
            'inputMint': 'SOL',
            'outputMint': 'RISKY',
            'amount': 5.0,
          },
          'agentReasoning': 'Token has high risk score (85/100)',
          'rejectionReason': 'Risk too high',
          'rejectedAt': '2026-02-04T09:50:00Z',
          'createdAt': '2026-02-04T09:45:00Z',
        },
        {
          'id': 'apr_3',
          'requestType': 'large_transfer',
          'status': 'expired',
          'estimatedUsdValue': 500.0,
          'pendingTransaction': {
            'action': 'transfer_sol',
            'amount': 3.3,
            'toAddress': 'DEF...UVW',
          },
          'agentReasoning': 'Transfer requires manual approval',
          'expiredAt': '2026-02-03T15:15:00Z',
          'createdAt': '2026-02-03T15:00:00Z',
        },
      ];
    }
  }

  List<Map<String, dynamic>> get _filteredApprovals {
    if (_selectedFilter == 'all') return _approvals;
    return _approvals.where((a) => a['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Filter Chips
          _buildFilters(),

          // Stats Summary
          _buildStats(),

          // List
          Flexible(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                    ),
                  )
                : _filteredApprovals.isEmpty
                    ? _buildEmptyState()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[SECURITY]',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Approval History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshHistory,
            icon: Icon(
              Icons.refresh,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter['id']!;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                filter['label']!,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStats() {
    final approved = _approvals.where((a) => a['status'] == 'approved').length;
    final rejected = _approvals.where((a) => a['status'] == 'rejected').length;
    final expired = _approvals.where((a) => a['status'] == 'expired').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.15),
            AppTheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Approved',
              approved.toString(),
              AppTheme.success,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: _buildStatItem(
              'Rejected',
              rejected.toString(),
              AppTheme.error,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: _buildStatItem(
              'Expired',
              expired.toString(),
              AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Approvals Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your approval history will appear here',
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

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shrinkWrap: true,
      itemCount: _filteredApprovals.length,
      itemBuilder: (context, index) {
        final approval = _filteredApprovals[index];
        return _buildApprovalCard(approval);
      },
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> approval) {
    final status = approval['status'] as String;
    final requestType = approval['requestType'] as String;
    final usdValue = approval['estimatedUsdValue'] as double? ?? 0.0;
    final transaction = approval['pendingTransaction'] as Map<String, dynamic>?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        break;
      case 'expired':
        statusColor = AppTheme.warning;
        statusIcon = Icons.timer_off;
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.pending;
    }

    String typeLabel;
    IconData typeIcon;
    switch (requestType) {
      case 'large_transfer':
        typeLabel = 'Large Transfer';
        typeIcon = Icons.send;
        break;
      case 'high_risk_token':
        typeLabel = 'High Risk Token';
        typeIcon = Icons.warning_amber;
        break;
      case 'setting_change':
        typeLabel = 'Setting Change';
        typeIcon = Icons.settings;
        break;
      default:
        typeLabel = 'Transaction';
        typeIcon = Icons.swap_horiz;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    typeIcon,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${usdValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Transaction Details
            if (transaction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction['action'] != null)
                      _buildDetailRow(
                        'Action',
                        transaction['action'].toString().replaceAll('_', ' '),
                      ),
                    if (transaction['amount'] != null)
                      _buildDetailRow(
                        'Amount',
                        '${transaction['amount']} ${transaction['inputMint'] ?? 'SOL'}',
                      ),
                    if (transaction['toAddress'] != null)
                      _buildDetailRow('To', transaction['toAddress']),
                  ],
                ),
              ),
            ],

            // Reasoning
            if (approval['agentReasoning'] != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textTertiary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      approval['agentReasoning'],
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Rejection Reason
            if (approval['rejectionReason'] != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.block,
                    color: AppTheme.error.withOpacity(0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: ${approval['rejectionReason']}',
                      style: TextStyle(
                        color: AppTheme.error.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Timestamp
            const SizedBox(height: 12),
            Text(
              _formatDate(approval['createdAt']),
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateStr;
    }
  }

  void _refreshHistory() async {
    setState(() {
      _isLoading = true;
    });

    // Call API to refresh
    widget.onAction?.call('refreshApprovalHistory', {});

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
