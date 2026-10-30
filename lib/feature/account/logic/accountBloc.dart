import 'package:bloc/bloc.dart';
import 'package:capflow/data/models/account.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/typed_tool_mapper.dart';
import 'package:capflow/data/repository/accountRepository.dart';
import 'package:capflow/data/repository/activityRepository.dart';
import 'package:capflow/data/repository/currencyRepository.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/settingsRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/feature/account/data/accountDataState.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// Importing the parts for event and state definitions
part 'event.dart';
part 'state.dart';

class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  ScheduledTransactionRepository _eventRepo = ScheduledTransactionRepository();
  AccountData accountData = AccountData();
  // Constructor initializes the bloc with an initial state
  AccountsBloc() : super(AccountsInitial()) {
    on<AccountsTransitionEvent>((event, emit) async {
      await _refreshAccountData();
      await _refreshTools();
      await _refreshActivities();
      final now = DateTime.now();
      accountData.clearEvents();
      (await _eventRepo.getExecutableEvents(DateTime(now.year, now.month, now.day + 20,
      now.hour, now.minute, now.second, now.millisecond, now.microsecond))).forEach((ScheduledTransaction transaction) {
        accountData.addEvent(
          transaction.id,
          transaction.type,
          transaction.name,
          transaction.comment ?? '',
          transaction.category,
          transaction.accountId,
          transaction.walletId,
          transaction.amount,
          transaction.nextExecutionDate,
          depositToolId: transaction.depositToolId,
        );
      });
      emit(AccountsDataState(accountData));
    });
    on<ChangePageAccountsEvent>((event, emit) async {
      debugPrint("ChangePageAccountsEvent ${event.page}");
      String accountId = accountData.accounts[event.page].id;
      if (accountId == accountData.targetDisplayAccount)
        accountData.setTargetDisplayAccount(null);
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

    on<MoveAccountEvent>((event, emit) async {
      final List<AccountSummary> accounts = accountData.accounts;
      final int idx = accounts.indexWhere(
        (AccountSummary a) => a.id == event.accountId,
      );
      if (idx < 0) return;
      final int otherIdx = event.up ? idx - 1 : idx + 1;
      // Total (index 0) всегда первый — с ним не меняемся.
      if (otherIdx < 1 || otherIdx >= accounts.length) {
        return;
      }

      final AccountSummary moved = accounts[idx];
      final AccountSummary other = accounts[otherIdx];
      final int tmp = moved.sortOrder;
      moved.sortOrder = other.sortOrder;
      other.sortOrder = tmp;
      await AccountRepository().changeSortOrder(moved.id, moved.sortOrder);
      await AccountRepository().changeSortOrder(other.id, other.sortOrder);
      accountData.sortAccounts();
      emit(AccountsDataState(accountData));
    });

    on<AddAccountEvent>((event, emit) async {
      final int maxSortOrder = accountData.accounts
          .where((AccountSummary a) => a.id != 'total')
          .map((AccountSummary a) => a.sortOrder)
          .fold(0, math.max);
      final Account account = Account(
        id: Uuid().v7(),
        name: event.account.name,
        colorValue: event.account.colorValue,
        type: event.account.type.name,
        hideEvents: event.account.hideEvents.toString(),
        excludeFromTotal: event.account.excludeFromTotal.toString(),
        sortOrder: maxSortOrder + 1,
      );
      await AccountRepository().insert(account);
      // Money-тул — в дефолтной валюте из настроек.
      final String defaultCurrency = await SettingsRepository()
          .getDefaultCurrency();
      // Имя тула по умолчанию — название валюты («Рубль», «Доллар США»).
      final String moneyToolName =
          await CurrencyRepository().getName(defaultCurrency);
      final Tool tool = Tool(
        id: Uuid().v7(),
        name: moneyToolName,
        accountId: account.id,
        type: ToolType.money.name,
        ticker: defaultCurrency,
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
            // Валюта активности совпадает с валютой (ticker) Money-тула.
            currency: Activity.currencyFromCode(defaultCurrency),
            isTransmit: true,
            name: 'Create ' + event.account.name,
          ),
        );
      }

      debugPrint("AddAccountEvent ${event.account.name}");
      accountData.setTargetDisplayAccount(account.id);
      accountData.setActiveAccount(account.id);
      await _refreshAccountData();
      await _refreshTools();
      await _refreshActivities();
      emit(AccountsDataState(accountData));
    });

    on<ChangeAccountEvent>((event, emit) async {
      if (true == event.remove) {
        // Полное удаление: тулы, их операции, парные половины переводов,
        // строка счёта и плановые события (с очисткой висячих event_id).
        // Все тулы счёта из БД (включая скрытые: инвест-тула с нулевым
        // количеством и т.п.) — иначе операции на них не будут найдены.
        final List<Tool> allTools = await ToolRepository().geListByAccount(
          event.accountId,
        );

        // Собрать id пар переводов этого счёта до удаления.
        final Set<String> transferPairIds = <String>{};
        for (final Tool tool in allTools) {
          final List<Activity> activities = await ActivityRepository()
              .getActivityListByTool(tool.id);
          for (final Activity a in activities) {
            if (a.transferPairId != null && a.transferPairId!.isNotEmpty) {
              transferPairIds.add(a.transferPairId!);
            }
          }
        }

        // Удалить парные половины переводов (на других счетах).
        for (final String pairId in transferPairIds) {
          await ActivityRepository().deleteByTransferPairId(pairId);
        }

        // Тулы и их операции.
        for (final Tool tool in allTools) {
          await ActivityRepository().deleteByTool(tool.id);
          await ToolRepository().delete(tool.id);
        }

        accountData.deleteAccount(event.accountId);
        await AccountRepository().delete(event.accountId);

        // Плановые события счёта → собрать их id и обнулить ссылки в операциях.
        final List<String> eventIds = await ScheduledTransactionRepository()
            .getIdsByAccount(event.accountId);
        await ScheduledTransactionRepository().deleteByAccount(event.accountId);
        await ActivityRepository().clearEventIds(eventIds);

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
        emit(AccountsDataState(await _refreshAccountData()));
      }
    });

    on<UpdateAccountEvent>((event, emit) async {
      if (event.accountId == 'total') return;
      final String name = event.name.trim();
      if (name.isEmpty) return;
      await AccountRepository().updateAccountDetails(
        event.accountId,
        name: name,
        colorValue: event.colorValue,
        hideEvents: event.hideEvents,
        excludeFromTotal: event.excludeFromTotal,
      );
      accountData.updateAccountDetails(
        event.accountId,
        name: name,
        colorValue: event.colorValue,
        hideEvents: event.hideEvents,
        excludeFromTotal: event.excludeFromTotal,
      );
      emit(AccountsDataState(accountData));
    });

    on<ArchiveAccountEvent>((event, emit) async {
      await AccountRepository().archive(event.accountId);
      accountData.archiveAccount(event.accountId);
      emit(AccountsDataState(accountData));
    });

    on<RestoreAccountEvent>((event, emit) async {
      await AccountRepository().unarchive(event.accountId);
      emit(AccountsDataState(await _refreshAccountData()));
    });
  }

  Future<AccountData> _refreshAccountData() async {
    (await AccountRepository().geList()).forEach((account) async {
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
            isArchived: account.isArchived,
          );

          return accountSummary;
        },
      );
      accountSummary.name = account.name;
      accountSummary.colorValue = account.colorValue;
      accountSummary.hideEvents = bool.parse(account.hideEvents);
      accountSummary.excludeFromTotal = bool.parse(account.excludeFromTotal);
      accountSummary.sortOrder = account.sortOrder;
      accountSummary.isArchived = account.isArchived;
      accountData.addAccount(accountSummary);
    });

    accountData.sortAccounts();
    return accountData;
  }

  Future<AccountData> _refreshTools() async {
    final toolsFromDb = await ToolRepository().geList();
    debugPrint('[_refreshTools] Found ${toolsFromDb.length} tools in DB');

    // Track which tool IDs we saw in DB to know what to remove
    final seenIds = <String>{};

    for (final tool in toolsFromDb) {
      seenIds.add(tool.id);

      // Always create tool with zero values - activity replay will set correct values
      final toolSummary = ToolSummary.fromTyped(typedToolFromDb(tool));
      accountData.addTool(toolSummary);
      debugPrint('[_refreshTools] Tool ${tool.id} (${tool.name}) reset to zero for activity replay');
    }

    // Remove tools that are no longer in DB
    final currentIds = accountData.tools.keys.toSet();
    final toRemove = currentIds.difference(seenIds);
    for (final id in toRemove) {
      final ToolSummary? tool = accountData.tools[id];
      // accountData.tools is a copy — use the real removal, otherwise the
      // deleted tool stays in the list forever (e.g. after deposit closure).
      accountData.removeTool(id);
      debugPrint('[_refreshTools] Removed tool ${id} (${tool?.name}) - no longer in DB');
    }

    return accountData;
  }

  Future<AccountData> _refreshActivities() async {
    Map<String, ToolSummary> toolMap = accountData.tools;
    // Reset all tool values to zero before replaying activities
    for (final tool in toolMap.values) {
      tool.quantity = 0;
      tool.currentValue = 0;
      tool.percentageChange = 0;
    }
    // Reset period turnover (last 30 days) for all accounts before replay.
    final DateTime today = DateTime.now();
    final DateTime periodStart = today.subtract(const Duration(days: 30));
    for (final AccountSummary acc in accountData.accounts) {
      acc.periodIncome = 0;
      acc.periodExpense = 0;
    }
    final activities = await ActivityRepository().getActivityList();
    debugPrint('[_refreshActivities] Found ${activities.length} activities to replay');
    for (final activity in activities) {
      if (toolMap.containsKey(activity.toolId)) {
        final toolSummary = toolMap[activity.toolId]!;
        final double quantityChange =
            activity.quantity * (activity.type == ActivityType.add ? 1 : -1);
        final double valueChange = activity.price * quantityChange;

        // Update the tool with the activity's effect
        toolSummary.quantity += quantityChange;
        toolSummary.currentValue += valueChange;

        // Period turnover (30 days): real money movements of money tools only.
        if (!activity.isTransmit && toolSummary.type == ToolType.money) {
          final DateTime at = activity.createAt;
          final bool inPeriod = at.isAfter(periodStart);
          if (inPeriod) {
            final AccountSummary? acc = accountData.getAccountById(
              toolSummary.accountId,
            );
            if (acc != null) {
              if (activity.type == ActivityType.add) {
                acc.periodIncome += valueChange;
              } else {
                acc.periodExpense += valueChange;
              }
            }
          }
        }

        // Реализованная прибыль/убыток от продажи инвестиций: маркер
        // на туле-инструменте (quantity = 0, сумма в price).
        if (!activity.isTransmit && toolSummary.type != ToolType.money) {
          final String? markerName = activity.name;
          final bool isGain = markerName?.startsWith(
                Activity.investmentGainName,
              ) ??
              false;
          final bool isLoss = markerName?.startsWith(
                Activity.investmentLossName,
              ) ??
              false;
          if ((isGain || isLoss) && activity.price > 0) {
            final DateTime at = activity.createAt;
            final bool inPeriod = at.isAfter(periodStart);
            if (inPeriod) {
              final AccountSummary? acc = accountData.getAccountById(
                toolSummary.accountId,
              );
              if (acc != null) {
                if (isGain) {
                  acc.periodIncome += activity.price;
                } else {
                  acc.periodExpense += activity.price;
                }
              }
            }
          }
        }

        debugPrint('[_refreshActivities] activity ${activity.id}: toolId=${activity.toolId}, ' +
            'qtyChange=${quantityChange.toStringAsFixed(2)}, valueChange=${valueChange.toStringAsFixed(2)}, ' +
            'newQty=${toolSummary.quantity.toStringAsFixed(2)}, newValue=${toolSummary.currentValue.toStringAsFixed(2)}');
        accountData.addTool(toolSummary);
      } else {
        debugPrint('[_refreshActivities] SKIPPED activity ${activity.id}: toolId=${activity.toolId} not found in toolMap');
      }
    }

    return accountData;
  }
}