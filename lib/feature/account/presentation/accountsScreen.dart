import 'package:go_router/go_router.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/logic/addAccountFormCubit.dart';
import 'package:investflow/feature/account/presentation/widget/accountCard.dart';
import 'package:investflow/feature/account/presentation/widget/actionSelectionBottomSheet.dart';
import 'package:investflow/feature/account/presentation/widget/addAccountForm.dart';
import 'package:investflow/feature/account/presentation/widget/eventList.dart';
import 'package:investflow/feature/account/presentation/widget/toolList.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Screen displaying the list of transactions, grouped by day.
class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    accountBloc.add(AccountsTransitionEvent());
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    late PageController _pageController;
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9, // Adjust to show a portion of next/prev cards
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surface,
        title: Text(
          "Accounts",
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.add,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            onPressed: () {
              _showAddAccountForm(context);
            },
          ),
        ],
      ),
      body: BlocBuilder<AccountsBloc, AccountsState>(
        builder: (context, state) {
          if (state is! AccountsDataState) {
            return const CircularProgressIndicator();
          }
          // Find initial page index based on activeAccountId
          int currentPageIndex = state.accountData.accounts.indexWhere(
            (AccountSummary acc) => acc.id == state.accountData.activeAccountId,
          );
          if (currentPageIndex == -1) {
            currentPageIndex = 0; // Default to first account if not found
          }
          // Only animate if the active account changed and PageController is ready
          if (_pageController.hasClients &&
              _pageController.page!.round() != currentPageIndex) {
            _pageController.animateToPage(
              currentPageIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }

          return GestureDetector(
            // Tap anywhere on the body to exit delete mode
            onTap: () {
              accountBloc.add(DisableEditModeAccountCardEvent(null));
            },
            // Add horizontal drag gesture to change active account
            onHorizontalDragEnd: (DragEndDetails details) {
              // If in delete mode, a swipe should just clear delete mode
              // if (accountData.deletableAccountId != null) {
              //   accountData.clearDeletableAccount();
              //   return;
              // }

              // Ensure there's a valid velocity
              if (details.primaryVelocity == null) return;

              // final int currentIndex = _pageController.page?.round() ?? 0;
              // final int numAccounts = accountData.accounts.length;

              // Swipe left (negative velocity) to go to the next account
              if (details.primaryVelocity! < 0) {
                // if (currentIndex < numAccounts - 1) {
                //   _pageController.nextPage(
                //     duration: const Duration(milliseconds: 300),
                //     curve: Curves.easeInOut,
                //   );
                // }
              }
              // Swipe right (positive velocity) to go to the previous account
              else if (details.primaryVelocity! > 0) {
                // if (currentIndex > 0) {
                //   _pageController.previousPage(
                //     duration: const Duration(milliseconds: 300),
                //     curve: Curves.easeInOut,
                //   );
                // }
              }
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 16.0),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                    ), // Horizontal padding handled by PageView's itemBuilder
                    width: MediaQuery.of(context).size.width,
                    height: 150,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged:
                          (int page) => accountBloc.add(
                            ChangePageAccountsEvent(page.round()),
                          ),
                      itemCount: state.accountData.accounts.length,
                      itemBuilder: (context, int index) {
                        final AccountSummary account =
                            state.accountData.accounts[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                          ), // Spacing between cards
                          child: ConstrainedBox(
                            // Limit the maximum width
                            constraints: const BoxConstraints(maxWidth: 400.0),
                            child: AccountCard(
                              account: account,
                              isDeletable: state.accountData.isAccountDeletable(
                                account.id,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (state.accountData.activeAccountId != 'total' &&
                      state.accountData.deletableAccountId ==
                          null) // Show buttons if not 'total' account AND not in delete mode
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'View Events (Not Implemented)',
                                    ),
                                  ),
                                );
                                print('/accounts/${state.accountData.activeAccountId}/events');
                                GoRouter.of(context).go('/accounts/${state.accountData.activeAccountId}/events');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              icon: Icon(
                                Icons.history, // Icon for events/history
                                size: 20,
                                color: colorScheme.onPrimary,
                              ),
                              label: Text(
                                "События", // "Events" in Russian
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge!.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16), // Spacing between buttons
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showActionBottomSheet(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              icon: Icon(
                                Icons.add_circle, // Icon for add action
                                size: 20,
                                color: colorScheme.onSecondary,
                              ),
                              label: Text(
                                "Добавить", // "Add" in Russian
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge!.copyWith(
                                  color: colorScheme.onSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Conditional display for Tools and Events sections
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Financial Tools Section (Displayed for all accounts *except* 'total')
                      if (state.accountData.activeAccountId !=
                          'total') ...<Widget>[
                        ToolList(
                          accountData: state.accountData,
                          accountId: state.accountData.activeAccountId,
                        ),
                      ],
                      // Recent Events Section (Displayed *only* for 'total' account)
                      if (state.accountData.activeAccountId ==
                          'total') ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 24,
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Text(
                            "Последние события", // "Recent Events"
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onBackground,
                            ),
                          ),
                        ),
                        EventList(
                          accountData: state.accountData,
                          maxEvents: 50, // As per original code, total gets 5
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountForm(BuildContext context) {
    final AccountsBloc accountsBloc = context.read<AccountsBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        // Use MultiBlocProvider to provide both the AddAccountFormCubit
        // (a new instance for the form) and the existing AccountsBloc
        // instance to the widget tree of the modal bottom sheet.
        return MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AddAccountFormCubit>(
              create: (BuildContext context) => AddAccountFormCubit(),
            ),
            BlocProvider<AccountsBloc>.value(
              value: accountsBloc, // Re-provide the existing AccountsBloc
            ),
          ],
          child: const AddAccountForm(),
        );
      },
    );
  }

  void _showActionBottomSheet(BuildContext context) {
    final AccountsBloc accountsBloc = context.read<AccountsBloc>();
    final AccountsState state = accountsBloc.state;
    // Check if the state is AccountsDataState before accessing accountData
    if (state is AccountsDataState) {
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AccountsBloc>.value(
                value: accountsBloc, // Re-provide the existing AccountsBloc
              ),
            ],
            child: const ActionSelectionBottomSheet(),
          );
        },
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      );
    } else {
      // Handle the case where state is not AccountsDataState, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account data not available.')),
      );
    }
  }
}
