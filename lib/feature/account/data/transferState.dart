import 'package:capflow/feature/account/data/accountDataState.dart';

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

  /// Курс перевода FROM → TO (строка, редактируемый; при одинаковых валютах = '1').
  final String rate;

  /// Сумма зачисления в валюте получателя.
  final String amountTo;

  /// Валюты (тикеры) тула-источника и тула-получателя.
  final String? fromTicker;
  final String? toTicker;
  final List<ToolSummary> availableMoneyTools;
  final List<AccountSummary> accounts;
  final FormStatus formStatus;
  final String? errorMessage;
  final String? scheduledEventId;
  final bool sameCurrencyOnly;

  bool get isCrossCurrency =>
      fromTicker != null && toTicker != null && fromTicker != toTicker;

  bool get isScheduled => scheduledEventId != null;

  const TransferState({
    required this.amount,
    required this.comment,
    required this.selectedDate,
    this.selectedFromToolId,
    this.selectedToToolId,
    this.commission,
    this.rate = '',
    this.amountTo = '',
    this.fromTicker,
    this.toTicker,
    required this.availableMoneyTools,
    required this.accounts,
    this.formStatus = FormStatus.initial,
    this.errorMessage,
    this.scheduledEventId,
    this.sameCurrencyOnly = false,
  });

  /// Factory constructor to create an initial state for the form.
  factory TransferState.initial(
    ToolSummary currentTool,
    List<ToolSummary> initialMoneyTools,
    List<AccountSummary> accounts, {
    String? fromToolId,
    String? toToolId,
    DateTime? initialDate,
    String? amount,
    String? comment,
    String? scheduledEventId,
    bool sameCurrencyOnly = false,
  }) {
    String? tickerOf(String? id) {
      if (id == null) return null;
      for (final ToolSummary tool in initialMoneyTools) {
        if (tool.id == id) return tool.ticker ?? 'RUB';
      }
      return null;
    }

    final String selectedFromToolId = fromToolId ?? currentTool.id;
    return TransferState(
      amount: amount ?? '',
      comment: comment ?? '',
      selectedDate: initialDate ?? DateTime.now(),
      selectedFromToolId: selectedFromToolId,
      selectedToToolId: toToolId,
      fromTicker: tickerOf(selectedFromToolId),
      toTicker: tickerOf(toToolId),
      availableMoneyTools: initialMoneyTools,
      accounts: accounts,
      rate: '',
      amountTo: amount ?? '',
      scheduledEventId: scheduledEventId,
      sameCurrencyOnly: sameCurrencyOnly,
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
    String? rate,
    String? amountTo,
    String? fromTicker,
    String? toTicker,
    List<ToolSummary>? availableMoneyTools,
    FormStatus? formStatus,
    String? errorMessage,
    String? scheduledEventId,
    bool? sameCurrencyOnly,
  }) {
    return TransferState(
      amount: amount ?? this.amount,
      comment: comment ?? this.comment,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedFromToolId: selectedFromToolId ?? this.selectedFromToolId,
      selectedToToolId: selectedToToolId ?? this.selectedToToolId,
      commission: commission ?? this.commission,
      rate: rate ?? this.rate,
      amountTo: amountTo ?? this.amountTo,
      fromTicker: fromTicker ?? this.fromTicker,
      toTicker: toTicker ?? this.toTicker,
      availableMoneyTools: availableMoneyTools ?? this.availableMoneyTools,
      accounts: accounts,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage, // Allow explicit nulling out of error message
      scheduledEventId: scheduledEventId ?? this.scheduledEventId,
      sameCurrencyOnly: sameCurrencyOnly ?? this.sameCurrencyOnly,
    );
  }
}
