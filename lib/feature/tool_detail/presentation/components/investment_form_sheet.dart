import 'package:flutter/material.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/account/logic/accountBloc.dart';
import 'package:capflow/feature/account/presentation/widget/form/investment.dart';
import 'package:capflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:capflow/feature/tool_detail/tool_detail_event.dart';

/// Открыть форму покупки/продажи биржевого инструмента снизу поверх
/// детального экрана. Данные счёта грузятся свежим AccountsBloc,
/// после закрытия перезагружает детали тула.
Future<void> showInvestmentFormSheet(
  BuildContext context, {
  required String accountId,
  required String toolId,
  required ToolType investmentType,
  required InvestmentOperationType operationType,
  String? presetTicker,
  String? presetName,
}) async {
  final AccountsBloc accountsBloc = AccountsBloc()
    ..add(AccountsTransitionEvent());
  try {
    await accountsBloc.stream
        .firstWhere((AccountsState state) => state is AccountsDataState)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => accountsBloc.state,
        );
  } catch (_) {
    // Таймаут обработки ниже: без данных счёта операция невозможна.
  }
  if (accountsBloc.state is! AccountsDataState) {
    // Данные счёта не загрузились — форму не открываем.
    accountsBloc.close();
    if (context.mounted) {
      Toast.show(context, 'Не удалось загрузить данные счёта', error: true);
    }
    return;
  }
  if (!context.mounted) {
    accountsBloc.close();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
    builder: (BuildContext sheetContext) => BlocProvider<AccountsBloc>.value(
      value: accountsBloc,
      child: AddInvestmentOperationForm(
        accountId: accountId,
        operationType: operationType,
        investmentType: investmentType,
        presetTicker: presetTicker,
        presetName: presetName,
      ),
    ),
  );
  accountsBloc.close();
  if (!context.mounted) return;
  // Полная продажа удаляет тул — детальный экран тогда закрываем.
  bool toolDeleted = false;
  try {
    await ToolRepository().get(toolId);
  } catch (_) {
    toolDeleted = true;
  }
  if (toolDeleted) {
    Toast.show(context, 'Позиция продана полностью');
    Navigator.of(context).pop();
    return;
  }
  context.read<ToolDetailBloc>().add(LoadToolDetail(accountId, toolId));
}
