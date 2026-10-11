import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/report/data/repository/report.dart';
import 'package:investflow/feature/report/logic/reportEvent.dart';
import 'package:investflow/feature/report/logic/reportState.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportRepository _repository = ReportRepository();

  ReportBloc() : super(ReportInitial()) {
    on<LoadReportEvent>(_load);
  }
  
  FutureOr<void> _load(LoadReportEvent event, Emitter<ReportState> emit) async {
    // Ошибка загрузки больше не оставляет bloc в Initial (вечный спиннер).
    emit(const ReportLoading());
    try {
      final data = await _repository.getReportData(event.accountId);
      emit(ReportLoaded(reportData: data));
    } catch (e) {
      emit(ReportError(message: 'Не удалось загрузить отчёт: $e'));
    }
  }
}
