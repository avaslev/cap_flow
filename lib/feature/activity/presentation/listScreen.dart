import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/core/widgets/searchable_picker.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/categoryRepository.dart';
import 'package:go_router/go_router.dart';
import 'package:investflow/feature/activity/logic/activity_rows.dart';
import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:intl/intl.dart';

/// Экран операций: месяц, поиск, фильтр по типу, фильтр по категории,
/// группировка по дням.
class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  static const List<String> _monthNames = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  bool _searchActive = false;
  String _query = '';
  String? _typeFilter; // null = все; 'add' | 'substract'
  String? _categoryFilter; // null = все категории
  List<String> _categories = const <String>[];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late final StreamSubscription<void> _activityChanges;

  @override
  void initState() {
    super.initState();
    context.read<ActivityBloc>().add(ActivityListTransitionEvent());
    _loadCategories();
    // Undo удаления вставляет запись уже после возврата с деталей —
    // перечитываем список, чтобы восстановленная операция появилась.
    _activityChanges = ActivityRepository.changes.listen((_) {
      if (mounted) {
        context.read<ActivityBloc>().add(ActivityListTransitionEvent());
      }
    });
  }

  @override
  void dispose() {
    _activityChanges.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final List<String> categories = await CategoryRepository().getList(null, null);
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Активность'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_searchActive ? Icons.search_off : Icons.search),
            tooltip: 'Поиск',
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _query = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            // Явный child (вместо icon:) — без общего ключа moreButton,
            // чтобы иконка не пропадала после выбора фильтра.
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                _typeFilter == null ? Icons.filter_list : Icons.filter_alt,
              ),
            ),
            tooltip: 'Фильтр по типу',
            onSelected: (String value) {
              setState(() {
                _typeFilter = value == 'all' ? null : value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('Все типы'),
              ),
              const PopupMenuItem<String>(
                value: 'add',
                child: Text('Пополнения'),
              ),
              const PopupMenuItem<String>(
                value: 'substract',
                child: Text('Списания'),
              ),
              const PopupMenuItem<String>(
                value: 'transfer',
                child: Text('Переводы'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_categoryFilter == null ? Icons.label_outline : Icons.label),
            tooltip: 'Фильтр по категории',
            onPressed: () => _showCategorySheet(context),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Навигация по месяцам.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Предыдущий месяц',
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1, 1);
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Следующий месяц',
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1, 1);
                }),
              ),
            ],
          ),
          if (_searchActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _query = ''),
                        ),
                  hintText: 'Поиск по названию или комментарию',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  isDense: true,
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          Expanded(
            child: BlocBuilder<ActivityBloc, ActivityState>(
              builder: (BuildContext context, ActivityState state) {
                if (state is ActivityInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ActivityError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(state.message),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.read<ActivityBloc>().add(
                            ActivityListTransitionEvent(),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ActivityListLoaded) {
                  return _buildList(context, state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Фильтрация по месяцу/типу/категории/тексту + группировка по дням.
  List<MapEntry<DateTime, List<ActivityRow>>> _groupFiltered(
    List<ActivityRow> rows,
    Map<String, Tool> toolsById,
  ) {
    final Map<DateTime, List<ActivityRow>> grouped =
        <DateTime, List<ActivityRow>>{};
    for (final ActivityRow row in rows) {
      if (!_matchesFilters(row, toolsById)) continue;
      final DateTime day = DateTime(
        row.date.year,
        row.date.month,
        row.date.day,
      );
      grouped.putIfAbsent(day, () => <ActivityRow>[]).add(row);
    }
    final List<DateTime> keys = grouped.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    return <MapEntry<DateTime, List<ActivityRow>>>[
      for (final DateTime k in keys)
        MapEntry<DateTime, List<ActivityRow>>(
          k,
          grouped[k]!
            ..sort(
              (ActivityRow a, ActivityRow b) => b.date.compareTo(a.date),
            ),
        ),
    ];
  }

  bool _matchesFilters(ActivityRow row, Map<String, Tool> toolsById) {
    if (_month.year != row.date.year || _month.month != row.date.month) {
      return false;
    }
    final String query = _query.trim().toLowerCase();

    if (row is TransferActivityRow) {
      if (_typeFilter != null && _typeFilter != 'transfer') return false;
      if (_categoryFilter != null) return false;
      if (query.isEmpty) return true;
      return _containsText(row.from, query) ||
          _containsText(row.to, query) ||
          _containsText(row.commission, query) ||
          (toolsById[row.from.toolId]?.name ?? '')
              .toLowerCase()
              .contains(query) ||
          (toolsById[row.to.toolId]?.name ?? '')
              .toLowerCase()
              .contains(query);
    }

    final Activity a = (row as SingleActivityRow).activity;
    if (_typeFilter != null) {
      if (_typeFilter == 'transfer') {
        if (!a.isTransmit) return false;
      } else if (a.isTransmit || a.type.name != _typeFilter) {
        return false;
      }
    }
    if (_categoryFilter != null && a.name != _categoryFilter) return false;
    if (query.isEmpty) return true;
    return _containsText(a, query) ||
        (toolsById[a.toolId]?.name ?? '').toLowerCase().contains(query);
  }

  bool _containsText(Activity? a, String query) {
    if (a == null) return false;
    return (a.name ?? '').toLowerCase().contains(query) ||
        (a.comment ?? '').toLowerCase().contains(query);
  }

  Widget _buildList(BuildContext context, ActivityListLoaded state) {
    final List<ActivityRow> rows = buildActivityRows(state.data);
    final List<MapEntry<DateTime, List<ActivityRow>>> groups = _groupFiltered(
      rows,
      state.toolsById,
    );

    if (groups.isEmpty) {
      return Center(
      child: Text(
        _query.isNotEmpty || _typeFilter != null || _categoryFilter != null
            ? 'Ничего не найдено'
            : 'Операций пока нет',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Итоги за выбранный месяц: только реальные доходы/расходы
    // (переводы между своими счетами не влияют).
    double income = 0;
    double expense = 0;
    for (final MapEntry<DateTime, List<ActivityRow>> g in groups) {
      for (final ActivityRow row in g.value) {
        for (final Activity a in row.activities) {
          if (a.isTransmit) continue;
          if (a.type == ActivityType.add) {
            income += a.price * a.quantity;
          } else {
            expense -= a.price * a.quantity;
          }
        }
      }
    }

    return ListView(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _total('Доход', income, Colors.green.shade700),
                _total('Расход', expense.abs(), Colors.red.shade700),
              ],
            ),
          ),
        ),
        for (final MapEntry<DateTime, List<ActivityRow>> g in groups)
          _DayGroup(
            date: g.key,
            rows: g.value,
            toolsById: state.toolsById,
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _total(String label, double value, Color color) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(value),
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _showCategorySheet(BuildContext context) async {
    final SearchPick? pick = await showSearchablePicker(
      context,
      items: _categories,
      selected: _categoryFilter,
      allLabel: 'Все категории',
      searchHint: 'Поиск категории',
    );
    if (pick == null || !mounted) return;
    setState(() => _categoryFilter = pick.value);
  }
}

/// Группа операций за день.
class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<ActivityRow> rows;
  final Map<String, Tool> toolsById;

  const _DayGroup({
    required this.date,
    required this.rows,
    required this.toolsById,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('d MMMM yyyy', 'ru').format(date);
    // Переводы между своими счетами не влияют на доход/расход дня.
    double dayIncome = 0;
    double dayExpense = 0;
    for (final ActivityRow row in rows) {
      for (final Activity a in row.activities) {
        if (a.isTransmit) continue;
        final double v = a.price * a.quantity;
        if (a.type == ActivityType.add) {
          dayIncome += v;
        } else {
          dayExpense += v;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (dayIncome > 0)
                    Text(
                      '+${formatCurrency(dayIncome)}',
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (dayExpense > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '−${formatCurrency(dayExpense)}',
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ...rows
            .map<Widget>(
              (ActivityRow row) =>
                  _ActivityListItem(row: row, toolsById: toolsById),
            )
            .toList(),
        const Divider(height: 1.0, indent: 16.0, endIndent: 16.0),
      ],
    );
  }
}

/// Строка операции: одиночная запись или объединённый перевод.
class _ActivityListItem extends StatelessWidget {
  final ActivityRow row;
  final Map<String, Tool> toolsById;

  const _ActivityListItem({required this.row, required this.toolsById});

  @override
  Widget build(BuildContext context) {
    final ActivityRow current = row;
    if (current is TransferActivityRow) {
      return _TransferActivityListItem(row: current, toolsById: toolsById);
    }
    return _SingleActivityListItem(
      activity: (current as SingleActivityRow).activity,
    );
  }
}

/// Строка обычной операции.
class _SingleActivityListItem extends StatelessWidget {
  final Activity activity;

  const _SingleActivityListItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isAdd = activity.type == ActivityType.add;
    // Переводы между своими счетами — нейтральные (не доход/расход).
    final bool internal = activity.isTransmit;
    // Маркер прибыль/убыток (quantity = 0) несёт сумму в price.
    final double value = activity.quantity == 0
        ? activity.price
        : activity.price * activity.quantity;

    return InkWell(
      onTap: () async {
        await context.push('/activities/${activity.id}');
        // Возвращаемся с деталей: данные могли измениться (в т.ч. обе
        // половины перевода) — перечитываем список.
        if (context.mounted) {
          context.read<ActivityBloc>().add(ActivityListTransitionEvent());
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: <Widget>[
            Icon(
              internal
                  ? Icons.swap_horiz
                  : isAdd
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: internal
                  ? colorScheme.onSurfaceVariant
                  : isAdd
                  ? Colors.green.shade700
                  : colorScheme.error,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activity.name ?? 'Операция',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (activity.comment != null &&
                      activity.comment!.isNotEmpty)
                    Text(
                      activity.comment!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Text(
              '${internal ? '' : isAdd ? '+' : '-'}${formatCurrency(value)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: internal
                    ? colorScheme.onSurfaceVariant
                    : isAdd
                    ? Colors.green.shade700
                    : colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка объединённого перевода: откуда → куда, сумма, комиссия.
class _TransferActivityListItem extends StatelessWidget {
  final TransferActivityRow row;
  final Map<String, Tool> toolsById;

  const _TransferActivityListItem({
    required this.row,
    required this.toolsById,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Tool? fromTool = toolsById[row.from.toolId];
    final Tool? toTool = toolsById[row.to.toolId];
    final String fromName = fromTool?.name ?? 'счёт';
    final String toName = toTool?.name ?? 'счёт';
    final String? fromTicker = fromTool?.ticker;
    final String? toTicker = toTool?.ticker;

    final List<String> subtitle = <String>[];
    if (fromTicker != null &&
        toTicker != null &&
        fromTicker != toTicker) {
      subtitle.add(
        '${_formatAmount(row.from.quantity)} $fromTicker → '
        '${_formatAmount(row.to.quantity)} $toTicker',
      );
    }
    final String? comment = row.from.comment;
    if (comment != null && comment.isNotEmpty) subtitle.add(comment);
    if (row.commission != null) {
      final Activity commission = row.commission!;
      subtitle.add('Комиссия: ${formatCurrency(commission.price * commission.quantity)}');
    }
    final String title = switch (row.kind) {
      TransferKind.purchase => 'Покупка: ${toTool?.name ?? 'инструмент'}',
      TransferKind.sale => 'Продажа: ${fromTool?.name ?? 'инструмент'}',
      TransferKind.transfer => 'Перевод: $fromName → $toName',
    };

    return InkWell(
      onTap: () async {
        await context.push('/activities/${row.from.id}');
        if (context.mounted) {
          context.read<ActivityBloc>().add(ActivityListTransitionEvent());
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: <Widget>[
            Icon(Icons.swap_horiz, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final String line in subtitle)
                    Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Text(
              formatCurrency(row.rubAmount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(double value) =>
    NumberFormat('#,##0.##', 'ru').format(value);
