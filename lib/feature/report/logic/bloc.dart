import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
import 'package:investflow/feature/report/data/repository/report.dart';
import 'package:investflow/feature/report/logic/reportEvent.dart';
import 'package:investflow/feature/report/logic/reportState.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportRepository _repository = ReportRepository();

  ReportBloc() : super(ReportInitial()) {
    on<LoadReportEvent>(_load);
  }

  FutureOr<void> _load(
    LoadReportEvent event,
    Emitter<ReportState> emit,
  ) async {
    final data = await _repository.getReportData(event.accountId);
    emit(ReportLoaded(reportData: data));
  }
}
