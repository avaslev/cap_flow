import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/core/utils/formatCurrency.dart';

class ToolDetailScreen extends StatelessWidget {
  final String accountId;
  final String toolId;

  const ToolDetailScreen({
    super.key,
    required this.accountId,
    required this.toolId,
  });

  IconData _getToolIcon(ToolType type) {
    switch (type) {
      case ToolType.money:
        return Icons.money;
      case ToolType.deposit:
        return Icons.account_balance;
      case ToolType.credit:
        return Icons.credit_card;
      case ToolType.stocks:
        return Icons.trending_up;
      case ToolType.bonds:
        return Icons.receipt_long;
      case ToolType.cryptocurrency:
        return Icons.currency_bitcoin;
      case ToolType.other:
        return Icons.category;
    }
  }

  String _formatDate(DateTime? date) => date != null ? DateFormat('MMM d, yyyy').format(date) : '';

  String _getPayoutTypeDisplayName(PayoutType type) {
    switch (type) {
      case PayoutType.atEndOfTerm:
        return 'В конце срока';
      case PayoutType.monthly:
        return 'Ежемесячно';
      case PayoutType.monthlyToWithdrawalAccount:
        return 'Ежемесячно на счет списания';
    }
  }

  String _getCreditPaymentTypeDisplayName(CreditPaymentType type) {
    switch (type) {
      case CreditPaymentType.annuity:
        return 'Аннуитетный (Annuity)';
      case CreditPaymentType.differentiated:
        return 'Дифференцированный (Differentiated)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsBloc = context.read<AccountsBloc>();
    final tool = accountsBloc.accountData.tools[toolId];

    if (tool == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tool Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Tool not found.')),
      );
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color positive = colorScheme.primary.withOpacity(0.8);
    final Color negative = colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(tool.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getToolIcon(tool.type), size: 32, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tool.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tool.ticker != null)
              Text('Ticker: ${tool.ticker}', style: Theme.of(context).textTheme.bodySmall),
            Text('Quantity: ${tool.quantity.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
            Text('Current value: ${formatCurrency(tool.currentValue)}', style: Theme.of(context).textTheme.bodyMedium),
            Text(
              'Change: ${tool.percentageChange >= 0 ? '+' : ''}${tool.percentageChange.toStringAsFixed(2)}%',
              style: TextStyle(
                color: tool.percentageChange >= 0 ? positive : negative,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tool.type == ToolType.bonds && tool.faceValue != null)
              Text('Nominal: ${formatCurrency(tool.faceValue!)}', style: Theme.of(context).textTheme.bodySmall),
            if (tool.type == ToolType.credit) ...[
              if (tool.interestRate != null)
                Text('Interest: ${tool.interestRate!.toStringAsFixed(2)}% APY', style: Theme.of(context).textTheme.bodySmall),
              if (tool.loanStartDate != null)
                Text('Loan start: ${_formatDate(tool.loanStartDate!)}', style: Theme.of(context).textTheme.bodyMedium),
              if (tool.loanTermMonths != null)
                Text('Term: ${tool.loanTermMonths} months', style: Theme.of(context).textTheme.bodyMedium),
              if (tool.paymentDayOfMonth != null)
                Text('Payment day: ${tool.paymentDayOfMonth}', style: Theme.of(context).textTheme.bodyMedium),
              if (tool.creditPaymentType != null)
                Text('Payment type: ${_getCreditPaymentTypeDisplayName(tool.creditPaymentType!)}', style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (tool.type == ToolType.deposit) ...[
              if (tool.startDate != null && tool.endDate != null)
                Text('Period: ${_formatDate(tool.startDate!)} – ${_formatDate(tool.endDate!)}', style: Theme.of(context).textTheme.bodySmall),
              if (tool.payoutType != null)
                Text(_getPayoutTypeDisplayName(tool.payoutType!), style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}