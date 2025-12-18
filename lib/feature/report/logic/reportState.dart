
import 'package:investflow/feature/report/data/model/report_data.dart';

abstract class ReportState {
}

final class ReportInitial extends ReportState {}
final class ReportLoaded extends ReportState {
  final ReportData reportData;

  ReportLoaded({required this.reportData});
}