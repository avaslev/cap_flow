import 'dart:math';

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
///
/// Parameters:
/// - [initialDate]: The starting date for the event.
/// - [recurrenceType]: The type of recurrence as a string (e.g., 'weekly', 'monthly', etc.).
/// - [recurrenceEndDate]: The end date for the recurrence, if any.
/// - [recurrenceDayOfMonth]: The specific day of the month for monthly recurrences (optional).
/// Returns null if there are no future occurrences (e.g., recurrence ended or not recurring).
DateTime? calculateNextOccurrence({
  required DateTime initialDate,
  required String recurrenceType,
  DateTime? recurrenceEndDate,
  int? recurrenceDayOfMonth,
  required DateTime now,
}) {
  if (recurrenceType == 'none') {
    return null;
  }

  DateTime currentCandidate = initialDate;

  // Loop indefinitely until a suitable next occurrence is found or determined that none exist.
  while (true) {
    // 1. Check if current candidate date is past the recurrence end date
    if (recurrenceEndDate != null && currentCandidate.isAfter(recurrenceEndDate)) {
      return null; // No more occurrences
    }

    // 2. If the current candidate date is after the reference 'now', this is our next occurrence
    if (currentCandidate.isAfter(now)) {
      return currentCandidate;
    }

    // 3. If we reach here, currentCandidate is at or before 'now', so we need to advance it
    switch (recurrenceType) {
      case 'weekly':
        currentCandidate = currentCandidate.add(const Duration(days: 7));
        break;
      case 'monthly':
        currentCandidate = _addMonthCorrectly(currentCandidate, 1);
        break;
      case 'annual':
        int targetDay = currentCandidate.day;
        int nextYear = currentCandidate.year + 1;
        int nextMonth = currentCandidate.month;
        int daysInNextMonth = _daysInMonth(nextYear, nextMonth);
        currentCandidate = DateTime(nextYear, nextMonth, 
          min(targetDay, daysInNextMonth),
          currentCandidate.hour, currentCandidate.minute, 
          currentCandidate.second, currentCandidate.millisecond, 
          currentCandidate.microsecond);
        break;
      case 'quarterly':
        currentCandidate = _addMonthCorrectly(currentCandidate, 3);
        break;
      case 'semiannual':
        currentCandidate = _addMonthCorrectly(currentCandidate, 6);
        break;
      case 'monthlyOnDay':
        final int targetRecurrenceDay = recurrenceDayOfMonth ?? currentCandidate.day;
        int year = currentCandidate.year;
        int month = currentCandidate.month;

        // Check for a valid occurrence in the current month
        if (currentCandidate.day < targetRecurrenceDay) {
          DateTime potentialDateInCurrentMonth = DateTime(year, month, 
            min(targetRecurrenceDay, _daysInMonth(year, month)),
            currentCandidate.hour, currentCandidate.minute, 
            currentCandidate.second, currentCandidate.millisecond, 
            currentCandidate.microsecond);

          if (potentialDateInCurrentMonth.isAfter(now)) {
            // This date is in the future. Return if not past the end date
            if (recurrenceEndDate == null || !potentialDateInCurrentMonth.isAfter(recurrenceEndDate)) {
              return potentialDateInCurrentMonth;
            } else {
              return null; // Potential date is past end date
            }
          }
        }

        // No occurrence found, advance to the next month
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
        currentCandidate = DateTime(year, month, 
          min(targetRecurrenceDay, _daysInMonth(year, month)),
          currentCandidate.hour, currentCandidate.minute, 
          currentCandidate.second, currentCandidate.millisecond, 
          currentCandidate.microsecond);
        break;
      case 'none':
        return null; // Should be handled above
    }
  }
}