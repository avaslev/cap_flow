

abstract class ReportEvent {
  const ReportEvent();
}

class LoadReportEvent extends ReportEvent {
  final String accountId;
  LoadReportEvent(this.accountId);
}