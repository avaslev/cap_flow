import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/activityState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/presentation/widget/form/activity.dart';
import 'package:investflow/feature/account/presentation/widget/form/transfer.dart';
import 'package:investflow/feature/account/presentation/widget/form/credit.dart';
import 'package:investflow/feature/account/presentation/widget/form/money.dart';
import 'package:investflow/feature/account/presentation/widget/form/other.dart';
import 'package:investflow/feature/account/presentation/widget/form/deposit.dart';
import 'package:investflow/feature/account/presentation/widget/form/investment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A modal bottom sheet for selecting a financial action.
class ActionSelectionBottomSheet extends StatelessWidget {
  const ActionSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (context, state) {
        if (state is! AccountsDataState) {
          return const CircularProgressIndicator();
        }
        final accountData = state.accountData;
        final String activeAccountId = accountData.activeAccountId;
        final AccountSummary? activeAccount = accountData.getAccountById(
          accountData.activeAccountId,
        );
        final bool isGeneralAccount =
            activeAccount != null && activeAccount.type == AccountType.general;
        final bool isBrokerageAccount =
            activeAccount != null &&
            activeAccount.type == AccountType.brokerage;
        final bool isCryptocurrencyAccount = // NEW
            activeAccount != null &&
            activeAccount.type == AccountType.cryptocurrency;
        final bool hasMoneyTools =
            accountData
                .getMoneyToolsForAccount(accountData.activeAccountId)
                .isNotEmpty;

        _onTap(Widget form) {
          final accountsBloc = BlocProvider.of<AccountsBloc>(context);
          Navigator.pop(context); // Close the bottom sheet
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext context) => BlocProvider<AccountsBloc>.value(
              value: accountsBloc,
              child: form,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
          ).then((void value) {
            accountBloc.add(AccountsTransitionEvent());
          });
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Choose Action",
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.arrow_upward,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    "Доход (Income)",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _onTap(ActivityForm(accountData: accountData, activityStateType: ActivityStateType.add,)),
                ),
                ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    "Расход (Expense)",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _onTap(ActivityForm(accountData: accountData, activityStateType: ActivityStateType.substract,)),
                ),
                if (hasMoneyTools) // Conditionally show Transfer action
                  ListTile(
                    leading: Icon(
                      Icons.swap_horiz,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Перевод (Transfer)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(TransferForm(accountData: accountData)),
                  ),
                if (isGeneralAccount && hasMoneyTools)
                  ListTile(
                    leading: Icon(
                      Icons.currency_exchange,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Добавить деньги (валюту)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: MoneyForm(
                              accountData: accountData,
                              accountId: activeAccountId,
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      ).then((_) {
                        accountBloc.add(AccountsTransitionEvent());
                      });
                    },
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.savings,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить депозит", // Add Deposit
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return DepositForm(
                            accountData: accountData,
                            accountId: activeAccountId,
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      ).then((_) {
                        // Refresh so the new deposit shows up immediately.
                        accountBloc.add(AccountsTransitionEvent());
                      });
                    },
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.credit_score,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить кредит",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: CreditForm(
                              accountData: accountData,
                              accountId: activeAccountId,
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      ).then((_) {
                        accountBloc.add(AccountsTransitionEvent());
                      });
                    },
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.category,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить прочее (актив)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return OtherForm(
                            accountData: accountData,
                            accountId: activeAccountId,
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      ).then((_) {
                        accountBloc.add(AccountsTransitionEvent());
                      });
                    },
                  ),
                if (isBrokerageAccount) ...<Widget>[
                  // New: Actions for Brokerage accounts
                  ListTile(
                    leading: Icon(
                      Icons.add_shopping_cart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Акции (Buy Stocks)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.stocks,
                      )),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.sell,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Акции (Sell Stocks)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.stocks,
                      )),
                  ),
                  // New: Bond Actions
                  ListTile(
                    leading: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Облигации (Buy Bonds)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.bonds,
                      )),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.money_off_csred,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Облигации (Sell Bonds)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.bonds,
                      )),
                  ),
                ],
                // NEW: Cryptocurrency Actions
                if (isCryptocurrencyAccount) ...<Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.currency_bitcoin,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Криптовалюту (Buy Crypto)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.cryptocurrency,
                      )),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.currency_yen, // Using yen for selling crypto
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Криптовалюту (Sell Crypto)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.cryptocurrency,
                      )),
                  ),
                ],
                ListTile(
                  leading: Icon(
                    Icons.list_alt,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    "Посмотреть активности по счету",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('View account activities selected'),
                      ),
                    );
                    // TODO: Implement navigation to All Events screen (or specific account events)
                  },
                ),
                const SizedBox(height: 8.0), // Some bottom padding
              ],
            ),
          ),
        );
      },
    );
  }
}
