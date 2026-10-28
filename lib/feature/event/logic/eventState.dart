// States
import 'package:capflow/feature/event/data/event.dart';
import 'package:capflow/feature/event/data/wallet.dart';

/// Represents the possible states of the form submission process.
enum FormStatus { initial, loading, success, failure, validationError }

abstract class FinancialEventState {
  const FinancialEventState();
}

class FinancialEventLoading extends FinancialEventState {
  const FinancialEventLoading();
}

class FinancialEventLoaded extends FinancialEventState {
  final List<FinancialEvent> events;
  final List<Wallet> wallets;
  final List<String> categories;
  final String accountId;

  const FinancialEventLoaded(this.events, this.wallets, this.categories, this.accountId);
}

class FinancialEventError extends FinancialEventState {
  final String message;
  const FinancialEventError(this.message);
}

class FinancialEventEditState extends FinancialEventState {
  final String accountId;
  final FinancialEvent event;
  final FormStatus formStatus;
  final String? errorMessage;
  const FinancialEventEditState({required this.accountId,  required this.event,  required this.formStatus, this.errorMessage});

    /// Factory constructor to create an initial state for the form.
  factory FinancialEventEditState.initial(String accountId, FinancialEvent? event) {
    return FinancialEventEditState(
      accountId: accountId,
      event: event ?? FinancialEvent(id: '', name: '', amount: 0, type: FinancialEventType.income, category: '', date: DateTime.now(), walletId: ''), 
      formStatus: FormStatus.initial,
    );
  }

  /// Creates a copy of the current state with specified changes.
  FinancialEventEditState copyWith({
    String? accountId,
    FinancialEvent? event,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return FinancialEventEditState(
      accountId: accountId ?? this.accountId,
      event: event ?? this.event,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}