import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'data/tool_detail_repository.dart';
import 'tool_detail_event.dart';
import 'tool_detail_state.dart';

/// BLoC responsible for loading a tool's detail.
/// It receives a [LoadToolDetail] event with a tool ID, fetches the tool
/// from the repository, and emits one of the following states:
///   * [ToolDetailLoading] – when the fetch is in progress.
///   * [ToolDetailLoaded] – when the tool is successfully retrieved.
///   * [ToolDetailError] – if an error occurs.
class ToolDetailBloc extends Bloc<LoadToolDetail, ToolDetailState> {
  final ToolDetailRepository _repo = ToolDetailRepository();

  ToolDetailBloc() : super(ToolDetailLoading()) {
    on<LoadToolDetail>(_onLoadTool);
  }

  Future<void> _onLoadTool(LoadToolDetail event, Emitter<ToolDetailState> emit) async {
    emit(ToolDetailLoading());
    try {
      final tool = await _repo.get(event.toolId);
      emit(ToolDetailLoaded(tool));
    } catch (e) {
      emit(ToolDetailError(e.toString()));
    }
  }
}
