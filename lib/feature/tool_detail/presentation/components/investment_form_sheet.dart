import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:investflow/data/models/tools/tool_kind.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/logic/investmentCubit.dart';
import 'package:investflow/feature/account/presentation/widget/form/investment.dart';
import 'package:investflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_event.dart';

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
  if (context.mounted) {
    context.read<ToolDetailBloc>().add(LoadToolDetail(accountId, toolId));
  }
}
