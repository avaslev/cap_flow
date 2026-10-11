import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/presentation/widget/form/activityEdit.dart';
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

  void _openEditSheet(BuildContext context, Activity activity) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ActivityEditSheet(activity: activity),
        );
      },
    ).then((_) {
      // Обновляем детальную страницу после редактирования.
      context.read<ActivityBloc>().add(
        ActivityTransitionEvent(activityId: activity.id),
      );
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Activity activity,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Удаление операции'),
          content: const Text('Удалить эту операцию? Действие необратимо.'),
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    await ActivityRepository().delete(activity.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Операция удалена'),
        action: SnackBarAction(
          label: 'Отменить',
          // Undo: возвращаем операцию с тем же id.
          onPressed: () => ActivityRepository().insert(activity),
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Операция'),
        actions: <Widget>[
          BlocBuilder<ActivityBloc, ActivityState>(
            builder: (BuildContext context, ActivityState state) {
              if (state is! ActivityLoaded) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Редактировать',
                    onPressed: () => _openEditSheet(context, state.data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить операцию',
                    onPressed: () => _confirmDelete(context, state.data),
                  ),
                ],
              );
            },
          ),
        ],
      ),
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
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
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
