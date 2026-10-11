import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/data/models/tools/tool_kind.dart';
import 'package:uuid/uuid.dart';
import 'package:investflow/feature/tools/domain/tool_valuation.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';
import 'package:uuid/uuid.dart';

/// Repository for tool detail operations.
///
/// This repository provides methods to fetch tool details while
/// maintaining isolation from other modules.
class ToolDetailRepository {
  final ToolRepository _repo = ToolRepository();
  final ActivityRepository _activityRepo = ActivityRepository();
  final ScheduledTransactionRepository _scheduledRepo =
      ScheduledTransactionRepository();

  /// Gets a tool by its ID and converts it to display format.
  Future<ToolDetailDisplay> get(String toolId) async {
    // Fetch the tool from the database
    final tool = await _repo.get(toolId);

    // Fetch all activities for this tool to calculate quantity and currentValue
    final activities = await _activityRepo.getActivityListByTool(toolId);

    // Calculate total quantity and current value by replaying activities
    double totalQuantity = 0.0;
    double currentValue = 0.0;

    for (final activity in activities) {
      final quantityChange = activity.quantity *
          (activity.type == ActivityType.add ? 1 : -1);
      final valueChange = activity.price * quantityChange;

      totalQuantity += quantityChange;
      currentValue += valueChange;
    }

    // For stocks and bonds, calculate percentage change based on last price
    double percentageChange = 0.0;
    if (tool.type == 'STOCK' && activities.isNotEmpty) {
      // Get the last activity for price comparison
      final sortedActivities = List<Activity>.from(activities)..sort(
        (a, b) => b.createAt.compareTo(a.createAt),
      );
      final latestActivity = sortedActivities.first;

      // Calculate percentage change from initial to current value
      if (totalQuantity > 0 && latestActivity.price > 0) {
        final avgPrice = currentValue / totalQuantity;
        final initialPrice = latestActivity.price; // Simplified - using latest price as reference
        percentageChange = ((avgPrice - initialPrice) / initialPrice) * 100;
      }
    } else if (tool.type == 'BOND' && totalQuantity > 0) {
      // For bonds, calculate yield based on current value vs face value
      percentageChange = ((currentValue / totalQuantity) - (tool.faceValue ?? 0)) / (tool.faceValue ?? 0) * 100;
    }

    return ToolDetailDisplay(
      id: tool.id,
      name: tool.name,
      quantity: totalQuantity,
      percentageChange: percentageChange,
      accountId: tool.accountId,
      type: tool.type.toUpperCase(),
      currentValue: currentValue,
      ticker: tool.ticker,
      startDate: tool.startDate,
      endDate: tool.endDate,
      interestRate: tool.interestRate,
      faceValue: tool.faceValue,
      paymentDayOfMonth: tool.paymentDayOfMonth,
    );
  }

  /// Gets a tool by its ID as a plain Tool object.
  Future<Tool> getTool(String toolId) async {
    return await _repo.get(toolId);
  }

  /// Gets tool type as a string for use in display.
  String getToolTypeString(String type) {
    return type;
  }

