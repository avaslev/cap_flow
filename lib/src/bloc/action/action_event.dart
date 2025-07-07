part of 'action_bloc.dart';

@immutable
sealed class ActionEvent {}

class CounterIncrementPressed extends ActionEvent {
  final int counter;

  CounterIncrementPressed({required this.counter});

}