import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/repository/accountRepository.dart';
import 'package:capflow/data/repository/categoryRepository.dart';
import 'package:capflow/data/repository/currencyRepository.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/feature/event/data/event.dart';
import 'package:capflow/feature/event/data/wallet.dart';
import 'package:capflow/feature/event/logic/eventEvent.dart';
import 'package:capflow/feature/event/logic/eventState.dart';

// Bloc

class FinancialEventBloc
    extends Bloc<FinancialEventEvent, FinancialEventState> {
  final ScheduledTransactionRepository _repo = ScheduledTransactionRepository();
  final CategoryRepository _categoriesRepo = CategoryRepository();
  final ToolRepository _toolsRepo = ToolRepository();
  String _accountId = '';
  List<Wallet> _wallets = [];
  List<String> _categories = [];
  ScheduledTransaction? _lastDeleted;

  FinancialEventBloc()
    : super(
        const FinancialEventLoaded(
          <FinancialEvent>[],
          <Wallet>[],
          <String>[],
          '',
        ),
      ) {
    on<LoadFinancialEvents>(_load);
    on<DeleteFinancialEvent>(_delete);
    on<UndoDeleteFinancialEvent>(_undoDelete);
  }

  Future<void> _load(
    LoadFinancialEvents event,
    Emitter<FinancialEventState> emit,
  ) async {
    // Show the full-screen spinner only before any data has been loaded;
    // subsequent refreshes stay silent to avoid list flicker.
    final FinancialEventState current = state;
    final bool isFirstLoad =
        current is FinancialEventLoaded &&
        current.events.isEmpty &&
        current.accountId.isEmpty;
    if (isFirstLoad) {
      emit(const FinancialEventLoading());
    }
    _accountId = event.accountId;
    final list =
        (await _repo.getByAccount(
          _accountId,
        )).map((item) => _mapToEvent(item)).toList();

    // Все открытые тулы всех счетов: нужны и для отображения имён, и для
    // выбора получателя межсчётного перевода.
    final List<Tool> allTools = await _toolsRepo.geList();
    final Map<String, String> accountNames = <String, String>{
      for (final account in await AccountRepository().geList())
        account.id: account.name,
    };
    final String defaultCurrency =
        await CurrencyRepository().getDefaultCurrency();
    _wallets =
        allTools.where((Tool tool) => !tool.isClosed).map((Tool tool) {
          final ToolType toolType = ToolType.values.firstWhere(
            (ToolType type) => type.name == tool.type,
            orElse: () => ToolType.other,
          );
          return Wallet(
            id: tool.id,
            name: tool.name,
            icon: Icons.account_balance_wallet,
            color: Colors.indigo,
            accountId: tool.accountId,
            accountName: accountNames[tool.accountId] ?? '',
            ticker: tool.ticker ?? defaultCurrency,
            type: toolType,
          );
        }).toList();
    _categories =
        _categories.length > 0
            ? _categories
            : (await _categoriesRepo.getList(event.accountId, null));
    emit(FinancialEventLoaded(list, _wallets, _categories, _accountId));
  }

  Future<void> _delete(
    DeleteFinancialEvent event,
    Emitter<FinancialEventState> emit,
  ) async {
    // Keep a copy so the deletion can be undone.
    try {
      _lastDeleted = await _repo.getById(event.eventId);
    } catch (_) {
      _lastDeleted = null;
    }
    await _repo.delete(event.eventId);
    add(LoadFinancialEvents(_accountId));
  }

  Future<void> _undoDelete(
    UndoDeleteFinancialEvent event,
    Emitter<FinancialEventState> emit,
  ) async {
    final ScheduledTransaction? restore = _lastDeleted;
    if (restore != null) {
      _lastDeleted = null;
      await _repo.add(restore);
      add(LoadFinancialEvents(_accountId));
    }
  }

  FinancialEvent _mapToEvent(ScheduledTransaction tx) {
    return FinancialEvent(
      id: tx.id,
      name: tx.name,
      amount: tx.amount,
      type: FinancialEventType.values.firstWhere((e) => e.name == tx.type),
      category: tx.category,
      // The planner works with the NEXT execution date — it is advanced
      // by the execution flow (not the original first-occurrence date).
      date: tx.nextExecutionDate,
      walletId: tx.walletId,
      destinationWalletId: tx.destinationWalletId,
      comment: tx.comment,
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == tx.recurrenceType,
      ),
      recurrenceEndDate: tx.recurrenceEndDate,
      recurrenceDayOfMonth: tx.recurrenceDayOfMonth,
    );
  }
}
