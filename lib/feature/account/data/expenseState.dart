import 'package:bookstore/feature/account/data/accountDataState.dart';


/// Represents the possible states of the form submission process.
enum FormStatus { initial, loading, success, failure, validationError }

/// Represents the entire state of the Add Expense form.
class ExpenseState {
  final String amount;
  final String category;
  final String comment;
  final DateTime selectedDate;
  final String? selectedMoneyToolId;
  final List<ToolSummary> availableMoneyTools;
  final FormStatus formStatus;
  final String? errorMessage;

  const ExpenseState({
    required this.amount,
    required this.category,
    required this.comment,
    required this.selectedDate,
    this.selectedMoneyToolId,
    required this.availableMoneyTools,
    this.formStatus = FormStatus.initial,
    this.errorMessage,
  });

  /// Factory constructor to create an initial state for the form.
  factory ExpenseState.initial(List<ToolSummary> initialMoneyTools) {
    return ExpenseState(
      amount: '',
      category: '',
      comment: '',
      selectedDate: DateTime.now(),
      selectedMoneyToolId:
          initialMoneyTools.isNotEmpty ? initialMoneyTools.first.id : null,
      availableMoneyTools: initialMoneyTools,
    );
  }

  /// Creates a copy of the current state with specified changes.
  ExpenseState copyWith({
    String? amount,
    String? category,
    String? comment,
    DateTime? selectedDate,
    String? selectedMoneyToolId,
    List<ToolSummary>? availableMoneyTools,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return ExpenseState(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      comment: comment ?? this.comment,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedMoneyToolId:
          selectedMoneyToolId ?? this.selectedMoneyToolId,
      availableMoneyTools: availableMoneyTools ?? this.availableMoneyTools,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage, // Allow explicit nulling out of error message
    );
  }

}
