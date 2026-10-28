import 'package:bloc/bloc.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/repository/activityRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/feature/activity/logic/activity_rows.dart';
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
      final List<Tool> tools = await ToolRepository().geList();
      final Map<String, Tool> toolsById = <String, Tool>{
        for (final Tool tool in tools) tool.id: tool,
      };
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
      emit(
        ActivityListLoaded(
          data: list,
          grouped: sortedGrouped,
          toolsById: toolsById,
        ),
      );
    } catch (e) {
      emit(ActivityError(message: 'Не удалось загрузить операции: $e'));
    }
  }

  Future<void> _loadById(
    ActivityTransitionEvent event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final ActivityRepository repository = ActivityRepository();
      final Activity activity = await repository.getById(event.activityId);

      Activity? counterpart;
      Activity? commission;
      final String? pairId = activity.transferPairId;
      if (pairId != null && pairId.isNotEmpty && activity.isTransmit) {
        final List<Activity> group = await repository.getByTransferPairId(
          pairId,
        );
        for (final Activity a in group) {
          if (a.id == activity.id) continue;
          if (!a.isTransmit) {
            commission ??= a;
          } else if (a.type != activity.type) {
            counterpart ??= a;
          }
        }
      }

      emit(
        ActivityLoaded(
          data: activity,
          counterpart: counterpart,
          commission: commission,
        ),
      );
    } catch (e) {
      emit(ActivityError(message: 'Не удалось загрузить операцию: $e'));
    }
  }
}
