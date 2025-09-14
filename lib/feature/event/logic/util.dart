import 'dart:math';

import 'package:investflow/feature/event/data/event.dart';


// --- Helper Functions for Date Calculations ---
// These are private to this file as they are internal utilities.

/// Returns the number of days in a given month and year, accounting for leap years.
int _daysInMonth(int year, int month) {
  if (month == DateTime.february) {
    final bool isLeapYear = (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
    return isLeapYear ? 29 : 28;
  } else if (<int>[DateTime.april, DateTime.june, DateTime.september, DateTime.november].contains(month)) {
    return 30;
  } else {
    return 31;
  }
}

/// Adds a specified number of months to a [DateTime] object,
/// correctly handling day overflows (e.g., Jan 31 + 1 month = Feb 28/29).
DateTime _addMonthCorrectly(DateTime date, int months) {
  int year = date.year;
  int month = date.month + months;
  int day = date.day;

  while (month > 12) {
    month -= 12;
    year++;
  }
  while (month < 1) {
    month += 12;
    year--;
  }

  // Cap the day at the end of the target month
  int daysInTargetMonth = _daysInMonth(year, month);
  if (day > daysInTargetMonth) {
    day = daysInTargetMonth;
  }
  return DateTime(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

/// Calculates the next occurrence date for a recurring financial event
/// after a specified reference [now] time.
/// Returns null if there are no future occurrences (e.g., recurrence ended or not recurring).
DateTime? calculateNextOccurrence(FinancialEvent event, DateTime now) {
  if (event.recurrenceType == RecurrenceType.none) {
    return null;
  }

  DateTime currentCandidate = event.date;

  // Loop indefinitely until a suitable next occurrence is found or determined that none exist.
  while (true) {
    // 1. Check if current candidate date is past the recurrence end date
    if (event.recurrenceEndDate != null && currentCandidate.isAfter(event.recurrenceEndDate!)) {
      return null; // No more occurrences
    }

    // 2. If the current candidate date is after the reference 'now', this is our next occurrence
    if (currentCandidate.isAfter(now)) {
      return currentCandidate;
    }

    // 3. If we reach here, currentCandidate is at or before 'now', so we need to advance it
    switch (event.recurrenceType) {
      case RecurrenceType.weekly:
        currentCandidate = currentCandidate.add(const Duration(days: 7));
        break;
      case RecurrenceType.monthly:
        currentCandidate = _addMonthCorrectly(currentCandidate, 1);
        break;
      case RecurrenceType.annually:
        int targetDay = currentCandidate.day;
        int nextYear = currentCandidate.year + 1;
        int nextMonth = currentCandidate.month;
        int daysInNextMonth = _daysInMonth(nextYear, nextMonth);
        currentCandidate = DateTime(nextYear, nextMonth, min(targetDay, daysInNextMonth),
            currentCandidate.hour, currentCandidate.minute, currentCandidate.second, currentCandidate.millisecond, currentCandidate.microsecond);
        break;
      case RecurrenceType.monthlyOnDay:
        final int targetRecurrenceDay = event.recurrenceDayOfMonth ?? event.date.day;
        int year = currentCandidate.year;
        int month = currentCandidate.month;

        // First, check if there's a valid occurrence in the current month that is after 'now'.
        // If currentCandidate.day is before targetRecurrenceDay, the date with targetRecurrenceDay in the current month
        // might be after 'now'.
        if (currentCandidate.day < targetRecurrenceDay) {
          DateTime potentialDateInCurrentMonth = DateTime(year, month, min(targetRecurrenceDay, _daysInMonth(year, month)),
              currentCandidate.hour, currentCandidate.minute, currentCandidate.second, currentCandidate.millisecond, currentCandidate.microsecond);

          if (potentialDateInCurrentMonth.isAfter(now)) {
            // This date is in the future. Return it if it's not past the end date.
            if (event.recurrenceEndDate == null || !potentialDateInCurrentMonth.isAfter(event.recurrenceEndDate!)) {
              return potentialDateInCurrentMonth;
            } else {
              return null; // Potential date is past end date
            }
          }
        }

        // If no occurrence was found in the current month that is after 'now',
        // or if currentCandidate.day is already >= targetRecurrenceDay,
        // then advance to the next month to find the target day.
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
        currentCandidate = DateTime(year, month, min(targetRecurrenceDay, _daysInMonth(year, month)),
            currentCandidate.hour, currentCandidate.minute, currentCandidate.second, currentCandidate.millisecond, currentCandidate.microsecond);
        break;
      case RecurrenceType.none:
        return null; // Should be handled by initial check, but for safety
    }
  }
}
