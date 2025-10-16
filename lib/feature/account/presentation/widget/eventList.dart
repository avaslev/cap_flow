import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investflow/feature/account/data/activityState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/presentation/widget/form/activity.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventState.dart';
import 'package:investflow/widgets/itemAvatar.dart';
import 'package:investflow/widgets/itemValue.dart';

/// A widget to display a list of financial events.
class EventList extends StatelessWidget {
  final AccountData accountData;
  final int maxEvents;

  const EventList({
    Key? key,
    required this.accountData,
    this.maxEvents = 10, // Changed default to showing top 10 events
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Event> events = accountData.allEvents;

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No recent events to display.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // To allow parent SingleChildScrollView to scroll
      itemCount: events.length > maxEvents ? maxEvents : events.length,
      itemBuilder: (BuildContext context, int index) {
        final Event event = events[index];
        return EventTile(event: event, accountData: accountData);
      },
    );
  }
}

/// A widget to display a single financial event/transaction.
class EventTile extends StatelessWidget {
  final Event event;
  final AccountData accountData;

  const EventTile({Key? key, required this.event, required this.accountData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String accountName = accountData.getAccountById(event.accountId)?.name ?? "Unknown";
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: ItemAvatar(type: event.eventType),
        title: Text(
          event.name,
          style: Theme.of(context).listTileTheme.titleTextStyle,
        ),
        subtitle: Text(
          '${event.description.isEmpty ? '' : event.description + ', '}${DateFormat('MMM d, yyyy').format(event.date)} ',
          style: Theme.of(context).listTileTheme.subtitleTextStyle,
        ),
        trailing: ItemValue(type: event.eventType, amount: event.amount),
        isThreeLine: true,
        onTap: () => _showActionBottomSheet(context, event),
      ),
    );
  }

  void _showActionBottomSheet(BuildContext context, Event financialEvent) {
    final AccountsBloc accountsBloc = context.read<AccountsBloc>();
    
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AccountsBloc>.value(
              value: accountsBloc, // Re-provide the existing AccountsBloc
            ),
          ],
          child: switch(event.eventType) {
            'income' => ActivityForm(accountData: accountData, activityStateType: ActivityStateType.add, event: event),
            'expense' => ActivityForm(accountData: accountData, activityStateType: ActivityStateType.substract, event: event),
            // 'transfer' => ActivityForm(accountData: accountData, activityStateType: ActivityStateType.substract,),
            String() => throw UnimplementedError(),
          }
        );
      },
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
    ).whenComplete(() {
      accountsBloc.add(AccountsTransitionEvent());
    });
  }
}
