import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_event.dart';
import 'package:investflow/feature/tool_detail/tool_detail_state.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';
import 'package:investflow/feature/tool_detail/presentation/components/money_asset_tab.dart';
import 'package:investflow/feature/tool_detail/presentation/components/stock_asset_tab.dart';
import 'package:investflow/feature/tool_detail/presentation/components/bond_asset_tab.dart';

/// Screen displaying detailed information about a financial tool.
/// Uses a BLoC to load the tool data and displays tabs based on asset type.
class ToolDetailScreen extends StatelessWidget {
  final String accountId;
  final String toolId;

  const ToolDetailScreen({
    super.key,
    required this.accountId,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ToolDetailBloc>(
      create: (_) => ToolDetailBloc()..add(LoadToolDetail(accountId, toolId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Asset Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
        ),
        body: BlocBuilder<ToolDetailBloc, ToolDetailState>(
          builder: (context, state) {
            if (state is ToolDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ToolDetailError) {
              return Center(
                child: Text('Error loading tool: ${state.message}'),
              );
            }
            if (state is ToolDetailLoaded) {
              final tool = state.tool;
              return _buildAssetDetail(tool, context);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildAssetDetail(ToolDetailDisplay tool, BuildContext context) {
    // Get list of tabs based on tool type
    final tabs = _getTabsForToolType(tool);

    return Column(
      children: [
        // Asset header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tool.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (tool.ticker != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tool.ticker!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(tool.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatType(tool.type),
                      style: TextStyle(
                        color: _getTypeColor(tool.type),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Value section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '\$${tool.currentValue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              if (tool.percentageChange != 0)
                Text(
                  '${tool.percentageChange >= 0 ? '+' : ''}${tool.percentageChange.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: tool.percentageChange >= 0 ? Colors.green : Colors.red,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),

        // Tab bar or direct content for money
        tool.type == 'MONEY'
            ? Expanded(
                child: _buildPerformanceTab(tool, context),
              )
            : DefaultTabController(
                length: tabs.length,
                child: Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        tabs: tabs,
                        isScrollable: true,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: tabs.map((tab) {
                            switch (tab.text) {
                              case 'Overview':
                                return _buildOverviewTab(tool, context);
                              case 'Performance':
                                return _buildPerformanceTab(tool, context);
                              case 'Transactions':
                                return _buildTransactionsTab(tool, context);
                              case 'Details':
                                return _buildDetailsTab(tool, context);
                              default:
                                return const Center(child: Text('Tab not implemented'));
                            }
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  List<Tab> _getTabsForToolType(ToolDetailDisplay tool) {
    switch (tool.type) {
      case 'MONEY':
        return [
          const Tab(text: 'Performance'),
        ];
      case 'STOCK':
      case 'STOCKS':
        return [
          const Tab(text: 'Overview'),
          const Tab(text: 'Performance'),
          const Tab(text: 'Transactions'),
        ];
      case 'BOND':
      case 'BONDS':
        return [
          const Tab(text: 'Overview'),
          const Tab(text: 'Details'),
          const Tab(text: 'Performance'),
        ];
      default:
        return [const Tab(text: 'Overview')];
    }
  }

  Widget _buildOverviewTab(ToolDetailDisplay tool, BuildContext context) {
    if (tool.type == 'MONEY') {
      return MoneyAssetTab(tool: tool);
    } else if (tool.type == 'STOCK' || tool.type == 'STOCKS') {
      return StockAssetTab(tool: tool);
    } else if (tool.type == 'BOND' || tool.type == 'BONDS') {
      return BondAssetTab(tool: tool);
    }
    return _buildGenericOverview(tool, context);
  }

  Widget _buildGenericOverview(ToolDetailDisplay tool, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asset Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Type', _formatType(tool.type), context),
          _buildInfoRow('Quantity', tool.quantity.toStringAsFixed(2), context),
          _buildInfoRow('Current Value', '\$${tool.currentValue.toStringAsFixed(2)}', context),
          if (tool.faceValue != null)
            _buildInfoRow('Face Value', '\$${tool.faceValue!.toStringAsFixed(2)}', context),
          if (tool.interestRate != null)
            _buildInfoRow('Interest Rate', '${tool.interestRate!.toStringAsFixed(2)}%', context),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(ToolDetailDisplay tool, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Performance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildPerformanceCard('1D', tool.percentageChange, context),
                _buildPerformanceCard('1W', tool.percentageChange * 1.1, context),
                _buildPerformanceCard('1M', tool.percentageChange * 1.3, context),
                _buildPerformanceCard('3M', tool.percentageChange * 1.5, context),
                _buildPerformanceCard('1Y', tool.percentageChange * 2.0, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(ToolDetailDisplay tool, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTransactionItem('Buy', 100, '10 shares', context),
                _buildTransactionItem('Sell', 50, '5 shares', context),
                _buildTransactionItem('Dividend', 25, 'Dividend payment', context),
                _buildTransactionItem('Buy', 150, '15 shares', context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(ToolDetailDisplay tool, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (tool.faceValue != null)
            _buildInfoRow('Face Value', '\$${tool.faceValue!.toStringAsFixed(2)}', context),
          if (tool.interestRate != null)
            _buildInfoRow('Coupon Rate', '${tool.interestRate!.toStringAsFixed(2)}%', context),
          if (tool.paymentDayOfMonth != null)
            _buildInfoRow('Payment Day', 'Day ${tool.paymentDayOfMonth}', context),
          if (tool.startDate != null)
            _buildInfoRow('Start Date', '${tool.startDate!.toLocal()}'.split(' ')[0], context),
          if (tool.endDate != null)
            _buildInfoRow('Maturity Date', '${tool.endDate!.toLocal()}'.split(' ')[0], context),
          _buildInfoRow('Account ID', tool.accountId, context),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Widget _buildTransactionItem(String type, double amount, String description, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: type == 'Buy' ? Colors.red : type == 'Sell' ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'MONEY':
        return 'Cash';
      case 'STOCK':
      case 'STOCKS':
        return 'Stock';
      case 'BOND':
      case 'BONDS':
        return 'Bond';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'MONEY':
        return Colors.blue;
      case 'STOCK':
      case 'STOCKS':
        return Colors.green;
      case 'BOND':
      case 'BONDS':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}