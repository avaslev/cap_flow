part of 'bloc.dart';

@immutable
sealed class ActivityEvent {}

class ActivityListTransitionEvent extends ActivityEvent {
  ActivityListTransitionEvent();
}

class ActivityTransitionEvent extends ActivityEvent {
  final String activityId;
  ActivityTransitionEvent({required this.activityId});
}