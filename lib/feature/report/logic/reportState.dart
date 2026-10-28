
import 'package:capflow/feature/report/data/model/report_data.dart';

abstract class ReportState {
  const ReportState();
}

final class ReportInitial extends ReportState {}

final class ReportLoading extends ReportState {
  const ReportLoading();
}

final class ReportError extends ReportState {
  final String message;

  const ReportError({required this.message});
}
final class ReportLoaded extends ReportState {
  final ReportData reportData;

  ReportLoaded({required this.reportData});
}