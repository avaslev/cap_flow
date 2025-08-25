import 'package:bloc/bloc.dart';
import 'package:bookstore/data/models/account.dart';
import 'package:bookstore/data/repository/accountRepository.dart';
import 'package:bookstore/feature/account/data/accountDataState.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

// Importing the parts for event and state definitions
part 'event.dart';
part 'state.dart';

class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  final AccountData accountData = AccountData();
  // Constructor initializes the bloc with an initial state
  AccountsBloc() : super(AccountsInitial()) {
    on<AccountsTransitionEvent>((event, emit) async {
      emit(AccountsDataState(await _refreshAccountData(null)));
    });
    on<ChangePageAccountsEvent>((event, emit) async {
      debugPrint("ChangePageAccountsEvent ${event.page}");
      emit(
        AccountsDataState(
          await _refreshAccountData(accountData.accounts[event.page].id),
        ),
      );
    });

    on<DisableEditModeAccountCardEvent>((event, emit) async {
      accountData.clearDeletableAccount();
      emit(AccountsDataState(accountData));
    });

    on<EnableEditModeAccountCardEvent>((event, emit) async {
      accountData.setDeletableAccount(event.accountId);
      emit(AccountsDataState(accountData));
    });

    on<AddAccountEvent>((event, emit) async {
      final Account account = Account(
        id: Uuid().v7(),
        name: event.account.name,
        colorValue: event.account.colorValue,
        type: event.account.type.name,
        hideEvents: event.account.hideEvents.toString(),
        excludeFromTotal: event.account.excludeFromTotal.toString(),
      );
      await AccountRepository().insert(account);
      debugPrint("AddAccountEvent ${event.account.name}");
      emit(AccountsDataState(await _refreshAccountData(account.id)));
    });

    on<ChangeAccountEvent>((event, emit) async {
      debugPrint("ChangeAccountEvent ${event.hideEvents}");
      if (event.remove) {
        accountData.deleteAccount(event.accountId);
        await AccountRepository().delete(event.accountId);
        emit(AccountsDataState(await _refreshAccountData('total')));
      } else {
        await AccountRepository().changeHideEvents(
          event.accountId,
          event.hideEvents,
        );
        await AccountRepository().changeExcludeFromTotal(
          event.accountId,
          event.excludeFromTotal,
        );
        emit(AccountsDataState(await _refreshAccountData(event.accountId)));
      }
    });
  }

  Future<AccountData> _refreshAccountData(String? activeAccountId) async {
    final list = await AccountRepository().geList();
    for (final Account account in list) {
      AccountSummary accountSummary = accountData.accounts.firstWhere(
        (a) => a.id == account.id,
        orElse: () {
          debugPrint("_refreshAccountData new ${account.id}");
          AccountSummary accountSummary = AccountSummary(
            id: account.id,
            name: account.name,
            balance: 0,
            dailyChangeAmount: 0.0,
            dailyChangePercentage: 0.0,
            colorValue: account.colorValue,
            type: AccountType.values.byName(account.type),
            hideEvents: bool.parse(account.hideEvents),
            excludeFromTotal: bool.parse(account.excludeFromTotal),
          );
          accountData.addAccount(accountSummary);

          return accountSummary;
        },
      );
      accountSummary.hideEvents = bool.parse(account.hideEvents);
      accountSummary.excludeFromTotal = bool.parse(account.excludeFromTotal);
    }

    if (null != activeAccountId)
      accountData.setActiveAccount(activeAccountId.toString());

    return accountData;
  }
}
