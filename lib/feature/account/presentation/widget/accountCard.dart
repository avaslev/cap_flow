import 'package:bookstore/core/utils/getAccountIcon.dart';
import 'package:bookstore/feature/account/data/accountData.dart';
import 'package:bookstore/feature/account/logic/accountBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatCurrency.dart';

/// A widget to display a single account summary card.
class AccountCard extends StatelessWidget {
  final AccountSummary account;
  final bool isDeletable;

  const AccountCard({
    Key? key,
    required this.account,
    required this.isDeletable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on account data for aesthetics and readability
    final Color cardColor = Color(account.colorValue);
    final Color textColor =
        cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color positiveChangeColor = Theme.of(
      context,
    ).colorScheme.primary.withOpacity(0.8);
    final Color negativeChangeColor = Theme.of(context).colorScheme.error;
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    final canEdit = account.id != 'total';

    return GestureDetector(
      onTap: () {
        accountBloc.add(DisableEditModeAccountCardEvent(account.id));
      },
      onLongPress: () {
            canEdit ? accountBloc.add(EnableEditModeAccountCardEvent(account.id)) : null;
        },
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 110, // Fixed height for each card
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Row(
                  // Row for icon and account name
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      getAccountIcon(account.type),
                      color: textColor.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        account.name,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Expanded(
                      // Use Expanded to prevent overflow for long numbers
                      child: Text(
                        formatCurrency(account.balance),
                        textAlign:
                            TextAlign.start, // Align to start for currency
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'View Account Chart (Not Implemented)',
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.show_chart,
                          color: textColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Text(
                        '${account.dailyChangeAmount >= 0 ? '+' : ''}${formatCurrency(account.dailyChangeAmount)}',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.clip,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              account.dailyChangeAmount >= 0
                                  ? positiveChangeColor
                                  : negativeChangeColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "|",
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.clip,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      Text(
                        '${account.dailyChangePercentage >= 0 ? '+' : ''}${account.dailyChangePercentage.toStringAsFixed(2)}%',
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              account.dailyChangePercentage >= 0
                                  ? positiveChangeColor
                                  : negativeChangeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Display icons at bottom-left when not in delete mode
            if (canEdit && !isDeletable)
              Positioned(
                left: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      account.hideEvents
                          ? Icons.notifications_off
                          : Icons.notifications,
                      color: textColor.withOpacity(0.8),
                      size: 20,
                    ),
                    // New: Icon for 'excludeFromTotal' if true
                    if (account.excludeFromTotal)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.visibility_off,
                          color: textColor.withOpacity(0.8),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            if (canEdit && isDeletable) ...<Widget>[
              Positioned(
                top: -12,
                right: -15, // Rightmost position
                child: IconButton(
                  icon: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                    size: 28,
                  ),
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: Text(
                            'Are you sure you want to delete ${account.name} and all its associated transactions and tools? This action cannot be undone.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(false);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(true);
                              },
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    // if (confirm == true) {
                    //   // accountData.deleteAccount(account.id);
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     SnackBar(
                    //       content: Text(
                    //         '${account.name} deleted successfully.',
                    //       ),
                    //       duration: const Duration(seconds: 1),
                    //     ),
                    //   );
                    // } else {
                    //   accountData
                    //       .clearDeletableAccount(); // Exit delete mode if cancelled
                    // }
                  },
                ),
              ),
              Positioned(
                top: -12,
                right: 25, // To the left of delete button
                child: IconButton(
                  icon: Icon(
                    account.hideEvents
                        ? Icons.notifications_off
                        : Icons.notifications,
                    color: textColor,
                    size: 28,
                  ),
                  onPressed: () {
                    // accountData.toggleHideEvents(account.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Events for ${account.name} are now ${account.hideEvents ? 'hidden' : 'visible'}.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: -12,
                right: 65, // To the left of notification button
                child: IconButton(
                  icon: Icon(
                    account.excludeFromTotal
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: textColor,
                    size: 28,
                  ),
                  onPressed: () {
                    // accountData.toggleExcludeFromTotal(account.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${account.name} is now ${account.excludeFromTotal ? 'excluded from' : 'included in'} Total Balance calculation.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
