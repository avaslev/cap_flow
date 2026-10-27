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
  final Map<String, Tool> toolsById;

  ActivityListLoaded({
    required this.data,
    required this.grouped,
    this.toolsById = const <String, Tool>{},
  });
}

final class ActivityLoaded extends ActivityState {
  final Activity data;

  /// Вторая половина перевода (если открыта половина пары).
  final Activity? counterpart;

  /// Комиссия перевода (если есть).
  final Activity? commission;

  ActivityLoaded({
    required this.data,
    this.counterpart,
    this.commission,
  });

  bool get isTransferPair => counterpart != null;

  /// Смысл пары: перевод, покупка или продажа.
  TransferKind get transferKind {
    final Activity? other = counterpart;
    if (other == null) return TransferKind.transfer;
    final Activity from = data.type == ActivityType.substract ? data : other;
    final Activity to = data.type == ActivityType.substract ? other : data;
    return transferKindOf(from, to);
  }
}
 
class ActivityError extends ActivityState {
  final String message;
  ActivityError({required this.message});
}