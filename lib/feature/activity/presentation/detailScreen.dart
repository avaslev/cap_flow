import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/presentation/widget/form/activityEdit.dart';
import 'package:investflow/feature/activity/logic/activity_rows.dart';
import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:intl/intl.dart';

/// Детальная страница операции.
class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailScreen({required this.activityId, super.key});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ActivityBloc>().add(
      ActivityTransitionEvent(activityId: widget.activityId),
    );
  }

  void _openEditSheet(BuildContext context, ActivityLoaded state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ActivityEditSheet(
            activity: state.data,
            counterpart: state.counterpart,
            commission: state.commission,
          ),
        );
      },
    ).then((_) {
      // Обновляем детальную страницу после редактирования.
      context.read<ActivityBloc>().add(
        ActivityTransitionEvent(activityId: state.data.id),
      );
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ActivityLoaded state,
  ) async {
    final bool isPair = state.isTransferPair;
    final String? pairId = state.data.transferPairId;
    final bool deletePair = isPair && pairId != null && pairId.isNotEmpty;
    final TransferKind kind = state.transferKind;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            deletePair
                ? switch (kind) {
                    TransferKind.purchase => 'Удаление покупки',
                    TransferKind.sale => 'Удаление продажи',
                    TransferKind.transfer => 'Удаление перевода',
                  }
                : 'Удаление операции',
          ),
          content: Text(
            deletePair
                ? switch (kind) {
                    TransferKind.purchase =>
                      'Удалить покупку? Будут удалены обе половины, комиссия '
                          'и НКД. Действие необратимо.',
                    TransferKind.sale =>
                      'Удалить продажу? Будут удалены обе половины, комиссия '
                          'и связанные доход/расход. Действие необратимо.',
                    TransferKind.transfer =>
                      'Удалить перевод? Будут удалены обе половины и комиссия. '
                          'Действие необратимо.',
                  }
                : 'Удалить эту операцию? Действие необратимо.',
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
    if (confirmed != true || !context.mounted) return;

    final ActivityRepository repository = ActivityRepository();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    if (deletePair) {
      final String id = pairId;
      // Фиксируем все записи пары (половины + комиссию) для отмены.
      final List<Activity> group = await repository.getByTransferPairId(id);
      // Покупка/продажа дополнительно создают нетранзитные записи (НКД,
      // реализованный доход/расход) — удаляем и их, иначе баланс разъедется.
      if (kind != TransferKind.transfer) {
        final bool dataIsFrom = state.data.type == ActivityType.substract;
        final Activity from = dataIsFrom ? state.data : state.counterpart!;
        final Activity to = dataIsFrom ? state.counterpart! : state.data;
        final Activity asset = kind == TransferKind.purchase ? to : from;
        final Activity money = kind == TransferKind.purchase ? from : to;
        group.addAll(
          await repository.getPairExtras(
            assetToolId: asset.toolId,
            moneyToolId: money.toolId,
            at: from.createAt,
          ),
        );
      }
      await repository.deleteAll(
        group.map((Activity a) => a.id).toList(),
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            switch (kind) {
              TransferKind.purchase => 'Покупка удалена',
              TransferKind.sale => 'Продажа удалена',
              TransferKind.transfer => 'Перевод удалён',
            },
          ),
          // По умолчанию снекбар с action не исчезает сам — закрываем
          // по таймауту, чтобы он не «зависал» внизу экрана.
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Отменить',
            // Undo: возвращаем обе половины и комиссию с теми же id.
            onPressed: () => repository.insertAll(group),
          ),
        ),
      );
    } else {
      await repository.delete(state.data.id);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Операция удалена'),
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Отменить',
            // Undo: возвращаем операцию с тем же id.
            onPressed: () => repository.insert(state.data),
          ),
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Операция')),
      body: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (BuildContext context, ActivityState state) {
          if (state is ActivityError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(state.message),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.read<ActivityBloc>().add(
                      ActivityTransitionEvent(activityId: widget.activityId),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          if (state is ActivityLoaded) {
            if (state.isTransferPair) {
              return _buildTransferPair(context, state);
            }
            final Activity a = state.data;
            final bool isAdd = a.type == ActivityType.add;
            final double value = a.price * a.quantity;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${isAdd ? '+' : '-'}${formatCurrency(value)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .copyWith(
                                fontWeight: FontWeight.w800,
                                color: isAdd
                                    ? Colors.green.shade700
                                    : colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAdd ? 'Пополнение' : 'Списание',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _row(context, 'Категория', a.name ?? '—'),
                  _rowWidget(context, 'Инструмент', _toolName(a.toolId)),
                  _row(
                    context,
                    'Дата',
                    DateFormat(
                      'dd MMMM yyyy, HH:mm',
                      'ru',
                    ).format(a.createAt),
                  ),
                  if (a.comment != null && a.comment!.isNotEmpty)
                    _row(context, 'Комментарий', a.comment!),
                  if (a.interestAmount != null)
                    _row(
                      context,
                      'Проценты',
                      formatCurrency(a.interestAmount!),
                    ),
                  if (a.principalAmount != null)
                    _row(
                      context,
                      'Погашение тела',
                      formatCurrency(a.principalAmount!),
                    ),
                  const SizedBox(height: 24),
                  _actionButtons(context, state),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildTransferPair(BuildContext context, ActivityLoaded state) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool dataIsFrom = state.data.type == ActivityType.substract;
    final Activity from = dataIsFrom ? state.data : state.counterpart!;
    final Activity to = dataIsFrom ? state.counterpart! : state.data;
    final TransferKind kind = transferKindOf(from, to);
    final double amount = kind == TransferKind.sale
        ? to.price * to.quantity
        : from.price * from.quantity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                Text(
                  formatCurrency(amount),
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  switch (kind) {
                    TransferKind.purchase => 'Покупка',
                    TransferKind.sale => 'Продажа',
                    TransferKind.transfer => 'Перевод',
                  },
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _rowWidget(context, 'Откуда', _amountWithTool(from)),
          _rowWidget(context, 'Куда', _amountWithTool(to)),
          if (state.commission != null)
            _row(
              context,
              'Комиссия',
              formatCurrency(
                state.commission!.price * state.commission!.quantity,
              ),
            ),
          _row(
            context,
            'Дата',
            DateFormat('dd MMMM yyyy, HH:mm', 'ru').format(from.createAt),
          ),
          if (from.comment != null && from.comment!.isNotEmpty)
            _row(context, 'Комментарий', from.comment!),
          const SizedBox(height: 24),
          _actionButtons(context, state),
        ],
      ),
    );
  }

  /// Две обычные кнопки в теле карточки: редактировать и удалить.
  /// Продажу редактировать нельзя (есть связанные доходы/расходы) —
  /// для неё остаётся только удаление.
  Widget _actionButtons(BuildContext context, ActivityLoaded state) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool canEdit = !(state.isTransferPair &&
        state.transferKind == TransferKind.sale);
    return Row(
      children: <Widget>[
        if (canEdit) ...<Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _openEditSheet(context, state),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Редактировать'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _confirmDelete(context, state),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Удалить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountWithTool(Activity a) {
    return FutureBuilder<Tool?>(
      future: _toolFuture(a.toolId),
      builder: (BuildContext context, AsyncSnapshot<Tool?> snapshot) {
        final Tool? tool = snapshot.data;
        final String name = tool?.name ?? '—';
        final String ticker = tool?.ticker ?? 'RUB';
        final String rub = formatCurrency(a.price * a.quantity);
        if (ticker == 'RUB') return Text('$name · $rub');
        final String native = '${_formatAmount(a.quantity)} $ticker';
        return Text('$name · $native · $rub');
      },
    );
  }

  Widget _rowWidget(BuildContext context, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Future<Tool?> _toolFuture(String toolId) async {
    try {
      return await ToolRepository().get(toolId);
    } catch (_) {
      return null;
    }
  }

  Widget _toolName(String toolId) {
    return FutureBuilder<Tool?>(
      future: _toolFuture(toolId),
      builder: (BuildContext context, AsyncSnapshot<Tool?> snapshot) {
        final Tool? tool = snapshot.data;
        return Text(tool?.name ?? '—');
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double value) =>
    NumberFormat('#,##0.##', 'ru').format(value);
