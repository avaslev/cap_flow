import 'package:bloc/bloc.dart';
import 'package:bookstore/feature/account/data/accountData.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

// Importing the parts for event and state definitions
part 'event.dart';
part 'state.dart';


class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  final AccountData accountData = AccountData();
  // Constructor initializes the bloc with an initial state
  AccountsBloc() : super(AccountsInitial()) {
    on<AccountsTransitionEvent>((event, emit) {
      emit(AccountsDataState(accountData));
    });
    on<ChangePageAccountsEvent>((event, emit) {
      accountData.setActiveAccount(accountData.accounts[event.page].id);
      emit(AccountsDataState(accountData));
    });

    on<DisableEditModeAccountCardEvent>((event, emit) {
      debugPrint("DisableEditModeAccountCardEvent edit ${event.accountId}");
      accountData.clearDeletableAccount();
      if (event.accountId != null) accountData.setActiveAccount(event.accountId ?? '');
      emit(AccountsDataState(accountData));
    });

    
    on<EnableEditModeAccountCardEvent>((event, emit) {
      debugPrint("EnableEditModeAccountCardEvent edit ${event.accountId}");
      accountData.setDeletableAccount(event.accountId);
      emit(AccountsDataState(accountData));
    });

    on<AddAccountEvent>((event, emit) {
      debugPrint("AddAccountEvent ${event.account.name}");
      emit(AccountsDataState(accountData));
    });

    on<ChangeAccountEvent>((event, emit) {
      debugPrint("ChangeAccountEvent ${event.accountId}");
      emit(AccountsDataState(accountData));
    });
  }
}
