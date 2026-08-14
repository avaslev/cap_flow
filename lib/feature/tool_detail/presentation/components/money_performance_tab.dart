import 'package:flutter/material.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

class MoneyPerformanceTab extends StatelessWidget {
  final ToolDetailDisplay tool;

  const MoneyPerformanceTab({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Performance metrics only
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                _buildPerformanceCard('Today', 0.0, context),
                _buildPerformanceCard('This Week', 0.5, context),
                _buildPerformanceCard('This Month', 2.0, context),
                _buildPerformanceCard('This Year', 5.0, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(String period, double change, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              period,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
              style: TextStyle(
                color: change >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}