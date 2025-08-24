part of 'accountBloc.dart';

/// Base class for all states in the Activity feature.
/// This class is immutable and sealed, meaning no other classes
/// outside this file can extend it.
@immutable
sealed class AccountsState {}

/// Initial state of the Activity feature.
/// Represents the default state when no specific state is set.
final class AccountsInitial extends AccountsState {}

final class AccountsDataState extends AccountsState {
  final AccountData accountData;
  AccountsDataState(this.accountData);
}
 
