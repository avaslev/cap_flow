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

class AddFinancialEvent extends FinancialEventEvent {
  final FinancialEvent event;
  const AddFinancialEvent(this.event);
}

class EditFinancialEvent extends FinancialEventEvent {
  final FinancialEvent event;
  const EditFinancialEvent(this.event);
}

class DeleteFinancialEvent extends FinancialEventEvent {
  final String eventId;
  const DeleteFinancialEvent(this.eventId);
}
