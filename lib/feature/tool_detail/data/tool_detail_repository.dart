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