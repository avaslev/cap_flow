import 'package:investflow/feature/account/data/accountDataState.dart';

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
  final String? eventId;

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
    this.eventId,
  });

  /// Factory constructor to create an initial state for the form.
  ///
  /// [commentOverride] — готовый текст комментария (название события + счёт),
  /// сформированный вызывающей стороной; если не задан, используется
  /// описание события.
  factory ActivityState.initial(List<ToolSummary> initialMoneyTools, ActivityStateType activityType, Event? event, {String? commentOverride}) {
    List<ToolSummary> _initialMoneyTools = initialMoneyTools.where((tool) => null == event ? true : event.toolId == tool.id).toList();
    return ActivityState(
      amount: event?.amount.toString() ?? '',
      category: event?.category ?? '',
      comment: commentOverride ?? event?.description ?? '',
      selectedDate: event?.date ?? DateTime.now(),
      selectedMoneyToolId: _initialMoneyTools.isNotEmpty ? _initialMoneyTools.first.id : null,
      availableMoneyTools: _initialMoneyTools,
      activityType: activityType,
      eventId: event?.eventId,
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
    String? eventId,
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
      eventId: eventId ?? this.eventId,
    );
  }

}
