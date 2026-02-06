import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class SecuritySettingsPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const SecuritySettingsPanel({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<SecuritySettingsPanel> createState() => _SecuritySettingsPanelState();
}

class _SecuritySettingsPanelState extends State<SecuritySettingsPanel> {
  // Settings state
  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Transaction limits
  double _dailyLimit = 100.0;
  double _singleTxLimit = 50.0;
  double _slippageTolerance = 1.0;
  
  // Security toggles
  bool _requireApprovalAboveLimit = true;
  bool _autoApproveSmallTx = false;
  bool _enableNotifications = true;
  bool _showRiskWarnings = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.getPreferences();
      
      if (response['success'] == true && response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data']);
        
        setState(() {
          _preferences = data;
          
          // Parse limits
          _dailyLimit = (data['dailyLimit'] as num?)?.toDouble() ?? 100.0;
          _singleTxLimit = (data['singleTransactionLimit'] as num?)?.toDouble() ?? 
                          (data['txLimit'] as num?)?.toDouble() ?? 50.0;
          _slippageTolerance = (data['slippageTolerance'] as num?)?.toDouble() ?? 
                              (data['defaultSlippage'] as num?)?.toDouble() ?? 1.0;
          
          // Parse toggles
          _requireApprovalAboveLimit = data['requireApprovalAboveLimit'] ?? 
                                       data['approvalRequired'] ?? true;
          _autoApproveSmallTx = data['autoApproveSmallTransactions'] ?? 
                               data['autoApprove'] ?? false;
          _enableNotifications = data['enableNotifications'] ?? 
                                data['notifications'] ?? true;
          _showRiskWarnings = data['showRiskWarnings'] ?? 
                             data['riskWarnings'] ?? true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final newPrefs = {
        'dailyLimit': _dailyLimit,
        'singleTransactionLimit': _singleTxLimit,
        'slippageTolerance': _slippageTolerance,
        'requireApprovalAboveLimit': _requireApprovalAboveLimit,
        'autoApproveSmallTransactions': _autoApproveSmallTx,
        'enableNotifications': _enableNotifications,
        'showRiskWarnings': _showRiskWarnings,
      };
      
      final response = await apiClient.updatePreferences(newPrefs);
      
      if (response['success'] == true) {
        setState(() {
          _successMessage = 'Settings saved successfully!';
        });
        
        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        throw Exception(response['error'] ?? 'Failed to save settings');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetPreferences() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text('Reset Settings', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to reset all security settings to defaults?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final apiClient = ApiClient(authService: authService);
      
      final response = await apiClient.resetPreferences();
      
      if (response['success'] == true) {
        // Reload preferences
        await _loadPreferences();
        
        setState(() {
          _successMessage = 'Settings reset to defaults!';
        });
      } else {
        throw Exception(response['error'] ?? 'Failed to reset settings');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
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

          // Messages
          if (_errorMessage != null)
            _buildMessageBanner(_errorMessage!, isError: true),
          if (_successMessage != null)
            _buildMessageBanner(_successMessage!, isError: false),

          // Content
          _buildContent(),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.security,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Security & Limits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _isLoading ? null : _loadPreferences,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner(String message, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? Colors.red : Colors.green).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 450),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Limits Section
            _buildSectionHeader('Transaction Limits', Icons.account_balance_wallet),
            const SizedBox(height: 12),
            
            _buildSliderSetting(
              label: 'Daily Limit',
              value: _dailyLimit,
              min: 10,
              max: 1000,
              unit: 'SOL',
              color: Colors.blue,
              onChanged: (value) => setState(() => _dailyLimit = value),
            ),
            const SizedBox(height: 16),
            
            _buildSliderSetting(
              label: 'Single Transaction Limit',
              value: _singleTxLimit,
              min: 1,
              max: 500,
              unit: 'SOL',
              color: Colors.green,
              onChanged: (value) => setState(() => _singleTxLimit = value),
            ),
            const SizedBox(height: 16),
            
            _buildSliderSetting(
              label: 'Slippage Tolerance',
              value: _slippageTolerance,
              min: 0.1,
              max: 5.0,
              unit: '%',
              color: Colors.orange,
              onChanged: (value) => setState(() => _slippageTolerance = value),
              divisions: 49,
            ),
            
            const SizedBox(height: 24),
            
            // Security Settings Section
            _buildSectionHeader('Security Settings', Icons.shield),
            const SizedBox(height: 12),
            
            _buildToggleSetting(
              label: 'Require Approval Above Limit',
              description: 'Require manual approval for transactions exceeding your limits',
              value: _requireApprovalAboveLimit,
              onChanged: (value) => setState(() => _requireApprovalAboveLimit = value),
            ),
            
            _buildToggleSetting(
              label: 'Auto-Approve Small Transactions',
              description: 'Automatically approve transactions under 1 SOL',
              value: _autoApproveSmallTx,
              onChanged: (value) => setState(() => _autoApproveSmallTx = value),
            ),
            
            _buildToggleSetting(
              label: 'Show Risk Warnings',
              description: 'Display warnings for risky tokens and transactions',
              value: _showRiskWarnings,
              onChanged: (value) => setState(() => _showRiskWarnings = value),
            ),
            
            _buildToggleSetting(
              label: 'Enable Notifications',
              description: 'Receive notifications for important events',
              value: _enableNotifications,
              onChanged: (value) => setState(() => _enableNotifications = value),
            ),
            
            const SizedBox(height: 24),
            
            // Reset button
            Center(
              child: TextButton.icon(
                onPressed: _isSaving ? null : _resetPreferences,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset to Defaults'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  unit == '%' 
                      ? '${value.toStringAsFixed(1)}$unit'
                      : '${value.toStringAsFixed(0)} $unit',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions ?? (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unit == '%' ? '${min.toStringAsFixed(1)}$unit' : '${min.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                unit == '%' ? '${max.toStringAsFixed(1)}$unit' : '${max.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.amber,
            activeTrackColor: Colors.amber.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onDismiss,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.amber.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Save Settings',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
