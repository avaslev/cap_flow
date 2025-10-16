import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventState.dart';
import 'package:investflow/core/utils/calculateNextOccurrence.dart';
import 'package:investflow/feature/event/presentation/form/eventForm.dart';
import 'package:investflow/widgets/itemAvatar.dart';
import 'package:investflow/widgets/itemValue.dart';

class FinancialEventOverviewPage extends StatelessWidget {
  final String accountId;
  FinancialEventOverviewPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    final FinancialEventBloc financialEventBloc = BlocProvider.of<FinancialEventBloc>(context);
    financialEventBloc.add(LoadFinancialEvents(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Планировщик'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить событие',
            onPressed: () {
              _showActionBottomSheet(context, null);
            },
          ),
        ],
      ),
      body: BlocBuilder<FinancialEventBloc, FinancialEventState>(
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
                        'Нет финансовых событий.\nНажмите "+" чтобы добавить новое.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            String getWalletNameById(String walletId) {
              return eventState.wallets.length > 0
                ? eventState.wallets.firstWhere((Wallet w) => w.id == walletId,).name
                : '';
            }

            return ListView.builder(
              itemCount: eventState.events.length,
              itemBuilder: (BuildContext context, int index) {
                final FinancialEvent event = eventState.events[index];
                final String formattedDate = DateFormat(
                  'dd.MM.yyyy',
                ).format(event.date);
                final String sourceWalletName = getWalletNameById(
                  event.walletId,
                );
                String subtitleTextLines =
                    ''; // This will build our multi-line subtitle

                String recurrenceInfoText = '';
                if (event.recurrenceType != RecurrenceType.none) {
                  final DateTime? nextOccurrence = calculateNextOccurrence(
                    initialDate: event.date, 
                    recurrenceType: event.recurrenceType.name, 
                    recurrenceEndDate: event.recurrenceEndDate,
                    recurrenceDayOfMonth: event.recurrenceDayOfMonth,
                    now: DateTime.now()
                  );
                  if (nextOccurrence != null) {
                    recurrenceInfoText =
                        'Следующее: ${DateFormat('dd.MM.yyyy').format(nextOccurrence)}';
                  } else {
                    recurrenceInfoText =
                        'Повторяется: ${event.recurrenceType.displayName} (завершено)';
                  }
                }

                if (event.type == FinancialEventType.transfer &&
                    event.destinationWalletId != null) {
                  final String destinationWalletName = getWalletNameById(
                    event.destinationWalletId!,
                  );
                  subtitleTextLines +=
                      'Перевод: $sourceWalletName -> $destinationWalletName\n${event.category} - $formattedDate';
                } else {
                  subtitleTextLines +=
                      '${event.type.displayName} - ${event.category} ($sourceWalletName)\n$formattedDate';
                }

                // Append recurrence info if available
                if (recurrenceInfoText.isNotEmpty) {
                  subtitleTextLines += '\n$recurrenceInfoText';
                }

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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 30,
                    ),
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
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              child: const Text("Отмена"),
                            ),
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              child: const Text("Удалить"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (DismissDirection direction) {
                    context.read<FinancialEventBloc>().add(
                      DeleteFinancialEvent(event.id),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Событие "${event.name}" удалено'),
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
                      subtitle: Text(
                        subtitleTextLines,
                        style:
                            Theme.of(context).listTileTheme.subtitleTextStyle,
                      ),
                      trailing: ItemValue(type: event.type.name, amount: event.amount),
                      isThreeLine: true,
                      onTap: () => _showActionBottomSheet(context, event),
                    ),
                  ),
                );
              },
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
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showActionBottomSheet(BuildContext context, FinancialEvent? financialEvent) {
    final FinancialEventBloc financialEventBloc = context.read<FinancialEventBloc>();
    final FinancialEventState state = financialEventBloc.state;
    // Check if the state is AccountsDataState before accessing accountData
    if (state is FinancialEventLoaded) {
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<FinancialEventBloc>.value(
                value: financialEventBloc, // Re-provide the existing AccountsBloc
              ),
            ],
            child: FinancialEventForm(event: financialEvent, accountId: state.accountId,),
          );
        },
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ).whenComplete(() {
        financialEventBloc.add(LoadFinancialEvents(state.accountId));
      });
    } else {
      // Handle the case where state is not AccountsDataState, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account data not available.')),
      );
    }
  }
}
