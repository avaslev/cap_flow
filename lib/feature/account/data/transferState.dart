import 'package:bookstore/feature/account/data/accountDataState.dart';


/// Represents the possible states of the form submission process.
enum FormStatus { initial, loading, success, failure, validationError }

/// Represents the entire state of the Add Income form.
class TransferState {
  final String amount;
  final String comment;
  final DateTime selectedDate;
  final String? selectedFromToolId;
  final String? selectedToToolId;
  final String? commission;
  final List<ToolSummary> availableMoneyTools;
  final List<AccountSummary> accounts;
  final FormStatus formStatus;
  final String? errorMessage;

  const TransferState({
    required this.amount,
    required this.comment,
    required this.selectedDate,
    this.selectedFromToolId,
    this.selectedToToolId,
    this.commission,
    required this.availableMoneyTools,
    required this.accounts,
    this.formStatus = FormStatus.initial,
    this.errorMessage,
  });

  /// Factory constructor to create an initial state for the form.
  factory TransferState.initial(ToolSummary currentTool, List<ToolSummary> initialMoneyTools, List<AccountSummary> accounts) {
    return TransferState(
      amount: '',
      comment: '',
      selectedDate: DateTime.now(),
      selectedFromToolId: currentTool.id,
      availableMoneyTools: initialMoneyTools,
      accounts: accounts,
    );
  }

  /// Creates a copy of the current state with specified changes.
  TransferState copyWith({
    String? amount,
    String? comment,
    DateTime? selectedDate,
    String? selectedFromToolId,
    String? selectedToToolId,
    String? commission,
    List<ToolSummary>? availableMoneyTools,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return TransferState(
      amount: amount ?? this.amount,
      comment: comment ?? this.comment,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedFromToolId:
          selectedFromToolId ?? this.selectedFromToolId,
      selectedToToolId:
          selectedToToolId ?? this.selectedToToolId,
      commission: commission ?? this.commission,
      availableMoneyTools: availableMoneyTools ?? this.availableMoneyTools,
      accounts: accounts,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage, // Allow explicit nulling out of error message
    );
  }
}
