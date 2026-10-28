import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/data/repository/settingsRepository.dart';

/// Предпочтительный money-тул: с тикером дефолтной валюты из настроек
/// (среди открытых). Если такого нет — первый в списке. null — список пуст.
Future<ToolSummary?> selectDefaultMoneyTool(List<ToolSummary> tools) async {
  if (tools.isEmpty) return null;
  final String def = await SettingsRepository().getDefaultCurrency();
  for (final ToolSummary t in tools) {
    if (!t.isClosed && (t.ticker ?? 'RUB') == def) {
      return t;
    }
  }
  return tools.first;
}
