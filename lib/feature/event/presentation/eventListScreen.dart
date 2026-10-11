import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/data/models/account.dart';
import 'package:investflow/data/repository/accountRepository.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventState.dart';
import 'package:investflow/feature/event/presentation/form/eventForm.dart';
import 'package:investflow/widgets/itemAvatar.dart';
import 'package:investflow/widgets/itemValue.dart';

class FinancialEventOverviewPage extends StatefulWidget {
  final String accountId;
  const FinancialEventOverviewPage({super.key, required this.accountId});

  @override
  State<FinancialEventOverviewPage> createState() =>
      _FinancialEventOverviewPageState();
}

class _FinancialEventOverviewPageState
    extends State<FinancialEventOverviewPage> {
  bool _searchActive = false;
  String _query = '';
  FinancialEventType? _typeFilter;
  String? _accountName;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    // Don't leave stale snackbars (e.g. the delete-Undo one) behind.
    _messenger?.hideCurrentSnackBar();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load events once when the screen opens (not on every rebuild).
    context.read<FinancialEventBloc>().add(
      LoadFinancialEvents(widget.accountId),
    );
    _loadAccountName();
  }

  Future<void> _loadAccountName() async {
    try {
      final Account account = await AccountRepository().get(widget.accountId);
      if (mounted) {
        setState(() => _accountName = account.name);
      }
    } catch (_) {
      // Title simply stays without the account name.
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[FILTER] build typeFilter=$_typeFilter search=$_searchActive');
    final FinancialEventBloc financialEventBloc =
        context.read<FinancialEventBloc>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Планировщик'),
            if (_accountName != null)
              Text(
                _accountName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(
                    alpha: 0.85,
                  ),
                ),
              ),
          ],
        ),
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
            // Explicit child (instead of `icon:`) renders exactly this widget
            // and avoids PopupMenuButton's shared "more button" icon quirk.
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // Active filter gets a subtle white pill; the icon/text inherit
              // the AppBar's foreground so contrast stays readable. (Using
              // colorScheme.primary here was invisible on the primary AppBar.)
              decoration: _typeFilter == null
                  ? null
                  : BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _typeFilter == null ? Icons.filter_list : Icons.filter_alt,
                  ),
                  if (_typeFilter != null) ...<Widget>[
                    const SizedBox(width: 4),
                    Text(
                      _typeFilter!.displayName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            tooltip: 'Фильтр по типу',
            onSelected: (String value) {
              debugPrint('[FILTER] onSelected value=$value');
              setState(() {
                _typeFilter = value == 'all'
                    ? null
                    : FinancialEventType.values.byName(value);
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('Все типы'),
              ),
              ...FinancialEventType.values.map(
                (FinancialEventType type) => PopupMenuItem<String>(
                  value: type.name,
                  child: Text(type.displayName),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить событие',
            onPressed: () =>
                _FinancialEventOverviewPageState.showActionBottomSheet(context, null),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_searchActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                  hintText: 'Поиск по названию или категории',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  isDense: true,
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          Expanded(
            child: BlocBuilder<FinancialEventBloc, FinancialEventState>(
        builder: (BuildContext context, FinancialEventState eventState) {
          if (eventState is FinancialEventLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (eventState is FinancialEventLoaded) {
            if (eventState.events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.event_note,
                        size: 80,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет финансовых событий.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            _FinancialEventOverviewPageState.showActionBottomSheet(
                              context,
                              null,
                            ),
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить событие'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _EventsList(
              eventState: eventState,
              query: _query,
              typeFilter: _typeFilter,
            );
          }
          if (eventState is FinancialEventError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Произошла ошибка: ${eventState.message}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => financialEventBloc.add(
                        LoadFinancialEvents(widget.accountId),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
          ),
        ],
      ),
    );
  }

  static void showActionBottomSheet(
    BuildContext context,
    FinancialEvent? financialEvent,
  ) {
    final FinancialEventBloc financialEventBloc =
        context.read<FinancialEventBloc>();
    final FinancialEventState state = financialEventBloc.state;
    if (state is FinancialEventLoaded) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<FinancialEventBloc>.value(value: financialEventBloc),
            ],
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.5, 0.9, 0.95],
              builder: (context, scrollController) {
                return Padding(
                  // Keep the form above the keyboard.
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: FinancialEventForm(
                      event: financialEvent,
                      accountId: state.accountId,
                      scrollController: scrollController,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ).whenComplete(() {
        financialEventBloc.add(LoadFinancialEvents(state.accountId));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные счёта недоступны.')),
      );
    }
  }
}

/// Groups events by their next occurrence date and renders the grouped list.
class _EventsList extends StatelessWidget {
  final FinancialEventLoaded eventState;
  final String query;
  final FinancialEventType? typeFilter;

  const _EventsList({
    required this.eventState,
    required this.query,
    this.typeFilter,
  });

  /// The authoritative next-occurrence date is [FinancialEvent.date] — it is
  /// the stored `nextExecutionDate` and is advanced by the execution flow.
  DateTime _nextOccurrenceOf(FinancialEvent event) {
    return event.date;
  }

  bool _isFinished(FinancialEvent event) {
    // Finished only when the next execution date is already past the
    // recurrence end date.
    if (event.recurrenceType == RecurrenceType.none) {
      return false;
    }
    return event.recurrenceEndDate != null &&
        event.date.isAfter(event.recurrenceEndDate!);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final String normalizedQuery = query.trim().toLowerCase();

    // Apply search and type filter.
    final List<FinancialEvent> visible = eventState.events.where((
      FinancialEvent event,
    ) {
      if (typeFilter != null && event.type != typeFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return event.name.toLowerCase().contains(normalizedQuery) ||
          event.category.toLowerCase().contains(normalizedQuery);
    }).toList();

    // Sorted by next occurrence date.
    final List<FinancialEvent> sorted = List<FinancialEvent>.of(visible)
      ..sort((FinancialEvent a, FinancialEvent b) {
        final DateTime? na = _nextOccurrenceOf(a);
        final DateTime? nb = _nextOccurrenceOf(b);
        return (na ?? a.date).compareTo(nb ?? b.date);
      });

    if (sorted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Ничего не найдено.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Ordered groups.
    final Map<String, List<FinancialEvent>> groups =
        <String, List<FinancialEvent>>{
          'Просрочено': <FinancialEvent>[],
          'Сегодня': <FinancialEvent>[],
          'На этой неделе': <FinancialEvent>[],
          'Позже': <FinancialEvent>[],
          'Завершённые': <FinancialEvent>[],
        };

    for (final FinancialEvent event in sorted) {
      if (_isFinished(event)) {
        groups['Завершённые']!.add(event);
        continue;
      }
      final DateTime next = _nextOccurrenceOf(event) ?? event.date;
      if (next.isBefore(startOfToday)) {
        groups['Просрочено']!.add(event);
      } else if (next.year == now.year &&
          next.month == now.month &&
          next.day == now.day) {
        groups['Сегодня']!.add(event);
      } else if (next.isBefore(startOfToday.add(const Duration(days: 7)))) {
        groups['На этой неделе']!.add(event);
      } else {
        groups['Позже']!.add(event);
      }
    }

    String getWalletNameById(String walletId) {
      for (final Wallet wallet in eventState.wallets) {
        if (wallet.id == walletId) {
          return wallet.name;
        }
      }
      return '';
    }

    final List<Widget> items = <Widget>[];
    groups.forEach((String title, List<FinancialEvent> list) {
      if (list.isEmpty) {
        return;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: title == 'Просрочено'
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final FinancialEvent event in list) {
        items.add(
          _EventCard(
            event: event,
            getWalletNameById: getWalletNameById,
            startOfToday: startOfToday,
          ),
        );
      }
    });

    return ListView(children: items);
  }
}

/// A single event card with dismiss-to-delete and recurrence status.
class _EventCard extends StatelessWidget {
  final FinancialEvent event;
  final String Function(String walletId) getWalletNameById;
  final DateTime startOfToday;

  const _EventCard({
    required this.event,
    required this.getWalletNameById,
    required this.startOfToday,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String formattedDate = DateFormat('dd.MM.yyyy').format(event.date);
    final String sourceWalletName = getWalletNameById(event.walletId);

    // Meta chips: type · category · wallet (or transfer route).
    final List<String> chipLabels = <String>[
      if (event.type == FinancialEventType.transfer &&
          event.destinationWalletId != null)
        'Перевод: $sourceWalletName → ${getWalletNameById(event.destinationWalletId!)}'
      else ...<String>[
        event.type.displayName,
        if (event.category.isNotEmpty) event.category,
        if (sourceWalletName.isNotEmpty) sourceWalletName,
      ],
    ];

    // Recurrence badge and validity line. The badge is based on event.date —
    // the stored nextExecutionDate advanced by the execution flow.
    String? badgeText;
    Color? badgeColor;
    String? validUntilText;

    if (event.recurrenceType != RecurrenceType.none) {
      if (event.recurrenceEndDate != null) {
        validUntilText =
            'Актуально до ${DateFormat('dd.MM.yyyy').format(event.recurrenceEndDate!)}';
      }

      final bool finished =
          event.recurrenceEndDate != null &&
          event.date.isAfter(event.recurrenceEndDate!);
      if (finished) {
        badgeText = 'Завершено';
        badgeColor = colorScheme.onSurfaceVariant;
      } else {
        final int days =
            DateTime(
              event.date.year,
              event.date.month,
              event.date.day,
            ).difference(startOfToday).inDays;
        if (days < 0) {
          badgeText = 'Просрочено на ${-days} дн.';
          badgeColor = colorScheme.error;
        } else if (days == 0) {
          badgeText = 'Сегодня';
          badgeColor = colorScheme.primary;
        } else {
          badgeText = 'Через $days дн.';
          badgeColor = colorScheme.secondary;
        }
      }
    }

    final Widget subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String label in chipLabels)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formattedDate,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (validUntilText != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            validUntilText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (badgeText != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            badgeText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    return Dismissible(
      key: ValueKey<String>(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12.0),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (DismissDirection direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Подтверждение удаления"),
              content: const Text(
                "Вы уверены, что хотите удалить это событие навсегда?",
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Отмена"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text("Удалить"),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (DismissDirection direction) {
        final FinancialEventBloc bloc = context.read<FinancialEventBloc>();
        bloc.add(DeleteFinancialEvent(event.id));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Событие "${event.name}" удалено'),
              action: SnackBarAction(
                label: 'Отменить',
                onPressed: () =>
                    bloc.add(const UndoDeleteFinancialEvent()),
              ),
            ),
          );
      },
      child: Card(
        child: ListTile(
          leading: ItemAvatar(type: event.type.name),
          title: Text(
            event.name,
            style: Theme.of(context).listTileTheme.titleTextStyle,
          ),
          subtitle: subtitle,
          trailing: ItemValue(type: event.type.name, amount: event.amount),
          isThreeLine: true,
          onTap: () {
            _FinancialEventOverviewPageState.showActionBottomSheet(context, event);
          },
        ),
      ),
    );
  }
}
