import 'dart:async';

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
                      tooltip: 'Управление счётом',
                      color: colorScheme.error,
                      onPressed: () => _showManageSheet(context, accountBloc),
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

  /// Нижняя шторка управления счётом: архив, полное удаление или отмена.
  /// Безвозвратное удаление защищено от случайного нажатия: нужно подтвердить
  /// его тремя тапами подряд, иначе счётчик сбрасывается по таймеру.
  Future<void> _showManageSheet(
    BuildContext context,
    AccountsBloc accountBloc,
  ) async {
    final _ManageAction? action = await showModalBottomSheet<_ManageAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return _ManageAccountSheet(account: account);
      },
    );

    if (!context.mounted) return;
    switch (action) {
      case _ManageAction.archive:
        accountBloc.add(ArchiveAccountEvent(account.id));
        Toast.show(context, 'Счёт «${account.name}» в архиве');
      case _ManageAction.delete:
        accountBloc.add(
          ChangeAccountEvent(
            accountId: account.id,
            hideEvents: account.hideEvents,
            excludeFromTotal: account.excludeFromTotal,
            remove: true,
          ),
        );
        Toast.show(context, 'Счёт «${account.name}» удалён');
      case _ManageAction.cancel:
      case null:
        accountBloc.add(DisableEditModeAccountCardEvent(account.id));
    }
  }
}

/// Шторка управления счётом. Полное удаление требует трёх подтверждений
/// подряд: после каждого тапа показывается тостер с обратным отсчётом.
class _ManageAccountSheet extends StatefulWidget {
  final AccountSummary account;

  const _ManageAccountSheet({required this.account});

  @override
  State<_ManageAccountSheet> createState() => _ManageAccountSheetState();
}

class _ManageAccountSheetState extends State<_ManageAccountSheet> {
  /// Сколько нажатий нужно ещё для безвозвратного удаления.
  static const int _requiredTaps = 3;
  /// Окно, за которое счётчик сбрасывается (сек).
  static const int _confirmWindowSeconds = 5;
  /// Высота нижней шторки — тост показывается над ней.
  static const double _sheetHeight = 330;

  int _tapsLeft = _requiredTaps;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onDeleteTap() {
    setState(() => _tapsLeft--);
    if (_tapsLeft <= 0) {
      _resetTimer?.cancel();
      Navigator.pop(context, _ManageAction.delete);
      return;
    }
    Toast.show(
      context,
      'Ещё $_tapsLeft ${_plural(_tapsLeft)} для удаления',
      error: true,
      countdown: const Duration(seconds: _confirmWindowSeconds),
      bottomOffset: _sheetHeight,
    );
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: _confirmWindowSeconds), () {
      if (!mounted) return;
      setState(() => _tapsLeft = _requiredTaps);
    });
  }

  static String _plural(int n) {
    if (n >= 5) return 'нажатий';
    if (n == 1) return 'нажатие';
    return 'нажатия';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Счёт «${widget.account.name}»',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Выберите действие. Полное удаление необратимо и стирает '
              'операции из истории и статистики по всем месяцам. '
              'Архивация сохраняет данные — счёт можно вернуть.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Положить в архив'),
            subtitle: const Text('Скрыть из списка и баланса, данные сохранить'),
            onTap: () => Navigator.pop(context, _ManageAction.archive),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: colorScheme.error),
            title: Text(
              'Удалить полностью',
              style: TextStyle(color: colorScheme.error),
            ),
            subtitle: Text(
              _tapsLeft == _requiredTaps
                  ? 'Убрать счёт, тулы, операции и парные переводы. '
                        'Восстановить можно только из резервной копии. '
                        'Требуется $_requiredTaps нажатия'
                  : 'Нажмите ещё $_tapsLeft ${_plural(_tapsLeft)}, '
                        'чтобы удалить безвозвратно',
              style: TextStyle(
                color: _tapsLeft == _requiredTaps
                    ? null
                    : colorScheme.error,
              ),
            ),
            onTap: _onDeleteTap,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Отмена'),
            onTap: () => Navigator.pop(context, _ManageAction.cancel),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Действие в шторке управления счётом.
enum _ManageAction { archive, delete, cancel }
