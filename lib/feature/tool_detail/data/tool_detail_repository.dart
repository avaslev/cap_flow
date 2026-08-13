import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

/// Repository for tool detail operations.
///
/// This repository provides methods to fetch tool details while
/// maintaining isolation from other modules.
class ToolDetailRepository {
  final ToolRepository _repo = ToolRepository();

  /// Gets a tool by its ID and converts it to display format.
  Future<ToolDetailDisplay> get(String toolId) async {
    // For now, return mock data for testing
    if (toolId.startsWith('money')) {
      return ToolDetailDisplay(
        id: toolId,
        name: 'Main Checking Account',
        quantity: 10000.0,
        percentageChange: 0.0,
        accountId: 'acc123',
        type: 'MONEY',
        currentValue: 10000.0,
        ticker: 'USD',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );
    } else if (toolId.startsWith('stock')) {
      return ToolDetailDisplay(
        id: toolId,
        name: 'Apple Inc.',
        quantity: 100.0,
        percentageChange: 2.5,
        accountId: 'acc123',
        type: 'STOCK',
        currentValue: 180.0,
        ticker: 'AAPL',
      );
    } else if (toolId.startsWith('bond')) {
      return ToolDetailDisplay(
        id: toolId,
        name: 'US Treasury Bond',
        quantity: 5.0,
        percentageChange: 0.8,
        accountId: 'acc123',
        type: 'BOND',
        currentValue: 5250.0,
        faceValue: 1000.0,
        interestRate: 0.03,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2025, 6, 15),
        paymentDayOfMonth: 15,
      );
    }

    final tool = await _repo.get(toolId);

    // Note: The Tool model doesn't contain all fields needed for ToolDetailDisplay.
    // Fields like quantity and currentValue need to be calculated from activities.
    // This is a limitation of the current architecture where event replay is
    // handled at a higher level (AccountData level).

    return ToolDetailDisplay.fromTool(tool);
  }

  /// Gets a tool by its ID as a plain Tool object.
  Future<Tool> getTool(String toolId) async {
    return await _repo.get(toolId);
  }

  /// Gets tool type as a string for use in display.
  String getToolTypeString(String type) {
    return type;
  }
}