  /// Closes a deposit: transfers the full payout (principal + accrued
  /// interest) to the first money tool of the account, then removes the
  /// deposit tool together with its activity history.
  ///
  /// Returns the transferred amount. Throws if the account has no money tool.
  Future<double> closeDepositAndTransferToMoney({
    required String depositToolId,
    required String depositName,
    required String accountId,
    required double principal,
    required double interestRate,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final List<Tool> accountTools = await _repo.geListByAccount(accountId);
    final List<Tool> moneyTools = accountTools
        .where((Tool t) => t.type == ToolType.money.name)
        .toList();
    if (moneyTools.isEmpty) {
      throw Exception('На счёте нет денежного тула для зачисления.');
    }
    final Tool money = moneyTools.first;

    final double payout = depositValue(
      principal: principal,
      annualRate: interestRate,
      startDate: startDate,
      endDate: endDate,
      asOf: DateTime.now(),
    );
    final DateTime now = DateTime.now();
    final String closeName = 'Закрытие депозита «$depositName»';

    // Both records stay in history (like a fully sold stock): the deposit
    // tool remains with zero value.
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: money.id,
        type: ActivityType.add,
        createAt: now,
        quantity: payout,
        price: 1,
        currency: Currency.RUB,
        // Внутреннее перемещение (депозит → деньги), не доход.
        isTransmit: true,
        name: closeName,
      ),
    );
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: depositToolId,
        type: ActivityType.substract,
        createAt: now,
        quantity: payout,
        price: 1,
        currency: Currency.RUB,
        // Внутреннее перемещение — не расход.
        isTransmit: true,
        name: closeName,
      ),
    );
    // Mark closed instead of deleting: history stays, lists hide the tool.
    final Tool depositRow = await _repo.get(depositToolId);
    await _repo.update(depositRow.copyWith(isClosed: true));
    // Remove the linked interest schedule from the planner.
    await _scheduledRepo.deleteByDepositTool(depositToolId);
    return payout;
  }

  /// Closes a credit: the outstanding debt is paid from the first money
  /// tool of the account, the payment schedule is removed, and the credit
  /// tool is marked closed (history kept).
  ///
  /// Returns the paid outstanding amount.
  Future<double> closeCreditAndRemoveSchedule({
    required String creditToolId,
    required String creditName,
    required String accountId,
  }) async {
    final List<Tool> accountTools = await _repo.geListByAccount(accountId);
    final List<Tool> moneyTools = accountTools
        .where((Tool t) => t.type == ToolType.money.name)
        .toList();
    if (moneyTools.isEmpty) {
      throw Exception('На счёте нет денежного тула для списания.');
    }
    final Tool money = moneyTools.first;

    // Outstanding debt = |replayed credit tool value|.
    final List<Activity> creditActivities = await _activityRepo
        .getActivityListByTool(creditToolId);
    double outstanding = 0;
    for (final Activity a in creditActivities) {
      outstanding += (a.type == ActivityType.add ? 1 : -1) * a.price * a.quantity;
    }
    outstanding = outstanding.abs();

    final DateTime now = DateTime.now();
    final String closeName = 'Закрытие кредита «$creditName»';

    // Pay the outstanding body from cash.
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: money.id,
        type: ActivityType.substract,
        createAt: now,
        quantity: outstanding,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true,
        name: closeName,
      ),
    );
    // Liability goes to zero.
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: creditToolId,
        type: ActivityType.add,
        createAt: now,
        quantity: outstanding,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true,
        name: closeName,
      ),
    );
    // Remove the payment schedule.
    await _scheduledRepo.deleteByDepositTool(creditToolId);
    // Mark closed.
    final Tool row = await _repo.get(creditToolId);
    await _repo.update(row.copyWith(isClosed: true));
    return outstanding;
  }

  /// Переоценка тула «прочее»: стоимость доводится до [newValue] дельтой
  /// (add/substract активити), replay даёт ровно [newValue].
  /// Возвращает применённую дельту (со знаком).
  Future<double> revalueOtherTool({
    required String toolId,
    required double newValue,
  }) async {
    final Tool tool = await _repo.get(toolId);
    final List<Activity> activities = await _activityRepo.getActivityListByTool(
      toolId,
    );
    double current = 0;
    for (final Activity a in activities) {
      current += (a.type == ActivityType.add ? 1 : -1) * a.price * a.quantity;
    }
    final double delta = newValue - current;
    if (delta == 0) return 0;

    final DateTime now = DateTime.now();
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: toolId,
        type: delta > 0 ? ActivityType.add : ActivityType.substract,
        createAt: now,
        quantity: 1,
        price: delta.abs(),
        currency: Currency.RUB,
        isTransmit: true, // переоценка — не доход/расход
        name: 'Переоценка «${tool.name}»',
      ),
    );
    return delta;
  }

  /// Продажа актива «прочее»: деньги зачисляются на первый money-тул
  /// счёта, актив помечается закрытым (история сохраняется).
  /// Возвращает фактически зачисленную сумму.
  Future<double> sellOtherTool({
    required String toolId,
    required String toolName,
    required String accountId,
    double? salePrice,
  }) async {
    // Текущая стоимость = replay активити тула.
    final List<Activity> activities = await _activityRepo
        .getActivityListByTool(toolId);
    double current = 0;
    for (final Activity a in activities) {
      current += (a.type == ActivityType.add ? 1 : -1) * a.price * a.quantity;
    }
    current = current.abs();
    final double price = salePrice ?? current;

    final List<Tool> accountTools = await _repo.geListByAccount(accountId);
    final List<Tool> moneyTools = accountTools
        .where((Tool t) => t.type == ToolType.money.name)
        .toList();
    if (moneyTools.isEmpty) {
      throw Exception('На счёте нет денежного тула для зачисления.');
    }
    final Tool money = moneyTools.first;

    final DateTime now = DateTime.now();
    final String closeName = 'Продажа актива «$toolName»';

    // Актив обнуляется...
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: toolId,
        type: ActivityType.substract,
        createAt: now,
        quantity: 1,
        price: current,
        currency: Currency.RUB,
        isTransmit: true,
        name: closeName,
      ),
    );
    // ...деньги зачисляются на money-тул (по цене продажи).
    await _activityRepo.insert(
      Activity(
        id: const Uuid().v7(),
        toolId: money.id,
        type: ActivityType.add,
        createAt: now,
        quantity: price,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true,
        name: closeName,
      ),
    );
    // Актив закрывается (история сохраняется).
    final Tool row = await _repo.get(toolId);
    await _repo.update(row.copyWith(isClosed: true));
    return price;
  }

  /// Activities of a tool, newest first.
  Future<List<Activity>> getActivitiesForTool(String toolId) async {
    final List<Activity> list = await _activityRepo.getActivityListByTool(toolId);
    final List<Activity> sorted = List<Activity>.from(list)
      ..sort((Activity a, Activity b) => b.createAt.compareTo(a.createAt));
    return sorted;
  }
}