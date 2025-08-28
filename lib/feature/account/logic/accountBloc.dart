import 'package:bloc/bloc.dart';
import 'package:bookstore/data/models/account.dart';
import 'package:bookstore/data/models/activity.dart';
import 'package:bookstore/data/models/tool.dart';
import 'package:bookstore/data/repository/accountRepository.dart';
import 'package:bookstore/data/repository/activityRepository.dart';
import 'package:bookstore/data/repository/toolRepository.dart';
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
      await _refreshAccountData();
      emit(AccountsDataState(accountData));
    });
    on<ChangePageAccountsEvent>((event, emit) async {
      debugPrint("ChangePageAccountsEvent ${event.page}");
      String accountId = accountData.accounts[event.page].id;
      if (accountId == accountData.targetDisplayAccount) accountData.setTargetDisplayAccount(null);
      if (null != accountData.targetDisplayAccount) return;
      accountData.setActiveAccount(accountId);
      emit(AccountsDataState(accountData));
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
      final Tool tool = Tool(
        id: Uuid().v7(),
        name: 'Money',
        accountId: account.id,
        type: ToolType.money.name,
        quantity: event.account.balance,
        price: 1,
        ticker: Currency.RUB.name,
      );
      await ToolRepository().insert(tool);

      if (event.account.balance > 0) {
        await ActivityRepository().insert(
          Activity(
            id: Uuid().v7(),
            toolId: tool.id,
            type: ActivityType.add,
            createAt: DateTime.now(),
            quantity: event.account.balance,
            price: 1,
            currency: Currency.RUB,
            isTransmit: true,
          ),
        );
      }

      debugPrint("AddAccountEvent ${event.account.name}");
      accountData.setTargetDisplayAccount(account.id);
      accountData.setActiveAccount(account.id);
      await _refreshAccountData();
      emit(AccountsDataState(accountData));
    });

    on<ChangeAccountEvent>((event, emit) async {
      debugPrint("ChangeAccountEvent ${event.hideEvents}");
      if (event.remove) {
        accountData.deleteAccount(event.accountId);
        await AccountRepository().delete(event.accountId);
        accountData.getToolsForAccount(event.accountId).forEach((ToolSummary toolSummary) async {
          if (null != toolSummary.id) {
            await ActivityRepository().deleteByTool(toolSummary.id ?? '');
            await ToolRepository().delete(toolSummary.id ?? '');
          }
        });
        emit(AccountsDataState(accountData));
      } else {
        await AccountRepository().changeHideEvents(
          event.accountId,
          event.hideEvents,
        );
        await AccountRepository().changeExcludeFromTotal(
          event.accountId,
          event.excludeFromTotal,
        );
        await _refreshAccountData();
        emit(AccountsDataState(accountData));
      }
    });
  }

  Future<AccountData> _refreshAccountData() async {
    for (final Account account in (await AccountRepository().geList())) {
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
      await _refreshToolsByAccount(accountSummary.id);
    }

    return accountData;
  }

  Future<AccountData> _refreshToolsByAccount(String accountId) async {
    for (final Tool tool in (await ToolRepository().geListByAccount(accountId))) {
      ToolSummary toolSummary = accountData.getToolsForAccount(accountId).firstWhere(
        (t) => t.id == tool.id,
        orElse: () {
          ToolSummary toolSummary = ToolSummary(
            id: tool.id,
            name: tool.name,
            quantity: tool.quantity, 
            percentageChange: 0, 
            accountId: accountId, 
            type: ToolType.values.byName(tool.type), 
            currentValue: tool.quantity*tool.price,
          );
          accountData.addTool(toolSummary);
          return toolSummary;
        },
      );
      toolSummary.quantity = tool.quantity;
      toolSummary.currentValue = tool.quantity*tool.price;
    }

    return accountData;
  }
}
