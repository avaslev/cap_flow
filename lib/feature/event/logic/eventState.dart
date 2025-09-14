// States
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';

abstract class FinancialEventState {
  const FinancialEventState();
}

class FinancialEventLoading extends FinancialEventState {
  const FinancialEventLoading();
}

class FinancialEventLoaded extends FinancialEventState {
  final List<FinancialEvent> events;
  final List<Wallet> wallets;
  final String accountId;
  const FinancialEventLoaded(this.events, this.wallets, this.accountId);
}

class FinancialEventError extends FinancialEventState {
  final String message;
  const FinancialEventError(this.message);
}