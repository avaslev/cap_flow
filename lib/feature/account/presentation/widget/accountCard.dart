import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:investflow/core/utils/getAccountIcon.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';

import '../../../../core/utils/formatCurrency.dart';

/// A widget to display a single account summary card.
class AccountCard extends StatelessWidget {
  final AccountSummary account;
  final bool isDeletable;
  final Map<ToolType, int> toolCounts;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const AccountCard({
    super.key,
    required this.account,
    required this.isDeletable,
    required this.toolCounts,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  IconData _toolIcon(ToolType type) {
    return switch (type) {
      ToolType.money => Icons.account_balance_wallet,
      ToolType.deposit => Icons.account_balance,
      ToolType.credit => Icons.credit_card,
      ToolType.stocks => Icons.trending_up,
      ToolType.bonds => Icons.receipt_long,
      ToolType.cryptocurrency => Icons.currency_bitcoin,
      ToolType.other => Icons.category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color cardColor = Color(account.colorValue);
    final Color textColor =
        cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = textColor.withValues(alpha: 0.75);
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    final bool canEdit = account.id != 'total';
    final bool editMode = canEdit && isDeletable;

    // Net turnover for the last 30 days (single signed number).
    final double net = account.periodIncome + account.periodExpense;
    final Color netColor = net > 0
        ? colorScheme.primary
        : net < 0
        ? colorScheme.error
        : subtleTextColor;

    return GestureDetector(
      onTap: () {
        accountBloc.add(DisableEditModeAccountCardEvent(account.id));
      },
      onLongPress: () {
        canEdit
            ? accountBloc.add(EnableEditModeAccountCardEvent(account.id))
            : null;
      },
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Row 1: icon + name.
                Row(
                  children: <Widget>[
                    Icon(
                      getAccountIcon(account.type),
                      color: subtleTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    // Reserve space for the edit overlay controls.
                    if (editMode) const SizedBox(width: 96),
                  ],
                ),
                const Spacer(),
                // Row 2: balance + report shortcut.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        formatCurrency(account.balance),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.show_chart, color: textColor, size: 20),
                      tooltip: 'Отчёт',
                      onPressed: () => GoRouter.of(
                        context,
                      ).go('/accounts/${account.id}/report'),
                    ),
                  ],
                ),
                // Row 3: net turnover for the last 30 days.
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    net == 0
                        ? '0,00 ₽'
                        : '${net > 0 ? '+' : '-'}${formatCurrency(net.abs())}',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Row 4: tool composition + nearest planned event.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    // Account status indicators (always visible).
                    if (account.excludeFromTotal)
                      Tooltip(
                        message: 'Не учитывается в Total Balance',
                        child: Icon(
                          Icons.visibility_off,
                          size: 14,
                          color: subtleTextColor,
                        ),
                      ),
                    if (account.hideEvents)
                      Tooltip(
                        message: 'События скрыты из Total Balance',
                        child: Icon(
                          Icons.notifications_off,
                          size: 14,
                          color: subtleTextColor,
                        ),
                      ),
                    if (account.excludeFromTotal || account.hideEvents)
                      const SizedBox(width: 2),
                    for (final MapEntry<ToolType, int> entry
                        in toolCounts.entries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _toolIcon(entry.key),
                            size: 14,
                            color: subtleTextColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '×${entry.value}',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall!.copyWith(
                              color: subtleTextColor,
                            ),
                          ),
                        ],
                      ),
    
                  ],
                ),
              ],
            ),
            // Edit controls: overlay, no layout shift.
            // Edit controls: статусы и удаление — сверху справа,
            // перемещение — стрелки в нижнем правом углу (overlay, без сдвига).
            if (editMode)
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _editIcon(
                      context,
                      icon: account.excludeFromTotal
                          ? Icons.visibility_off
                          : Icons.visibility,
                      tooltip: account.excludeFromTotal
                          ? 'Исключён из Total'
                          : 'Исключить из Total',
                      color: account.excludeFromTotal
                          ? colorScheme.error
                          : textColor,
                      onPressed: () {
                        accountBloc.add(
                          ChangeAccountEvent(
                            accountId: account.id,
                            hideEvents: account.hideEvents,
                            excludeFromTotal: !account.excludeFromTotal,
                            remove: false,
                          ),
                        );
                      },
                    ),
                    _editIcon(
                      context,
                      icon: account.hideEvents
                          ? Icons.notifications_off
                          : Icons.notifications,
                      tooltip: account.hideEvents
                          ? 'События скрыты'
                          : 'Скрыть события',
                      color: account.hideEvents
                          ? colorScheme.error
                          : textColor,
                      onPressed: () {
                        accountBloc.add(
                          ChangeAccountEvent(
                            accountId: account.id,
                            hideEvents: !account.hideEvents,
                            excludeFromTotal: account.excludeFromTotal,
                            remove: false,
                          ),
                        );
                      },
                    ),
                    _editIcon(
                      context,
                      icon: Icons.delete_forever,
                      tooltip: 'Удалить счёт',
                      color: colorScheme.error,
                      onPressed: () => _confirmDelete(context, accountBloc),
                    ),
                  ],
                ),
              ),
            if (editMode)
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _editIcon(
                      context,
                      icon: Icons.chevron_left,
                      tooltip: 'Переместить ближе к началу',
                      color: canMoveUp
                          ? textColor
                          : textColor.withValues(alpha: 0.3),
                      onPressed: (canMoveUp && onMoveUp != null)
                          ? onMoveUp
                          : null,
                    ),
                    _editIcon(
                      context,
                      icon: Icons.chevron_right,
                      tooltip: 'Переместить дальше',
                      color: canMoveDown
                          ? textColor
                          : textColor.withValues(alpha: 0.3),
                      onPressed: (canMoveDown && onMoveDown != null)
                          ? onMoveDown
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AccountsBloc accountBloc,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Удаление счёта'),
          content: Text(
            'Удалить счёт «${account.name}» вместе с тулами и операциями? '
            'Действие необратимо.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Удалить',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true && context.mounted) {
      accountBloc.add(
        ChangeAccountEvent(
          accountId: account.id,
          hideEvents: account.hideEvents,
          excludeFromTotal: account.excludeFromTotal,
          remove: true,
        ),
      );
      Toast.show(context, 'Счёт «${account.name}» удалён');
    } else {
      accountBloc.add(DisableEditModeAccountCardEvent(account.id));
    }
  }
}
