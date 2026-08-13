import 'package:equatable/equatable.dart';

/// Event for loading a tool detail by its ID for a specific account.
class LoadToolDetail extends Equatable {
  final String accountId;
  final String toolId;

  const LoadToolDetail(this.accountId, this.toolId);

  @override
  List<Object> get props => [accountId, toolId];
}