part of 'action_bloc.dart';

/// Base class for all states in the Action feature.
/// This class is immutable and sealed, meaning no other classes
/// outside this file can extend it.
@immutable
sealed class ActionState {}

/// Initial state of the Action feature.
/// Represents the default state when no specific state is set.
final class ActionInitial extends ActionState {}

/// State representing the counter value.
/// Extends [ActionInitial] and holds the current counter value.
final class CounterState extends ActionInitial {
  /// The current value of the counter.
  final int counter;

  /// Constructor for [CounterState].
  /// Requires the [counter] value to be provided.
  CounterState({required this.counter});
}