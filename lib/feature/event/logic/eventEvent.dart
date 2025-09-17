// FinancialEvent Bloc
// Events

import 'package:investflow/feature/event/data/event.dart';

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
