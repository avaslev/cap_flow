import 'package:bookstore/feature/account/data/accountDataState.dart';

/// Represents the possible states of the form submission process.
enum ActivityStateType { add, substract }
/// Represents the possible states of the form submission process.
enum FormStatus { initial, loading, success, failure, validationError }

/// Represents the entire state of the Add Activity form.
class ActivityState {
  final String amount;
  final String category;
  final String comment;
  final DateTime selectedDate;
  final String? selectedMoneyToolId;
  final List<ToolSummary> availableMoneyTools;
  final ActivityStateType activityType;
  final FormStatus formStatus;
  final String? errorMessage;

  const ActivityState({
    required this.amount,
    required this.category,
    required this.comment,
    required this.selectedDate,
    this.selectedMoneyToolId,
    required this.availableMoneyTools,
    required this.activityType,
    this.formStatus = FormStatus.initial,
    this.errorMessage,
  });

  /// Factory constructor to create an initial state for the form.
  factory ActivityState.initial(List<ToolSummary> initialMoneyTools, ActivityStateType activityType) {
    return ActivityState(
      amount: '',
      category: '',
      comment: '',
      selectedDate: DateTime.now(),
      selectedMoneyToolId:
          initialMoneyTools.isNotEmpty ? initialMoneyTools.first.id : null,
      availableMoneyTools: initialMoneyTools,
      activityType: activityType,
    );
  }

  /// Creates a copy of the current state with specified changes.
  ActivityState copyWith({
    String? amount,
    String? category,
    String? comment,
    DateTime? selectedDate,
    String? selectedMoneyToolId,
    List<ToolSummary>? availableMoneyTools,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return ActivityState(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      comment: comment ?? this.comment,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedMoneyToolId:
          selectedMoneyToolId ?? this.selectedMoneyToolId,
      availableMoneyTools: availableMoneyTools ?? this.availableMoneyTools,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage, // Allow explicit nulling out of error message
      activityType: activityType,
    );
  }

}
