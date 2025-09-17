import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/categoryRepository.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventState.dart';


// Bloc

class FinancialEventBloc extends Bloc<FinancialEventEvent, FinancialEventState> {
  final ScheduledTransactionRepository _repo = ScheduledTransactionRepository();
  final CategoryRepository _categoriesRepo = CategoryRepository();
  final ToolRepository _toolsRepo = ToolRepository();
  String _accountId = '';
  List<Wallet> _wallets = [];
  List<String> _categories = [];

    FinancialEventBloc()
      : super(const FinancialEventLoaded(<FinancialEvent>[], <Wallet>[], <String>[], '')) {
    on<LoadFinancialEvents>(_load);
    on<DeleteFinancialEvent>(_delete);
  }

  Future<void> _load(
      LoadFinancialEvents event, Emitter<FinancialEventState> emit) async {
    _accountId = event.accountId;
    final list = (await _repo.getByAccount(_accountId)).map((item) => _mapToEvent(item)).toList();
    _wallets = _wallets.length > 0 ? _wallets : (await _toolsRepo.geListByAccount(event.accountId)).map(
      (Tool tool) => Wallet(
        id: tool.id,
        name: tool.name,
        icon: Icons.account_balance_wallet,
        color: Colors.indigo,
      ),
    ).toList();
    _categories = _categories.length > 0 ? _categories : (await _categoriesRepo.getList(event.accountId, null));
    emit(FinancialEventLoaded(list, _wallets, _categories, _accountId));
  }

  Future<void> _delete(
      DeleteFinancialEvent event, Emitter<FinancialEventState> emit) async {
    await _repo.delete(event.eventId);
    add(LoadFinancialEvents(_accountId));
  }

  FinancialEvent _mapToEvent (ScheduledTransaction tx) {
    return FinancialEvent(
            id: tx.id,
            name: tx.name,
            amount: tx.amount,
            type: FinancialEventType.values
                .firstWhere((e) => e.name == tx.type),
            category: tx.category,
            date: tx.date,
            walletId: tx.walletId,
            destinationWalletId: tx.destinationWalletId,
            comment: tx.comment,
            recurrenceType: RecurrenceType.values
                .firstWhere((e) => e.name == tx.recurrenceType),
            recurrenceEndDate: tx.recurrenceEndDate,
            recurrenceDayOfMonth: tx.recurrenceDayOfMonth,
          );
  }
}
