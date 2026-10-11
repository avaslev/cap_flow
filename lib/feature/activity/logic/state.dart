part of 'bloc.dart';

/// Base class for all states in the Activity feature.
/// This class is immutable and sealed, meaning no other classes
/// outside this file can extend it.
@immutable
sealed class ActivityState {}

/// Initial state of the Activity feature.
/// Represents the default state when no specific state is set.
final class ActivityInitial extends ActivityState {}

final class ActivityListLoaded extends ActivityState {
  final List<Activity> data;
  final Map<DateTime, List<Activity>> grouped;
  ActivityListLoaded({required this.data, required this.grouped});
}

final class ActivityLoaded extends ActivityState {
  final Activity data;
  ActivityLoaded({required this.data});
}
 
class ActivityError extends ActivityState {
  final String message;
  ActivityError({required this.message});
}