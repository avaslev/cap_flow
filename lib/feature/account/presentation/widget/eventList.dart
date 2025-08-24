import 'package:bookstore/core/utils/formatCurrency.dart';
import 'package:bookstore/feature/account/data/accountData.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  const EventTile({
    Key? key,
    required this.event,
    required this.accountData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String accountName =
        accountData.getAccountById(event.accountId)?.name ?? "Unknown";
    final bool isPastEvent = event.date.isBefore(DateTime.now());
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0, // Flat design
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      // Highlight past events with a distinct background color
      color: isPastEvent ? colorScheme.surfaceVariant : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: <Widget>[
            Icon(
              event.isCredit ? Icons.arrow_upward : Icons.arrow_downward,
              color: event.isCredit ? colorScheme.primary : colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(event.date)} - $accountName',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${event.isCredit ? '+' : '-'}${formatCurrency(event.amount.abs())}',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: event.isCredit
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
