import 'package:bloc/bloc.dart';
import 'package:bookstore/data/models/activity.dart';
import 'package:bookstore/data/repository/activityRepository.dart';
import 'package:meta/meta.dart';

// Importing the parts for event and state definitions
part 'event.dart';
part 'state.dart';

// The ActivityBloc class extends Bloc and manages the state of the application
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  // Constructor initializes the bloc with an initial state
  ActivityBloc() : super(ActivityInitial()) {
    // Specific event handler for CounterIncrementPressed
    on<CounterIncrementPressed>((event, emit) {
      // Emits a new CounterState with the incremented counter value
      emit(CounterState(counter: event.counter + 1));
    });

    on<ActivityListTransitionEvent>((event, emit) async {
      // await ActivityRepository().insert(Activity.money(Type.add, DateTime.now(), 105, Currency.RUB));
      // Emits a new CounterState with the incremented counter value
      final list = await ActivityRepository().getActivityList();

      final Map<DateTime, List<Activity>> grouped = <DateTime, List<Activity>>{};
      for (final Activity action in list) {
        // Normalize date to remove time component for grouping
        final DateTime date = DateTime(action.createAt.year, action.createAt.month, action.createAt.day);
        grouped.putIfAbsent(date, () => <Activity>[]).add(action);
      }

      // Sort dates in descending order (most recent first)
      final List<DateTime> sortedKeys = grouped.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      
      final Map<DateTime, List<Activity>> sortedGrouped = <DateTime, List<Activity>>{};
      for (final DateTime key in sortedKeys) {
        // Sort actions within each group by creation time (most recent first)
        final List<Activity> sortedActivities = grouped[key]!
          ..sort((a, b) => b.createAt.compareTo(a.createAt));
        sortedGrouped[key] = sortedActivities;
      }

      emit(ActivityListLoaded(data: list, grouped: sortedGrouped));
    });

    on<ActivityTransitionEvent>((event, emit) async {
      // emit(ActivityLoaded(data: Activity.money(Type.add, DateTime.now(), 105, Currency.RUB)));
    });
  }
}
