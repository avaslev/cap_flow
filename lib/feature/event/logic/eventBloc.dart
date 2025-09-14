import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventState.dart';


// Bloc

class FinancialEventBloc extends Bloc<FinancialEventEvent, FinancialEventState> {
  final ScheduledTransactionRepository _repo = ScheduledTransactionRepository();
  String _accountId = '';
  List<Wallet> _wallets = [];

    FinancialEventBloc()
      : super(const FinancialEventLoaded(<FinancialEvent>[], <Wallet>[], '')) {
    on<LoadFinancialEvents>(_load);
    on<AddFinancialEvent>(_add);
    on<EditFinancialEvent>(_edit);
    on<DeleteFinancialEvent>(_delete);
  }

  Future<void> _load(
      LoadFinancialEvents event, Emitter<FinancialEventState> emit) async {
    _accountId = event.accountId;
    final list = (await _repo.getByAccount(_accountId)).map((item) => _mapToEvent(item)).toList();
    _wallets = _wallets.length > 0 ? _wallets : (await ToolRepository().geListByAccount(event.accountId)).map(
      (Tool tool) => Wallet(
        id: tool.id,
        name: tool.name,
        icon: Icons.account_balance_wallet,
        color: Colors.indigo,
      ),
    ).toList();
    emit(FinancialEventLoaded(list, _wallets, _accountId));
  }

  Future<void> _add(
      AddFinancialEvent event, Emitter<FinancialEventState> emit) async {
    print('FinancialEvent _add ' + _accountId);
    await _repo.add(event.event.toScheduledTransaction(_accountId));
    // Перезагружа e
    add(LoadFinancialEvents(_accountId));
  }

  Future<void> _edit(
      EditFinancialEvent event, Emitter<FinancialEventState> emit) async {
    await _repo.update(event.event.toScheduledTransaction(_accountId));
    add(LoadFinancialEvents(_accountId));
  }

  Future<void> _delete(
      DeleteFinancialEvent event, Emitter<FinancialEventState> emit) async {
    await _repo.delete(event.eventId);
    add(LoadFinancialEvents(_accountId));
  }

  FinancialEvent _mapToEvent (ScheduledTransaction tx) {
    print(tx.toString());
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

// Initial dummy wallet data
const List<Wallet> initialWallets = <Wallet>[
  Wallet(id: '01993c8b-733d-7d4a-8636-f65bb654cd6a', name: 'Основной счет', icon: Icons.account_balance_wallet, color: Colors.indigo),
  Wallet(id: 'w2', name: 'Наличные', icon: Icons.money, color: Colors.brown),
  Wallet(id: 'w3', name: 'Сбережения', icon: Icons.savings, color: Colors.teal),
];
