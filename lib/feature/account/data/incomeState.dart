import 'package:bookstore/feature/account/data/accountDataState.dart';


/// Represents the possible states of the form submission process.
enum FormStatus { initial, loading, success, failure, validationError }

/// Represents the entire state of the Add Income form.
class IncomeState {
  final String amount;
  final String category;
  final String comment;
  final DateTime selectedDate;
  final String? selectedMoneyToolId;
  final List<ToolSummary> availableMoneyTools;
  final FormStatus formStatus;
  final String? errorMessage;

  const IncomeState({
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
  factory IncomeState.initial(List<ToolSummary> initialMoneyTools) {
    return IncomeState(
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
  IncomeState copyWith({
    String? amount,
    String? category,
    String? comment,
    DateTime? selectedDate,
    String? selectedMoneyToolId,
    List<ToolSummary>? availableMoneyTools,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return IncomeState(
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
