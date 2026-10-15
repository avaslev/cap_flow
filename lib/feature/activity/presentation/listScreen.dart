import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:go_router/go_router.dart';
import 'package:investflow/feature/activity/logic/bloc.dart';
import 'package:intl/intl.dart';

/// Экран операций: месяц, поиск, фильтр по типу, группировка по дням.
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
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    context.read<ActivityBloc>().add(ActivityListTransitionEvent());
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
                  return _buildList(context, state.data);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Фильтрация по месяцу/типу/тексту + группировка по дням.
  List<MapEntry<DateTime, List<Activity>>> _groupFiltered(
    List<Activity> data,
  ) {
    final String query = _query.trim().toLowerCase();
    final Map<DateTime, List<Activity>> grouped = <DateTime, List<Activity>>{};
    for (final Activity a in data) {
      if (_month.year != a.createAt.year || _month.month != a.createAt.month) {
        continue;
      }
      final bool internal = a.isTransmit;
      if (_typeFilter != null) {
        if (_typeFilter == 'transfer') {
          if (!internal) continue;
        } else if (internal || a.type.name != _typeFilter) {
          continue;
        }
      }
      if (query.isNotEmpty) {
        final String name = (a.name ?? '').toLowerCase();
        final String comment = (a.comment ?? '').toLowerCase();
        if (!name.contains(query) && !comment.contains(query)) {
          continue;
        }
      }
      final DateTime day = DateTime(
        a.createAt.year,
        a.createAt.month,
        a.createAt.day,
      );
      grouped.putIfAbsent(day, () => <Activity>[]).add(a);
    }
    final List<DateTime> keys = grouped.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    return <MapEntry<DateTime, List<Activity>>>[
      for (final DateTime k in keys) MapEntry<DateTime, List<Activity>>(k, grouped[k]!),
    ];
  }

  Widget _buildList(BuildContext context, List<Activity> data) {
    final List<MapEntry<DateTime, List<Activity>>> groups = _groupFiltered(
      data,
    );

    if (groups.isEmpty) {
      return Center(
        child: Text(
          _query.isNotEmpty || _typeFilter != null
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
    for (final MapEntry<DateTime, List<Activity>> g in groups) {
      for (final Activity a in g.value) {
        if (a.isTransmit) continue;
        if (a.type == ActivityType.add) {
          income += a.price * a.quantity;
        } else {
          expense -= a.price * a.quantity;
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
        for (final MapEntry<DateTime, List<Activity>> g in groups)
          _DayGroup(date: g.key, actions: g.value),
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
}

/// Группа операций за день.
class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<Activity> actions;

  const _DayGroup({required this.date, required this.actions});

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('d MMMM yyyy', 'ru').format(date);
    // Переводы между своими счетами не влияют на доход/расход дня.
    double dayIncome = 0;
    double dayExpense = 0;
    for (final Activity a in actions) {
      if (a.isTransmit) continue;
      final double v = a.price * a.quantity;
      if (a.type == ActivityType.add) {
        dayIncome += v;
      } else {
        dayExpense += v;
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
        ...actions
            .map<Widget>((Activity a) => _ActivityListItem(activity: a))
            .toList(),
        const Divider(height: 1.0, indent: 16.0, endIndent: 16.0),
      ],
    );
  }
}

/// Строка операции.
class _ActivityListItem extends StatelessWidget {
  final Activity activity;

  const _ActivityListItem({required this.activity});

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
      onTap: () {
        context.push('/activities/${activity.id}');
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
