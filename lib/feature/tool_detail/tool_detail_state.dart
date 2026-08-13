import 'package:equatable/equatable.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

/// Abstract class representing the state of the ToolDetail BLoC.
abstract class ToolDetailState extends Equatable {
  const ToolDetailState();
  @override
  List<Object> get props => [];
}

/// State indicating that the tool detail is being loaded.
class ToolDetailLoading extends ToolDetailState {
  @override
  List<Object> get props => [];
}

/// State indicating that the tool detail has been loaded.
class ToolDetailLoaded extends ToolDetailState {
  final ToolDetailDisplay tool;

  const ToolDetailLoaded(this.tool) : super();

  @override
  List<Object> get props => [tool];
}

/// State indicating that loading failed.
class ToolDetailError extends ToolDetailState {
  final String message;

  const ToolDetailError(this.message) : super();

  @override
  List<Object> get props => [message];
}