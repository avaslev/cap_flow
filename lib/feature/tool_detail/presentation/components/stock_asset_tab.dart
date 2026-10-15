import 'package:flutter/material.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/tool_detail/presentation/components/investment_form_sheet.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

class StockAssetTab extends StatelessWidget {
  final ToolDetailDisplay tool;

  const StockAssetTab({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),


          // Actions
          Text(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showInvestmentFormSheet(
                    context,
                    accountId: tool.accountId,
                    toolId: tool.id,
                    investmentType: ToolType.stocks,
                    operationType: InvestmentOperationType.buy,
                    presetTicker: tool.ticker,
                    presetName: tool.name,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Buy'),
                  // Покупка — primary из темы.
                // style из темы
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showInvestmentFormSheet(
                    context,
                    accountId: tool.accountId,
                    toolId: tool.id,
                    investmentType: ToolType.stocks,
                    operationType: InvestmentOperationType.sell,
                    presetTicker: tool.ticker,
                    presetName: tool.name,
                  ),
                  icon: const Icon(Icons.remove),
                  label: const Text('Sell'),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                ),
              ),
            ],
          ),


          // Stock header with price change
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tool.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tool.ticker != null)
                              Text(
                                tool.ticker!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ((tool.percentageChange >= 0 ? Colors.green : Colors.red))
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(tool.percentageChange >= 0 ? '+' : '')}${tool.percentageChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: tool.percentageChange >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '\$${tool.currentValue.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tool.quantity.toStringAsFixed(2)} shares',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Позиция: реальные данные из портфеля.
          Text(
            'Позиция',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Количество',
                  _formatCryptoQuantity(tool.quantity),
                  context,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Цена за единицу',
                  tool.quantity.abs() > 0
                      ? formatCurrency(
                          tool.currentValue / tool.quantity.abs(),
                        )
                      : '—',
                  context,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildStatCard(
            'Стоимость позиции',
            formatCurrency(tool.currentValue),
            context,
          ),

          const SizedBox(height: 24),

          // Holdings chart mock
          Text(
            'Holdings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 200,
                    child: CustomPaint(
                      painter: _ChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPeriodButton('1D', true, context),
                      _buildPeriodButton('1W', false, context),
                      _buildPeriodButton('1M', false, context),
                      _buildPeriodButton('3M', false, context),
                      _buildPeriodButton('1Y', false, context),
                    ],
                  ),
                ],
              ),
            ),
          ),

          ],
        ),
      ),
    );
  }

  /// Количество с точностью до 10 знаков, хвостовые нули обрезаются.
  String _formatCryptoQuantity(double v) {
    String s = v.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  Widget _buildStatCard(String label, String value, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period, bool isActive, BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isActive
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }


}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.green;

    final path = Path();
    const points = 50;
    final stepX = size.width / (points - 1);

    for (int i = 0; i < points; i++) {
      final x = i * stepX;
      final y = size.height / 2 + (i % 10 - 5) * 10.0;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw fill area
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.withValues(alpha: 0.1);
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}