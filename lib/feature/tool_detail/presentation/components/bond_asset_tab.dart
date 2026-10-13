import 'package:flutter/material.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

class BondAssetTab extends StatelessWidget {
  final ToolDetailDisplay tool;

  const BondAssetTab({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bond Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Bond summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color: Colors.grey[600],
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
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Bond',
                          style: TextStyle(
                            color: Colors.orange[700],
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
                    'Face Value: \$${tool.faceValue?.toStringAsFixed(2) ?? "100.00"}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (tool.interestRate != null)
                    Text(
                      'Coupon: ${(tool.interestRate! * 100).toStringAsFixed(2)}%',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Bond details
          Text(
            'Bond Details',
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
                  _buildDetailRow('Maturity Date', _getMaturityDate(), context),
                  _buildDetailRow('Coupon Rate', '${(tool.interestRate! * 100).toStringAsFixed(2)}%', context),
                  _buildDetailRow('Payment Frequency', 'Semi-annual', context),
                  _buildDetailRow('Credit Rating', 'AA+', context),
                  _buildDetailRow('Issuer', 'Government', context),
                  _buildDetailRow('Yield to Maturity', '3.2%', context),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Price chart
          Text(
            'Price History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: CustomPaint(
                      painter: _BondChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPeriodButton('1M', true, context),
                      _buildPeriodButton('3M', false, context),
                      _buildPeriodButton('6M', false, context),
                      _buildPeriodButton('1Y', false, context),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Cash flow timeline
          Text(
            'Cash Flow',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCashFlowItem(
                    date: 'Jun 2024',
                    amount: '\$${tool.faceValue! * tool.interestRate! / 2}',
                    type: 'Coupon Payment',
                  ),
                  const SizedBox(height: 12),
                  _buildCashFlowItem(
                    date: 'Dec 2024',
                    amount: '\$${tool.faceValue! * tool.interestRate! / 2}',
                    type: 'Coupon Payment',
                  ),
                  const SizedBox(height: 12),
                  _buildCashFlowItem(
                    date: 'Jun 2025',
                    amount: '\$${tool.faceValue! + tool.faceValue! * tool.interestRate! / 2}',
                    type: 'Coupon + Principal',
                    isFinal: true,
                  ),
                ],
              ),
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
                  onPressed: () => _showSellDialog(context),
                  icon: const Icon(Icons.sell),
                  label: const Text('Sell Bond'),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMaturityDate() {
    // Mock date - in real app this would come from the model
    return 'Jun 15, 2025';
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowItem({
    required String date,
    required String amount,
    required String type,
    bool isFinal = false,
  }) {
    return Row(
      children: [
        Container(
          width: 80,
          child: Text(
            date,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            type,
            style: TextStyle(
              fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFinal ? Colors.green : Colors.grey[700],
          ),
        ),
      ],
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
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showSellDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell Bond'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Market Value: \$${tool.currentValue.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Face Value to Sell',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Sell'),
          ),
        ],
      ),
    );
  }
}

class _BondChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.orange;

    final path = Path();
    const points = 40;
    final stepX = size.width / (points - 1);

    // Draw a more stable bond price line
    for (int i = 0; i < points; i++) {
      final x = i * stepX;
      // Bond prices are typically more stable
      final volatility = (i % 10) / 10.0;
      final baseY = size.height * 0.4;
      final y = baseY + (i % 5 - 2) * volatility * 15.0;
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
      ..color = Colors.orange.withValues(alpha: 0.1);
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}