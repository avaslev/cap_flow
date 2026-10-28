// FinancialEvent Bloc
// Events

import 'package:capflow/feature/event/data/event.dart';

abstract class FinancialEventEvent {
  const FinancialEventEvent();
}

class LoadFinancialEvents extends FinancialEventEvent {
  final String accountId;
  const LoadFinancialEvents(this.accountId);
}

class DeleteFinancialEvent extends FinancialEventEvent {
  final String eventId;
  const DeleteFinancialEvent(this.eventId);
}

/// Restores the most recently deleted event (Undo).
class UndoDeleteFinancialEvent extends FinancialEventEvent {
  const UndoDeleteFinancialEvent();
}
