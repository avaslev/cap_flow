import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/models/tools/tool_kind.dart';
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
        isTransmit: false,
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
        isTransmit: false,
        name: closeName,
      ),
    );
    return payout;
  }

  /// Activities of a tool, newest first.
  Future<List<Activity>> getActivitiesForTool(String toolId) async {
    final List<Activity> list = await _activityRepo.getActivityListByTool(toolId);
    final List<Activity> sorted = List<Activity>.from(list)
      ..sort((Activity a, Activity b) => b.createAt.compareTo(a.createAt));
    return sorted;
  }
}