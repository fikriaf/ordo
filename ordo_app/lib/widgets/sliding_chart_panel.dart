import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/binance_api.dart';
import '../services/token_logo_service.dart';

enum ChartType { line, candlestick }

class SlidingChartPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const SlidingChartPanel({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<SlidingChartPanel> createState() => _SlidingChartPanelState();
}

class _SlidingChartPanelState extends State<SlidingChartPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final GlobalKey _chartKey = GlobalKey();

  String _selectedToken = 'SOL';
  String _selectedInterval = '1h';
  ChartType _chartType = ChartType.candlestick;
  List<CandleData> _chartData = [];
  PriceStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedCandleIndex;

  final List<String> _tokens = [
    'SOL',
    'BTC',
    'ETH',
    'BONK',
    'JUP',
    'JTO',
    'WIF',
    'PYTH'
  ];
  final List<String> _timeframes = ['1H', '4H', '1D', '1W', '1M'];
  final List<String> _intervals = ['1h', '4h', '1d', '1w', '1M'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start off-screen to the right
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _loadChartData();
  }

  @override
  void didUpdateWidget(SlidingChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _binanceSymbol => '${_selectedToken}USDT';

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await BinanceApiService.get24hrStats(_binanceSymbol);
      final klineData = await BinanceApiService.getKlineData(
        _binanceSymbol,
        _selectedInterval,
        50,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _chartData = klineData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _onTimeframeChanged(int index) {
    setState(() {
      _selectedInterval = _intervals[index];
    });
    _loadChartData();
  }

  void _onTokenChanged(String token) {
    setState(() {
      _selectedToken = token;
    });
    _loadChartData();
  }

  void _toggleChartType() {
    setState(() {
      _chartType = _chartType == ChartType.line
          ? ChartType.candlestick
          : ChartType.line;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.85;
    
    return Stack(
      children: [
        // Panel content - slides in/out
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: panelWidth,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.98),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildTokenSelector(),
                    _buildPriceHeader(),
                    _buildTimeframeSelector(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              ),
                            )
                          : _errorMessage != null
                              ? _buildError()
                              : _buildChart(),
                    ),
                    _buildStats(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Toggle button - moves with panel animation
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Calculate button position based on animation
            // When closed (0.0): button at right edge (0)
            // When open (1.0): button at left edge of panel (panelWidth)
            final buttonOffset = panelWidth * _animationController.value;
            
            return Positioned(
              right: buttonOffset,
              top: MediaQuery.of(context).size.height * 0.45,
              child: GestureDetector(
                onTap: widget.onToggle,
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
                      turns: widget.isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Token logo
          TokenLogoService.buildTokenLogo(symbol: _selectedToken, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Price Chart',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Chart type toggle
          IconButton(
            icon: Icon(
              _chartType == ChartType.candlestick
                  ? Icons.candlestick_chart
                  : Icons.show_chart,
              color: AppTheme.primary,
              size: 20,
            ),
            onPressed: _toggleChartType,
            tooltip: _chartType == ChartType.candlestick
                ? 'Switch to Line Chart'
                : 'Switch to Candlestick',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            onPressed: _loadChartData,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tokens.length,
        itemBuilder: (context, index) {
          final token = _tokens[index];
          final isSelected = token == _selectedToken;
          return GestureDetector(
            onTap: () => _onTokenChanged(token),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TokenLogoService.buildTokenLogo(symbol: token, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    token,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceHeader() {
    final priceChange = _stats?.priceChangePercent ?? 0;
    final isPositive = priceChange >= 0;
    final lastPrice = _stats?.lastPrice ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$_selectedToken/USDT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Colors.green,
                      size: 4,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Price and change in column for narrow panel
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lastPrice > 0
                    ? '\$${lastPrice.toStringAsFixed(lastPrice >= 1 ? 2 : 6)}'
                    : '...',
                style: const TextStyle(
                  fontFamily: 'Tomorrow',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 16,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    Text(
                      '${isPositive ? "+" : ""}${priceChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontFamily: 'Tomorrow',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: _timeframes.asMap().entries.map((entry) {
            final index = entry.key;
            final timeframe = entry.value;
            final isSelected = _selectedInterval == _intervals[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => _onTimeframeChanged(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    timeframe,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.withValues(alpha: 0.7), size: 48),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load data',
            style: TextStyle(
                color: Colors.red.withValues(alpha: 0.7), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadChartData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _chartType == ChartType.line
          ? _buildLineChart()
          : _buildCandlestickChart(),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _chartData.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.close,
              );
            }).toList(),
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.25),
                  AppTheme.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppTheme.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _chartData.length) {
                  final candleData = _chartData[index];
                  final price = candleData.close;
                  return LineTooltipItem(
                    '\$${price.toStringAsFixed(price >= 1 ? 2 : 6)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCandlestickChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();

    final minPrice = _chartData.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = _chartData.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    return GestureDetector(
      onTapDown: (details) {
        _showCandleTooltip(details.localPosition);
      },
      onPanUpdate: (details) {
        _showCandleTooltip(details.localPosition);
      },
      onPanEnd: (_) {
        setState(() {
          _selectedCandleIndex = null;
        });
      },
      child: Stack(
        children: [
          Container(
            key: _chartKey,
            child: CustomPaint(
              painter: CandlestickChartPainter(
                candles: _chartData,
                minPrice: minPrice - padding,
                maxPrice: maxPrice + padding,
                selectedIndex: _selectedCandleIndex,
              ),
              child: Container(),
            ),
          ),
          if (_selectedCandleIndex != null && _selectedCandleIndex! < _chartData.length)
            _buildCandleTooltip(_chartData[_selectedCandleIndex!]),
        ],
      ),
    );
  }

  void _showCandleTooltip(Offset position) {
    final RenderBox? renderBox = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Get actual chart size
    final chartWidth = renderBox.size.width;
    
    // Calculate which candle was tapped based on x position
    final candleWidth = chartWidth / _chartData.length;
    final index = (position.dx / candleWidth).floor().clamp(0, _chartData.length - 1);

    if (_selectedCandleIndex != index) {
      setState(() {
        _selectedCandleIndex = index;
      });
    }
  }

  Widget _buildCandleTooltip(CandleData candle) {
    final isGreen = candle.close >= candle.open;
    
    return Positioned(
      top: 10,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isGreen ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedToken,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTooltipRow('O', candle.open, Colors.white.withValues(alpha: 0.7)),
            _buildTooltipRow('H', candle.high, Colors.green),
            _buildTooltipRow('L', candle.low, Colors.red),
            _buildTooltipRow('C', candle.close, isGreen ? Colors.green : Colors.red),
            const Divider(height: 12, color: Colors.white24),
            _buildTooltipRow('Vol', candle.volume, Colors.blue, isVolume: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipRow(String label, double value, Color color, {bool isVolume = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isVolume ? _formatVolume(value) : '\$${_formatPrice(value)}',
            style: TextStyle(
              fontFamily: 'Tomorrow',
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final highPrice = _stats?.highPrice ?? 0;
    final lowPrice = _stats?.lowPrice ?? 0;
    final volume = _stats?.volume ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatColumn(
                Icons.arrow_upward,
                '24H High',
                '\$${_formatPrice(highPrice)}',
                Colors.green,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Expanded(
              child: _buildStatColumn(
                Icons.arrow_downward,
                '24H Low',
                '\$${_formatPrice(lowPrice)}',
                Colors.red,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Expanded(
              child: _buildStatColumn(
                Icons.bar_chart,
                'Volume',
                _formatVolume(volume),
                Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 14,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 0.3,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Tomorrow',
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return '...';
    if (price >= 1000) {
      return price.toStringAsFixed(2);
    } else if (price >= 1) {
      return price.toStringAsFixed(4);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }
}

// Custom painter for candlestick chart
class CandlestickChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double minPrice;
  final double maxPrice;
  final int? selectedIndex;

  CandlestickChartPainter({
    required this.candles,
    required this.minPrice,
    required this.maxPrice,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final priceRange = maxPrice - minPrice;
    final candleWidth = size.width / candles.length;
    final bodyWidth = candleWidth * 0.7;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * candleWidth + candleWidth / 2;

      final isGreen = candle.close >= candle.open;
      final isSelected = i == selectedIndex;
      final color = isGreen ? Colors.green : Colors.red;

      // Calculate Y positions
      final highY = size.height - ((candle.high - minPrice) / priceRange * size.height);
      final lowY = size.height - ((candle.low - minPrice) / priceRange * size.height);
      final openY = size.height - ((candle.open - minPrice) / priceRange * size.height);
      final closeY = size.height - ((candle.close - minPrice) / priceRange * size.height);

      // Draw selection highlight
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(
            i * candleWidth,
            0,
            candleWidth,
            size.height,
          ),
          highlightPaint,
        );
      }

      // Draw wick (high-low line)
      final wickPaint = Paint()
        ..color = isSelected 
            ? color 
            : color.withValues(alpha: 0.5)
        ..strokeWidth = isSelected ? 2 : 1;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // Draw body (open-close rectangle)
      final bodyPaint = Paint()
        ..color = isSelected 
            ? color 
            : color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final bodyTop = isGreen ? closeY : openY;
      final bodyBottom = isGreen ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRect(
        Rect.fromLTWH(
          x - bodyWidth / 2,
          bodyTop,
          bodyWidth,
          bodyHeight,
        ),
        bodyPaint,
      );

      // Draw border for selected candle
      if (isSelected) {
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(
          Rect.fromLTWH(
            x - bodyWidth / 2,
            bodyTop,
            bodyWidth,
            bodyHeight,
          ),
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CandlestickChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.candles != candles;
  }
}
