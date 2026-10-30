part of 'accountBloc.dart';

@immutable
sealed class AccountsEvent {}

class AccountsTransitionEvent extends AccountsEvent {
  AccountsTransitionEvent();
}

class ChangePageAccountsEvent extends AccountsEvent {
  final int page;
  ChangePageAccountsEvent(this.page);
}

class TapByAccountCardEvent extends AccountsEvent {
  final String accountId;
  TapByAccountCardEvent(this.accountId);
}

class DisableEditModeAccountCardEvent extends AccountsEvent {
  final String? accountId;
  DisableEditModeAccountCardEvent(this.accountId);
}

class EnableEditModeAccountCardEvent extends AccountsEvent {
  final String accountId;
  EnableEditModeAccountCardEvent(this.accountId);
}

class AddAccountEvent extends AccountsEvent {
  final AccountSummary account;
  AddAccountEvent(this.account);
}

class MoveAccountEvent extends AccountsEvent {
  final String accountId;
  final bool up;

  MoveAccountEvent(this.accountId, {required this.up});
}

/// Изменить настройки счёта: название, цвет и флаги отображения.
class UpdateAccountEvent extends AccountsEvent {
  final String accountId;
  final String name;
  final int colorValue;
  final bool hideEvents;
  final bool excludeFromTotal;

  UpdateAccountEvent({
    required this.accountId,
    required this.name,
    required this.colorValue,
    required this.hideEvents,
    required this.excludeFromTotal,
  });
}

class ChangeAccountEvent extends AccountsEvent {
  final String accountId;
  final bool hideEvents; // New attribute to hide events for this account
  final bool excludeFromTotal; // New attribute to exclude from total balance calculation
  final bool remove; // New attribute to exclude from total balance calculation
  ChangeAccountEvent({required this.accountId, required this.hideEvents, required this.excludeFromTotal, required this.remove});
}

/// Скрыть счёт (архивация): данные сохраняются, счёт исчезает из
/// списка и общего баланса. Обратимо через [RestoreAccountEvent].
class ArchiveAccountEvent extends AccountsEvent {
  final String accountId;
  ArchiveAccountEvent(this.accountId);
}

/// Вернуть счёт из архива.
class RestoreAccountEvent extends AccountsEvent {
  final String accountId;
  RestoreAccountEvent(this.accountId);
}