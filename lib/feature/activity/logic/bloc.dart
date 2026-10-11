import 'package:bloc/bloc.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:meta/meta.dart';

// Importing the parts for event and state definitions
part 'event.dart';
part 'state.dart';

// The ActivityBloc class extends Bloc and manages the state of the application
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  // Constructor initializes the bloc with an initial state
  ActivityBloc() : super(ActivityInitial()) {
    on<ActivityListTransitionEvent>(_loadList);
    on<ActivityTransitionEvent>(_loadById);
  }

  Future<void> _loadList(
    ActivityListTransitionEvent event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final list = await ActivityRepository().getActivityList();
      final Map<DateTime, List<Activity>> grouped = <DateTime, List<Activity>>{};
      for (final Activity action in list) {
        final DateTime date = DateTime(action.createAt.year, action.createAt.month, action.createAt.day);
        grouped.putIfAbsent(date, () => <Activity>[]).add(action);
      }
      final List<DateTime> sortedKeys = grouped.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      final Map<DateTime, List<Activity>> sortedGrouped = <DateTime, List<Activity>>{};
      for (final DateTime key in sortedKeys) {
        final List<Activity> sortedActivities = grouped[key]!
          ..sort((a, b) => b.createAt.compareTo(a.createAt));
        sortedGrouped[key] = sortedActivities;
      }
      emit(ActivityListLoaded(data: list, grouped: sortedGrouped));
    } catch (e) {
      emit(ActivityError(message: 'Не удалось загрузить операции: $e'));
    }
  }

  Future<void> _loadById(
    ActivityTransitionEvent event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final Activity activity = await ActivityRepository().getById(
        event.activityId,
      );
      emit(ActivityLoaded(data: activity));
    } catch (e) {
      emit(ActivityError(message: 'Не удалось загрузить операцию: $e'));
    }
  }
}
