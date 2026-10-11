import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// A widget to display a list of financial tools.
class ToolList extends StatelessWidget {
  final AccountData accountData;
  final String accountId;

  const ToolList({
    Key? key,
    required this.accountData,
    required this.accountId,
  }) : super(key: key);

  String _getToolTypeDisplayName(ToolType type) {
    switch (type) {
      case ToolType.money:
        return 'Деньги и валюты';
      case ToolType.deposit:
        return 'Депозиты';
      case ToolType.credit:
        return 'Кредиты';
      case ToolType.stocks:
        return 'Акции';
      case ToolType.bonds:
        return 'Облигации';
      case ToolType.cryptocurrency:
        return 'Криптовалюта';
      case ToolType.other:
        return 'Прочее';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Closed tools keep history in the DB but are hidden from lists.
    final List<ToolSummary> tools = accountData
        .getToolsForAccount(accountId)
        .where((ToolSummary tool) => !tool.isClosed)
        .toList();

    if (tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No financial tools for this account.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Group tools by type
    final Map<ToolType, List<ToolSummary>> groupedTools = {};
    for (final ToolSummary tool in tools) {
      groupedTools.putIfAbsent(tool.type, () => <ToolSummary>[]).add(tool);
    }

    // Sort group keys for consistent display order
    final List<ToolType> sortedTypes = groupedTools.keys.toList()
      ..sort((ToolType a, ToolType b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedTypes.map<Widget>((ToolType type) {
        final List<ToolSummary> toolsInGroup = groupedTools[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 8),
              child: Text(
                _getToolTypeDisplayName(type),
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
              ),
            ),
            ...toolsInGroup
                .map<Widget>((ToolSummary tool) => ToolTile(tool: tool, accountId: accountId))
                .toList(),
          ],
        );
      }).toList(),
    );
  }
}

/// A widget to display a single financial tool/asset.
class ToolTile extends StatelessWidget {
  final ToolSummary tool;
  final String accountId;

  const ToolTile({
    Key? key,
    required this.tool,
    required this.accountId,
  }) : super(key: key);

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color positiveChangeColor = colorScheme.primary.withOpacity(0.8);
    final Color negativeChangeColor = colorScheme.error;

    return InkWell(
      onTap: () {
        context.go('/accounts/$accountId/tools/${tool.id}');
      },
      borderRadius: BorderRadius.circular(12.0),
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: <Widget>[
            Icon(
              _getToolIcon(tool.type),
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tool.name,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (tool.ticker != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        tool.ticker!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .copyWith(
                              fontWeight: FontWeight.w400,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (tool.type == ToolType.deposit && tool.startDate != null)
                    Text(
                      tool.endDate != null
                          ? '${DateFormat('MMM d, yyyy').format(tool.startDate!)} - ${DateFormat('MMM d, yyyy').format(tool.endDate!)}'
                          : 'Бессрочный · с ${DateFormat('dd.MM.yyyy').format(tool.startDate!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.deposit && tool.payoutType != null)
                    Text(
                      _getPayoutTypeDisplayName(tool.payoutType!),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit && tool.loanStartDate != null)
                    Text(
                      'Start: ${DateFormat('MMM d, yyyy').format(tool.loanStartDate!)} - ${tool.loanTermMonths} Months',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit &&
                      tool.paymentDayOfMonth != null &&
                      tool.creditPaymentType != null)
                    Text(
                      'Pay on Day ${tool.paymentDayOfMonth} (${_getCreditPaymentTypeDisplayName(tool.creditPaymentType!)})',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit && tool.interestRate != null)
                    Text(
                      'Interest: ${tool.interestRate!.toStringAsFixed(2)}% APY',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.bonds && tool.faceValue != null)
                    Text(
                      'Nominal: ${formatCurrency(tool.faceValue!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatCurrency(tool.currentValue),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tool.currentValue >= 0
                            ? colorScheme.onSurface
                            : colorScheme.error,
                      ),
                ),
                if (tool.percentageChange != 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${tool.percentageChange >= 0 ? '+' : ''}${tool.percentageChange.toStringAsFixed(2)}% ${tool.type == ToolType.deposit ? '(APY)' : ''}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tool.percentageChange >= 0
                              ? positiveChangeColor
                              : negativeChangeColor,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
