import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

// Importing the parts for event and state definitions
part 'action_event.dart';
part 'action_state.dart';

// The ActionBloc class extends Bloc and manages the state of the application
class ActionBloc extends Bloc<ActionEvent, CounterState> {
  // Constructor initializes the bloc with an initial state
  ActionBloc() : super(CounterState( counter: 0)) {
    // Specific event handler for CounterIncrementPressed
    on<CounterIncrementPressed>((event, emit) {
      // Emits a new CounterState with the incremented counter value
      emit(CounterState(counter: event.counter + 1));
    });
  }
}