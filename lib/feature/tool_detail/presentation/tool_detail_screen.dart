import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tools/tool_kind.dart';
import 'package:investflow/feature/tools/domain/credit_schedule.dart';
import 'package:investflow/feature/tools/domain/tool_valuation.dart';
import 'package:investflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_event.dart';
import 'package:investflow/feature/tool_detail/tool_detail_state.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_repository.dart';
import 'package:investflow/feature/tool_detail/presentation/components/money_overview_tab.dart';
import 'package:investflow/feature/tool_detail/presentation/components/money_performance_tab.dart';
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

        // Always use TabBar for consistency across all asset types
        DefaultTabController(
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
                        case 'Обзор':
                          return _buildOverviewTab(tool, context);
                        case 'Performance':
                          return _buildPerformanceTab(tool, context);
                        case 'Transactions':
                        case 'Операции':
                          return _buildTransactionsTab(tool, context);
                        case 'Details':
                        case 'Детали':
                          return _buildDetailsTab(tool, context);
                        case 'График платежей':
                          return _buildCreditScheduleTab(tool, context);
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

  Future<void> _confirmCloseDeposit(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Закрытие депозита'),
          content: Text(
            'Депозит «${tool.name}» будет закрыт, а вся сумма с процентами '
            'переведена в деньги счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Закрыть депозит'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final double payout =
          await ToolDetailRepository().closeDepositAndTransferToMoney(
        depositToolId: tool.id,
        depositName: tool.name,
        accountId: tool.accountId,
        principal: tool.currentValue,
        interestRate: tool.interestRate ?? 0,
        startDate: tool.startDate ?? DateTime.now(),
        endDate: tool.endDate,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Депозит закрыт: ${formatCurrency(payout)} зачислено в деньги счёта',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось закрыть депозит: $e')),
      );
    }
  }

  Future<void> _confirmCloseCredit(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Закрытие кредита'),
          content: Text(
            'Кредит «${tool.name}» будет закрыт: остаток долга '
            '${tool.currentValue.abs().toStringAsFixed(2)} ₽ будет списан с '
            'денежного тула счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Закрыть кредит'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final double paid =
          await ToolDetailRepository().closeCreditAndRemoveSchedule(
        creditToolId: tool.id,
        creditName: tool.name,
        accountId: tool.accountId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Кредит закрыт: погашено ${paid.toStringAsFixed(2)} ₽',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось закрыть кредит: $e')),
      );
    }
  }

  List<Tab> _getTabsForToolType(ToolDetailDisplay tool) {
    switch (tool.type) {
      case 'MONEY':
        return [
          const Tab(text: 'Обзор'),
          const Tab(text: 'Динамика'),
        ];
      case 'STOCK':
      case 'STOCKS':
        return [
          const Tab(text: 'Обзор'),
          const Tab(text: 'Динамика'),
          const Tab(text: 'Операции'),
        ];
      case 'BOND':
      case 'BONDS':
        return [
          const Tab(text: 'Обзор'),
          const Tab(text: 'Детали'),
          const Tab(text: 'Динамика'),
        ];
      case 'DEPOSIT':
        return [
          const Tab(text: 'Обзор'),
          const Tab(text: 'Операции'),
          const Tab(text: 'Детали'),
        ];
      case 'CREDIT':
        return [
          const Tab(text: 'Обзор'),
          const Tab(text: 'График платежей'),
          const Tab(text: 'Операции'),
        ];
      case 'OTHER':
        return [const Tab(text: 'Обзор'), const Tab(text: 'Операции')];
      default:
        return [const Tab(text: 'Обзор')];
    }
  }

  String _typeDisplayName(String type) {
    return switch (type.toUpperCase()) {
      'MONEY' => 'Деньги',
      'DEPOSIT' => 'Депозит',
      'CREDIT' => 'Кредит',
      'STOCK' || 'STOCKS' => 'Акции',
      'BOND' || 'BONDS' => 'Облигации',
      'CRYPTOCURRENCY' => 'Криптовалюта',
      'OTHER' => 'Прочее',
      _ => type,
    };
  }

  Widget _buildOverviewTab(ToolDetailDisplay tool, BuildContext context) {
    if (tool.type == 'MONEY') {
      return MoneyOverviewTab(tool: tool);
    } else if (tool.type == 'STOCK' || tool.type == 'STOCKS') {
      return StockAssetTab(tool: tool);
    } else if (tool.type == 'BOND' || tool.type == 'BONDS') {
      return BondAssetTab(tool: tool);
    } else if (tool.type == 'DEPOSIT') {
      return _buildDepositOverview(tool, context);
    } else if (tool.type == 'CREDIT') {
      return _buildCreditOverview(tool, context);
    } else if (tool.type == 'OTHER') {
      return _buildOtherOverview(tool, context);
    }
    return _buildGenericOverview(tool, context);
  }

  Future<void> _sellOtherTool(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Продажа актива'),
          content: Text(
            'Актив «${tool.name}» будет продан за '
            '${tool.currentValue.abs().toStringAsFixed(2)} ₽, деньги будут '
            'зачислены на money-тул счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Продать'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final double price =
          await ToolDetailRepository().sellOtherTool(
        toolId: tool.id,
        toolName: tool.name,
        accountId: tool.accountId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Актив продан: +${price.toStringAsFixed(2)} ₽ в деньги'),
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось продать актив: $e')),
      );
    }
  }

  Widget _buildOtherOverview(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextEditingController valueController = TextEditingController(
      text: tool.currentValue.toStringAsFixed(2),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Прочий актив',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Текущая стоимость',
            formatCurrency(tool.currentValue),
            context,
          ),
          const SizedBox(height: 24),
          Text(
            'Переоценка',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Новая стоимость (RUB)',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final double? newValue = double.tryParse(
                      valueController.text.replaceAll(',', '.'),
                    );
                    if (newValue == null || newValue <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Введите положительную стоимость'),
                        ),
                      );
                      return;
                    }
                    final double delta = await ToolDetailRepository()
                        .revalueOtherTool(toolId: tool.id, newValue: newValue);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            delta >= 0
                                ? 'Переоценка: +${delta.toStringAsFixed(2)} ₽'
                                : 'Переоценка: ${delta.toStringAsFixed(2)} ₽',
                          ),
                        ),
                      );
                      context.read<ToolDetailBloc>().add(
                        LoadToolDetail(tool.accountId, tool.id),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.update, size: 20),
                  label: Text(
                    'Переоценить',
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sellOtherTool(context, tool),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.sell_outlined, size: 20),
                  label: Text(
                    'Продать',
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepositOverview(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime start = tool.startDate ?? now;
    final DateTime? end = tool.endDate;
    final double accrued = depositValue(
      principal: tool.currentValue,
      annualRate: tool.interestRate ?? 0,
      startDate: start,
      endDate: end,
      asOf: now,
    );
    final double accruedOnly = accrued - tool.currentValue;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Депозит',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Текущая стоимость с процентами',
            formatCurrency(accrued),
            context,
          ),
          _buildInfoRow(
            'Накоплено процентов',
            formatCurrency(accruedOnly),
            context,
          ),
          _buildInfoRow(
            'Ставка',
            '${(tool.interestRate ?? 0).toStringAsFixed(2)}%',
            context,
          ),
          if (tool.startDate != null)
            _buildInfoRow(
              'Начало',
              DateFormat('dd.MM.yyyy').format(tool.startDate!),
              context,
            ),
          if (tool.endDate != null)
            _buildInfoRow(
              'Конец срока',
              DateFormat('dd.MM.yyyy').format(tool.endDate!),
              context,
            ),
          if (tool.payoutType != null)
            _buildInfoRow('Выплата процентов', _payoutTypeName(PayoutType.values.byName(tool.payoutType!)), context),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _confirmCloseDeposit(context, tool),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: Text(
              'Закрыть депозит',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditOverview(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double debt = tool.currentValue.abs();
    final CreditPaymentType? paymentType = tool.creditPaymentType == null
        ? null
        : CreditPaymentType.values.byName(tool.creditPaymentType!);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Кредит',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Текущий долг', formatCurrency(debt), context),
          _buildInfoRow(
            'Ставка',
            '${(tool.interestRate ?? 0).toStringAsFixed(2)}%',
            context,
          ),
          if (tool.loanStartDate != null)
            _buildInfoRow(
              'Начало кредита',
              DateFormat('dd.MM.yyyy').format(tool.loanStartDate!),
              context,
            ),
          if (tool.loanTermMonths != null)
            _buildInfoRow('Срок', '${tool.loanTermMonths} мес.', context),
          if (tool.paymentDayOfMonth != null)
            _buildInfoRow(
              'День платежа',
              '${tool.paymentDayOfMonth}',
              context,
            ),
          if (paymentType != null)
            _buildInfoRow(
              'Тип платежей',
              paymentType == CreditPaymentType.annuity
                  ? 'Аннуитетный'
                  : 'Дифференцированный',
              context,
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _confirmCloseCredit(context, tool),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: Text(
              'Погасить кредит',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _payoutTypeName(PayoutType type) {
    return switch (type) {
      PayoutType.atEndOfTerm => 'В конце срока',
      PayoutType.monthly => 'Ежемесячно',
      PayoutType.monthlyToWithdrawalAccount => 'Ежемесячно на счёт списания',
    };
  }

  Widget _buildCreditScheduleTab(
    ToolDetailDisplay tool,
    BuildContext context,
  ) {
    final CreditPaymentType paymentType =
        tool.creditPaymentType == null
            ? CreditPaymentType.annuity
            : CreditPaymentType.values.byName(tool.creditPaymentType!);
    final int term = tool.loanTermMonths ?? 0;
    final double debt = tool.currentValue.abs();
    final double rate = tool.interestRate ?? 0;
    final List<DataRow> rows = <DataRow>[
      for (int n = 1; n <= term; n++)
        DataRow(
          cells: <DataCell>[
            DataCell(Text('$n')),
            DataCell(
              Text(
                formatCurrency(
                  creditPaymentSplit(
                    paymentType: paymentType,
                    loanAmount: debt,
                    annualRate: rate,
                    termMonths: term,
                    paymentNumber: n,
                  ).payment,
                ),
              ),
            ),
            DataCell(
              Text(
                formatCurrency(
                  creditPaymentSplit(
                    paymentType: paymentType,
                    loanAmount: debt,
                    annualRate: rate,
                    termMonths: term,
                    paymentNumber: n,
                  ).interest,
                ),
              ),
            ),
            DataCell(
              Text(
                formatCurrency(
                  creditPaymentSplit(
                    paymentType: paymentType,
                    loanAmount: debt,
                    annualRate: rate,
                    termMonths: term,
                    paymentNumber: n,
                  ).principal,
                ),
              ),
            ),
          ],
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'График платежей',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('№')),
                DataColumn(label: Text('Платёж')),
                DataColumn(label: Text('Проценты')),
                DataColumn(label: Text('Тело')),
              ],
              rows: rows,
            ),
          ),
        ],
      ),
    );
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
    if (tool.type == 'MONEY') {
      return MoneyPerformanceTab(tool: tool);
    }
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Activity>>(
      future: ToolDetailRepository().getActivitiesForTool(tool.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Activity>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        final List<Activity> activities = snapshot.data ?? <Activity>[];
        if (activities.isEmpty) {
          return const Center(child: Text('Операций пока нет'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (BuildContext context, int index) {
            final Activity activity = activities[index];
            final bool isAdd = activity.type == ActivityType.add;
            final double value = activity.price * activity.quantity;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isAdd ? Icons.add_circle : Icons.remove_circle,
                color: isAdd ? colorScheme.primary : colorScheme.error,
              ),
              title: Text(
                activity.name ?? (isAdd ? 'Пополнение' : 'Списание'),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                DateFormat('dd.MM.yyyy').format(activity.createAt),
              ),
              trailing: Text(
                '${isAdd ? '+' : '-'}${formatCurrency(value)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isAdd ? colorScheme.primary : colorScheme.error,
                ),
              ),
            );
          },
        );
      },
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