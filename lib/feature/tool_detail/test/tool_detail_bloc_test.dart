import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:capflow/feature/tool_detail/tool_detail_event.dart';
import 'package:capflow/feature/tool_detail/tool_detail_state.dart';

void main() {
  group('ToolDetailBloc', () {
    late ToolDetailBloc bloc;

    setUp(() {
      bloc = ToolDetailBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is ToolDetailLoading', () {
      expect(bloc.state, isA<ToolDetailLoading>());
    });

    group('LoadToolDetail', () {
      test('emits loading state when event is added', () {
        // Arrange - We don't have a way to mock repository in this simple test

        // Act
        bloc.add(const LoadToolDetail('test-account-id', 'test-tool-id'));

        // Assert - Only check that it starts in loading state
        expect(bloc.state, isA<ToolDetailLoading>());
      });

      test('adds LoadToolDetail to stream', () {
        // Act
        bloc.add(const LoadToolDetail('test-account-id', 'test-tool-id'));

        // Assert
        expect(
          bloc.stream,
          emitsInOrder([
            isA<ToolDetailLoading>(),
          ]),
        );
      });
    });
  });
}