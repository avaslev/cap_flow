import 'package:go_router/go_router.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/logic/addAccountFormCubit.dart';
import 'package:investflow/feature/account/presentation/widget/accountCard.dart';
import 'package:investflow/feature/account/presentation/widget/actionSelectionBottomSheet.dart';
import 'package:investflow/feature/account/presentation/widget/addAccountForm.dart';
import 'package:investflow/feature/account/presentation/widget/eventList.dart';
import 'package:investflow/feature/account/presentation/widget/toolList.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Screen displaying the list of transactions, grouped by day.
class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  late final PageController _pageController = PageController(
    initialPage: 0,
    viewportFraction: 0.9, // Adjust to show a portion of next/prev cards
  );

  double? _dragStartPixels;

  /// Accumulated horizontal delta of the current drag (sign: left = negative).
  double _dragTotalDelta = 0;

  /// True while the user is swiping (or the resulting settle animation is
  /// running). Prevents the auto-sync in build() from fighting the drag.
  bool _isUserSwiping = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    accountBloc.add(AccountsTransitionEvent());
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

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
            return const Center(child: CircularProgressIndicator());
          }
          // Find initial page index based on activeAccountId
          int currentPageIndex = state.accountData.accounts.indexWhere(
            (AccountSummary acc) => acc.id == state.accountData.activeAccountId,
          );
          if (currentPageIndex == -1) {
            currentPageIndex = 0; // Default to first account if not found
          }
          // Only animate if the active account changed externally (not while
          // the user is swiping — otherwise the auto-sync fights the drag
          // and the carousel jitters).
          if (_pageController.hasClients &&
              !_isUserSwiping &&
              _pageController.page!.round() != currentPageIndex) {
            _pageController.animateToPage(
              currentPageIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }

          // Структура: карусель счетов — фиксированная зона (вне прокрутки),
          // контент счёта — отдельная прокручиваемая зона. Так вертикальный
          // скролл не двигает карусель (нет дрожания), а горизонтальный свайп
          // меняет счёт.
          return Column(
            children: <Widget>[
              // Карусель: свайп влево/вправо меняет счёт.
              Container(
                margin: const EdgeInsets.only(top: 16.0),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                width: MediaQuery.of(context).size.width,
                height: 178,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400.0),
                        child: AccountCard(
                          account: account,
                          isDeletable: state.accountData.isAccountDeletable(
                            account.id,
                          ),
                          toolCounts: state.accountData.toolCountsFor(
                            account.id,
                          ),
                          canMoveUp: index > 1,
                          canMoveDown:
                              index < state.accountData.accounts.length - 1,
                          onMoveUp: () => accountBloc.add(
                            MoveAccountEvent(account.id, up: true),
                          ),
                          onMoveDown: () => accountBloc.add(
                            MoveAccountEvent(account.id, up: false),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Нижняя зона: вертикальный скролл; горизонтальный свайп меняет
              // счёт только по завершении жеста (без дрожания карусели).
              Expanded(
                child: GestureDetector(
                  // Absorb hits in empty areas; tap exits delete mode.
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    accountBloc.add(DisableEditModeAccountCardEvent(null));
                  },
                  onHorizontalDragEnd: (DragEndDetails details) {
                    if (!_pageController.hasClients) return;
                    final double? page = _pageController.page;
                    if (page == null) return;
                    final int accountsCount =
                        state.accountData.accounts.length;
                    int targetPage = page.round();
                    final double velocity = details.primaryVelocity ?? 0;
                    if (velocity < -kMinFlingVelocity) {
                      targetPage = page.floor() + 1;
                    } else if (velocity > kMinFlingVelocity) {
                      targetPage = page.ceil() - 1;
                    }
                    _pageController.animateToPage(
                      targetPage.clamp(0, accountsCount - 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (state.accountData.activeAccountId != 'total' &&
                            state.accountData.deletableAccountId == null)
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
                                      GoRouter.of(context).push(
                                        '/accounts/${state.accountData.activeAccountId}/events',
                                      );
                                    },
                                    icon: const Icon(Icons.history, size: 20),
                                    label: Text(
                                      'События',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _showActionBottomSheet(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                    ),
                                    icon: const Icon(
                                      Icons.add_circle,
                                      size: 20,
                                    ),
                                    label: Text(
                                      'Добавить',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(
                                            color: colorScheme.onSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Total: последние события; обычный счёт: тула.
                        if (state.accountData.activeAccountId == 'total')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Последние события',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                          ),
                        if (state.accountData.activeAccountId == 'total')
                          EventList(
                            accountData: state.accountData,
                            maxEvents: 50,
                          ),
                        if (state.accountData.activeAccountId != 'total')
                          ToolList(
                            accountData: state.accountData,
                            accountId: state.accountData.activeAccountId,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
      Toast.show(context, 'Account data not available.');
    }
  }
}
