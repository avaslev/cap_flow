import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math'; // Required for min in date calculations
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:google_fonts/google_fonts.dart'; // Required for custom fonts

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
DateTime? _calculateNextOccurrence(FinancialEvent event, DateTime now) {
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

// --- 1. DATA MODELS ---

/// Enum representing the type of a financial event.
enum FinancialEventType {
  income,
  expense,
  transfer,
}

/// Extension to provide display names and icons for FinancialEventType.
extension FinancialEventTypeExtension on FinancialEventType {
  String get displayName {
    switch (this) {
      case FinancialEventType.income:
        return 'Доход';
      case FinancialEventType.expense:
        return 'Расход';
      case FinancialEventType.transfer:
        return 'Перевод';
    }
  }

  IconData get icon {
    switch (this) {
      case FinancialEventType.income:
        return Icons.arrow_upward;
      case FinancialEventType.expense:
        return Icons.arrow_downward;
      case FinancialEventType.transfer:
        return Icons.swap_horiz;
    }
  }

  Color get color {
    switch (this) {
      case FinancialEventType.income:
        return Colors.green;
      case FinancialEventType.expense:
        return Colors.red;
      case FinancialEventType.transfer:
        return Colors.blueGrey;
    }
  }
}

/// Enum representing the recurrence type of a financial event.
enum RecurrenceType {
  none,
  weekly,
  monthly,
  annually,
  monthlyOnDay,
}

/// Extension to provide display names for RecurrenceType.
extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return 'Не повторяется';
      case RecurrenceType.weekly:
        return 'Каждую неделю';
      case RecurrenceType.monthly:
        return 'Каждый месяц (в тот же день)';
      case RecurrenceType.annually:
        return 'Каждый год';
      case RecurrenceType.monthlyOnDay:
        return 'Каждый месяц (в определенный день)';
    }
  }
}

/// Represents a financial wallet.
@immutable
class Wallet {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, icon: $icon, color: $color)';
  }
}

// Initial dummy wallet data
const List<Wallet> _initialWallets = <Wallet>[
  Wallet(id: 'w1', name: 'Основной счет', icon: Icons.account_balance_wallet, color: Colors.indigo),
  Wallet(id: 'w2', name: 'Наличные', icon: Icons.money, color: Colors.brown),
  Wallet(id: 'w3', name: 'Сбережения', icon: Icons.savings, color: Colors.teal),
];

/// Represents a single financial event.
@immutable
class FinancialEvent {
  final String id;
  final String name;
  final double amount;
  final FinancialEventType type;
  final String category;
  final DateTime date;
  final String walletId; // Source wallet for transfers
  final String? destinationWalletId; // Destination wallet for transfers, nullable
  final String? comment; // New: Optional comment field

  final RecurrenceType recurrenceType;
  final DateTime? recurrenceEndDate; // Nullable, end date for recurrence
  final int? recurrenceDayOfMonth; // For MonthlyOnDay, e.g., 15 for 15th of month

  const FinancialEvent({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.walletId,
    this.destinationWalletId, // Make it optional
    this.comment, // Initialize new field
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceEndDate,
    this.recurrenceDayOfMonth,
  });

  /// Creates a copy of this FinancialEvent with optional new values.
  FinancialEvent copyWith({
    String? id,
    String? name,
    double? amount,
    FinancialEventType? type,
    String? category,
    DateTime? date,
    String? walletId,
    String? destinationWalletId,
    String? comment, // Add to copyWith
    RecurrenceType? recurrenceType,
    DateTime? recurrenceEndDate,
    int? recurrenceDayOfMonth,
  }) {
    return FinancialEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      walletId: walletId ?? this.walletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      comment: comment ?? this.comment, // Use new field
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
    );
  }

  @override
  String toString() {
    return 'FinancialEvent(id: $id, name: $name, amount: $amount, type: ${type.displayName}, category: $category, date: $date, walletId: $walletId, destinationWalletId: $destinationWalletId, comment: $comment, recurrenceType: ${recurrenceType.displayName}, recurrenceEndDate: $recurrenceEndDate, recurrenceDayOfMonth: $recurrenceDayOfMonth)';
  }
}

// --- 2. BLOC DEFINITIONS ---

// FinancialEvent Bloc
// Events
abstract class FinancialEventEvent {
  const FinancialEventEvent();
}

class LoadFinancialEvents extends FinancialEventEvent {
  const LoadFinancialEvents();
}

class AddFinancialEvent extends FinancialEventEvent {
  final FinancialEvent event;
  const AddFinancialEvent(this.event);
}

class EditFinancialEvent extends FinancialEventEvent {
  final FinancialEvent event;
  const EditFinancialEvent(this.event);
}

class DeleteFinancialEvent extends FinancialEventEvent {
  final String eventId;
  const DeleteFinancialEvent(this.eventId);
}

// States
abstract class FinancialEventState {
  const FinancialEventState();
}

class FinancialEventLoading extends FinancialEventState {
  const FinancialEventLoading();
}

class FinancialEventLoaded extends FinancialEventState {
  final List<FinancialEvent> events;
  const FinancialEventLoaded(this.events);
}

class FinancialEventError extends FinancialEventState {
  final String message;
  const FinancialEventError(this.message);
}

// Bloc
class FinancialEventBloc extends Bloc<FinancialEventEvent, FinancialEventState> {
  FinancialEventBloc() : super(const FinancialEventLoaded(<FinancialEvent>[])) {
    on<LoadFinancialEvents>(_onLoadFinancialEvents);
    on<AddFinancialEvent>(_onAddFinancialEvent);
    on<EditFinancialEvent>(_onEditFinancialEvent);
    on<DeleteFinancialEvent>(_onDeleteFinancialEvent);

    // Initial dummy data
    add(AddFinancialEvent(FinancialEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '1',
      name: 'Зарплата',
      amount: 150000.0,
      type: FinancialEventType.income,
      category: 'Работа',
      date: DateTime.now().subtract(const Duration(days: 5)),
      walletId: _initialWallets[0].id, // Assign to first wallet
      comment: 'Ежемесячная оплата труда',
      recurrenceType: RecurrenceType.monthly,
      recurrenceEndDate: DateTime.now().add(const Duration(days: 365 * 2)), // Two years from now
    )));
    add(AddFinancialEvent(FinancialEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '2',
      name: 'Поход в магазин',
      amount: 3500.0,
      type: FinancialEventType.expense,
      category: 'Продукты',
      date: DateTime.now().subtract(const Duration(days: 2)),
      walletId: _initialWallets[0].id, // Assign to first wallet
      comment: 'Продукты на неделю',
    )));
    add(AddFinancialEvent(FinancialEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '3',
      name: 'Перевод другу',
      amount: 1000.0,
      type: FinancialEventType.transfer,
      category: 'Долг',
      date: DateTime.now(),
      walletId: _initialWallets[1].id, // From second wallet
      destinationWalletId: _initialWallets[0].id, // To first wallet
      comment: 'Возврат части долга',
      recurrenceType: RecurrenceType.weekly,
      recurrenceEndDate: DateTime.now().add(const Duration(days: 90)), // 3 months from now
    )));
  }

  void _onLoadFinancialEvents(LoadFinancialEvents event, Emitter<FinancialEventState> emit) {
    if (state is FinancialEventLoaded) {
      emit(FinancialEventLoaded((state as FinancialEventLoaded).events));
    } else {
      emit(const FinancialEventLoaded(<FinancialEvent>[]));
    }
  }

  void _onAddFinancialEvent(AddFinancialEvent event, Emitter<FinancialEventState> emit) {
    if (state is FinancialEventLoaded) {
      final List<FinancialEvent> updatedEvents = List<FinancialEvent>.from((state as FinancialEventLoaded).events)
        ..add(event.event);
      // Sort by date, most recent first
      updatedEvents.sort((FinancialEvent a, FinancialEvent b) => b.date.compareTo(a.date));
      emit(FinancialEventLoaded(updatedEvents));
    }
  }

  void _onEditFinancialEvent(EditFinancialEvent event, Emitter<FinancialEventState> emit) {
    if (state is FinancialEventLoaded) {
      final List<FinancialEvent> updatedEvents = (state as FinancialEventLoaded).events.map<FinancialEvent>((FinancialEvent e) {
        return e.id == event.event.id ? event.event : e;
      }).toList();
      // Sort by date, most recent first
      updatedEvents.sort((FinancialEvent a, FinancialEvent b) => b.date.compareTo(a.date));
      emit(FinancialEventLoaded(updatedEvents));
    }
  }

  void _onDeleteFinancialEvent(DeleteFinancialEvent event, Emitter<FinancialEventState> emit) {
    if (state is FinancialEventLoaded) {
      final List<FinancialEvent> updatedEvents = (state as FinancialEventLoaded).events.where((FinancialEvent e) => e.id != event.eventId).toList();
      emit(FinancialEventLoaded(updatedEvents));
    }
  }
}

// Wallet Bloc
// Events
abstract class WalletEvent {
  const WalletEvent();
}

class LoadWallets extends WalletEvent {
  const LoadWallets();
}

// States
abstract class WalletState {
  const WalletState();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletLoaded extends WalletState {
  final List<Wallet> wallets;
  const WalletLoaded(this.wallets);
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);
}

// Bloc
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc() : super(const WalletLoaded(_initialWallets)) {
    on<LoadWallets>(_onLoadWallets);
  }

  void _onLoadWallets(LoadWallets event, Emitter<WalletState> emit) {
    // In a real app, this would load from a repository
    // For now, it just ensures the current state is emitted, or loads initial dummy data.
    if (state is WalletLoaded) {
      emit(WalletLoaded((state as WalletLoaded).wallets));
    } else {
      emit(const WalletLoaded(_initialWallets));
    }
  }
}

// --- 3. UI COMPONENTS ---

class FinancialEventPlannerApp extends StatelessWidget {
  const FinancialEventPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme defaultTextTheme = Theme.of(context).textTheme;
    final TextTheme customTextTheme = GoogleFonts.montserratTextTheme(defaultTextTheme).copyWith(
      titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.openSans(),
      bodyMedium: GoogleFonts.openSans(),
      labelLarge: GoogleFonts.openSans(fontWeight: FontWeight.w600),
    );

    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FinancialEventBloc>(
          create: (BuildContext context) => FinancialEventBloc(),
        ),
        BlocProvider<WalletBloc>(
          create: (BuildContext context) => WalletBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Финансовый планировщик',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: customTextTheme,
          appBarTheme: AppBarTheme(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            centerTitle: true,
            elevation: 4.0,
            titleTextStyle: customTextTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          ),
          cardTheme: CardThemeData(
            elevation: 2.0,
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
          ),
          listTileTheme: ListTileThemeData(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            titleTextStyle: customTextTheme.titleMedium,
            subtitleTextStyle: customTextTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
            ),
            labelStyle: customTextTheme.bodyMedium,
            hintStyle: customTextTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            prefixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            suffixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50), // Make button wider
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              textStyle: customTextTheme.labelLarge?.copyWith(fontSize: 18),
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: customTextTheme.labelLarge,
            ),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            titleTextStyle: customTextTheme.titleMedium,
            contentTextStyle: customTextTheme.bodyMedium,
          ),
        ),
        home: const FinancialEventOverviewPage(),
      ),
    );
  }
}

class FinancialEventOverviewPage extends StatelessWidget {
  const FinancialEventOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансовый планировщик'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить событие',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const FinancialEventFormPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<FinancialEventBloc, FinancialEventState>(
        builder: (BuildContext context, FinancialEventState eventState) {
          if (eventState is FinancialEventLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (eventState is FinancialEventLoaded) {
            if (eventState.events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.event_note, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Нет финансовых событий.\nНажмите "+" чтобы добавить новое.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              );
            }
            final List<Wallet> wallets;
            final WalletState walletState = context.watch<WalletBloc>().state;
            if (walletState is WalletLoaded) {
              wallets = walletState.wallets;
            } else {
              wallets = _initialWallets; // Fallback to initial wallets
            }

            String getWalletNameById(String walletId) {
              return wallets.firstWhere((Wallet w) => w.id == walletId, orElse: () => _initialWallets[0]).name;
            }

            return ListView.builder(
              itemCount: eventState.events.length,
              itemBuilder: (BuildContext context, int index) {
                final FinancialEvent event = eventState.events[index];
                final String formattedDate = DateFormat('dd.MM.yyyy').format(event.date);
                final String sourceWalletName = getWalletNameById(event.walletId);
                String subtitleTextLines = ''; // This will build our multi-line subtitle

                String recurrenceInfoText = '';
                if (event.recurrenceType != RecurrenceType.none) {
                  final DateTime? nextOccurrence = _calculateNextOccurrence(event, DateTime.now());
                  if (nextOccurrence != null) {
                    recurrenceInfoText = 'Следующее: ${DateFormat('dd.MM.yyyy').format(nextOccurrence)}';
                  } else {
                    recurrenceInfoText = 'Повторяется: ${event.recurrenceType.displayName} (завершено)';
                  }
                }

                if (event.type == FinancialEventType.transfer && event.destinationWalletId != null) {
                  final String destinationWalletName = getWalletNameById(event.destinationWalletId!);
                  subtitleTextLines += 'Перевод: $sourceWalletName -> $destinationWalletName\n${event.category} - $formattedDate';
                } else {
                  subtitleTextLines += '${event.type.displayName} - ${event.category} ($sourceWalletName)\n$formattedDate';
                }

                // Append recurrence info if available
                if (recurrenceInfoText.isNotEmpty) {
                  subtitleTextLines += '\n$recurrenceInfoText';
                }

                return Dismissible(
                  key: ValueKey<String>(event.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: const Icon(Icons.delete, color: Colors.white, size: 30),
                  ),
                  confirmDismiss: (DismissDirection direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text("Подтверждение удаления"),
                          content: const Text("Вы уверены, что хотите удалить это событие навсегда?"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text("Отмена"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text("Удалить"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (DismissDirection direction) {
                    context.read<FinancialEventBloc>().add(DeleteFinancialEvent(event.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Событие "${event.name}" удалено')),
                    );
                  },
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: event.type.color.withOpacity(0.1),
                        child: Icon(
                          event.type.icon,
                          color: event.type.color,
                        ),
                      ),
                      title: Text(
                        event.name,
                        style: Theme.of(context).listTileTheme.titleTextStyle,
                      ),
                      subtitle: Text(
                        subtitleTextLines,
                        style: Theme.of(context).listTileTheme.subtitleTextStyle,
                      ),
                      trailing: Text(
                        '${event.type == FinancialEventType.expense ? '-' : ''}${event.amount.toStringAsFixed(2)} ₽',
                        style: TextStyle(
                            color: event.type.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => FinancialEventFormPage(event: event),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }
          if (eventState is FinancialEventError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.error_outline, size: 80, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Произошла ошибка: ${eventState.message}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class FinancialEventFormPage extends StatefulWidget {
  final FinancialEvent? event; // Nullable for adding, non-null for editing

  const FinancialEventFormPage({super.key, this.event});

  @override
  State<FinancialEventFormPage> createState() => _FinancialEventFormPageState();
}

class _FinancialEventFormPageState extends State<FinancialEventFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController; // Now used for Autocomplete
  late FocusNode _categoryFocusNode; // Required for Autocomplete when supplying a TextEditingController
  late TextEditingController _commentController;
  late FinancialEventType _selectedType;
  late DateTime _selectedDate;
  late String _selectedWalletId; // Source wallet
  late String? _selectedDestinationWalletId; // Destination wallet, nullable

  late RecurrenceType _selectedRecurrenceType;
  late DateTime? _selectedRecurrenceEndDate;
  late int? _selectedRecurrenceDayOfMonth; // For MonthlyOnDay

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _amountController = TextEditingController(text: widget.event?.amount.toStringAsFixed(2) ?? '');
    _categoryController = TextEditingController(text: widget.event?.category ?? ''); // Initialize with existing category
    _categoryFocusNode = FocusNode(); // Initialize the FocusNode
    _commentController = TextEditingController(text: widget.event?.comment ?? '');
    _selectedType = widget.event?.type ?? FinancialEventType.expense; // Default to expense
    _selectedDate = widget.event?.date ?? DateTime.now();
    _selectedWalletId = widget.event?.walletId ?? _initialWallets[0].id; // Default to first wallet

    // Initialize destination wallet for transfer events, if editing
    _selectedDestinationWalletId = widget.event?.type == FinancialEventType.transfer
        ? widget.event?.destinationWalletId ?? _initialWallets[0].id // Default if not set
        : null;

    // If destination wallet is null for a transfer event during creation, set it to a valid default
    if (_selectedType == FinancialEventType.transfer && _selectedDestinationWalletId == null) {
      _selectedDestinationWalletId = _initialWallets.firstWhere(
            (Wallet w) => w.id != _selectedWalletId,
            orElse: () => _initialWallets[0],
          ).id;
    }

    _selectedRecurrenceType = widget.event?.recurrenceType ?? RecurrenceType.none;
    _selectedRecurrenceEndDate = widget.event?.recurrenceEndDate;
    _selectedRecurrenceDayOfMonth = widget.event?.recurrenceDayOfMonth;

    // If it's a new event and MonthlyOnDay is selected, set a reasonable default day
    if (widget.event == null && _selectedRecurrenceType == RecurrenceType.monthlyOnDay && _selectedRecurrenceDayOfMonth == null) {
      _selectedRecurrenceDayOfMonth = _selectedDate.day;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose(); // Dispose the FocusNode
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Подтвердить',
      fieldLabelText: 'Дата события',
      errorFormatText: 'Неверный формат даты',
      errorInvalidText: 'Дата вне диапазона',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // If MonthlyOnDay is selected, and it was defaulting to _selectedDate.day, update it.
        // Or if it's a new event and MonthlyOnDay is active, default it.
        if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && widget.event == null) {
          _selectedRecurrenceDayOfMonth = _selectedDate.day;
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRecurrenceEndDate ?? _selectedDate.add(const Duration(days: 1)),
      firstDate: _selectedDate.add(const Duration(days: 1)), // Must be after event date
      lastDate: DateTime(2101),
      helpText: 'Выберите дату окончания',
      cancelText: 'Отмена',
      confirmText: 'Подтвердить',
      fieldLabelText: 'Дата окончания повторения',
      errorFormatText: 'Неверный формат даты',
      errorInvalidText: 'Дата вне диапазона',
    );
    if (picked != null) {
      setState(() {
        _selectedRecurrenceEndDate = picked;
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final String id = widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(); // Simple unique ID
      final FinancialEvent newEvent = FinancialEvent(
        id: id,
        name: _nameController.text,
        amount: double.parse(_amountController.text),
        type: _selectedType,
        category: _categoryController.text.trim().isEmpty ? 'Без категории' : _categoryController.text.trim(),
        date: _selectedDate,
        walletId: _selectedWalletId,
        destinationWalletId: _selectedType == FinancialEventType.transfer ? _selectedDestinationWalletId : null,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(), // Save comment
        recurrenceType: _selectedRecurrenceType,
        recurrenceEndDate: _selectedRecurrenceType == RecurrenceType.none ? null : _selectedRecurrenceEndDate,
        recurrenceDayOfMonth: _selectedRecurrenceType == RecurrenceType.monthlyOnDay ? (_selectedRecurrenceDayOfMonth ?? _selectedDate.day) : null,
      );

      if (widget.event == null) {
        // Adding new event
        context.read<FinancialEventBloc>().add(AddFinancialEvent(newEvent));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Событие "${newEvent.name}" добавлено')),
        );
      } else {
        // Editing existing event
        context.read<FinancialEventBloc>().add(EditFinancialEvent(newEvent));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Событие "${newEvent.name}" обновлено')),
        );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique categories from loaded financial events
    final FinancialEventState eventState = context.watch<FinancialEventBloc>().state;
    List<String> allCategories = <String>[];
    if (eventState is FinancialEventLoaded) {
      allCategories = eventState.events
          .map<String>((FinancialEvent e) => e.category)
          .where((String category) => category.isNotEmpty && category != 'Без категории') // Exclude empty/default
          .toSet() // Get unique categories
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Добавить событие' : 'Редактировать событие'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название события',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите сумму';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Некорректный формат суммы';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Сумма должна быть положительной';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<FinancialEventType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип события',
                  prefixIcon: Icon(Icons.category),
                ),
                items: FinancialEventType.values.map<DropdownMenuItem<FinancialEventType>>((FinancialEventType type) {
                  return DropdownMenuItem<FinancialEventType>(
                    value: type,
                    child: Row(
                      children: <Widget>[
                        Icon(type.icon, color: type.color),
                        const SizedBox(width: 10),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (FinancialEventType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                      // Reset destination wallet if type is not transfer
                      if (newValue != FinancialEventType.transfer) {
                        _selectedDestinationWalletId = null;
                      } else {
                        // If switching to transfer, try to set a valid default destination
                        final WalletState walletState = context.read<WalletBloc>().state;
                        if (walletState is WalletLoaded) {
                          _selectedDestinationWalletId = (walletState.wallets.firstWhere(
                            (Wallet w) => w.id != _selectedWalletId,
                            orElse: () => walletState.wallets.isNotEmpty ? walletState.wallets[0] : _initialWallets[0],
                          )).id;
                        } else {
                          _selectedDestinationWalletId = _initialWallets.firstWhere(
                            (Wallet w) => w.id != _selectedWalletId,
                            orElse: () => _initialWallets[0],
                          ).id;
                        }
                      }
                    });
                  }
                },
                validator: (FinancialEventType? value) {
                  if (value == null) {
                    return 'Пожалуйста, выберите тип';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return allCategories.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  }).take(5); // Limit suggestions to 5
                },
                onSelected: (String selection) {
                  _categoryController.text = selection;
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Use the provided textEditingController and focusNode for the TextFormField.
                  return TextFormField(
                    controller: textEditingController, // Use the controller provided by Autocomplete
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Категория (необязательно)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onFieldSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                  );
                },
                // Pass our state-managed controller and focus node to Autocomplete.
                // Autocomplete will then use these for its internal TextFormField and pass them back to fieldViewBuilder.
                textEditingController: _categoryController,
                focusNode: _categoryFocusNode,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 3, // Allow multiple lines for comments
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16.0),
              BlocBuilder<WalletBloc, WalletState>(
                builder: (BuildContext context, WalletState walletState) {
                  if (walletState is WalletLoaded) {
                    return Column(
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          value: _selectedWalletId,
                          decoration: InputDecoration(
                            labelText: _selectedType == FinancialEventType.transfer ? 'Кошелек-отправитель' : 'Кошелек',
                            prefixIcon: const Icon(Icons.wallet),
                          ),
                          items: walletState.wallets.map<DropdownMenuItem<String>>((Wallet wallet) {
                            return DropdownMenuItem<String>(
                              value: wallet.id,
                              child: Row(
                                children: <Widget>[
                                  Icon(wallet.icon, color: wallet.color),
                                  const SizedBox(width: 10),
                                  Text(wallet.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedWalletId = newValue;
                                // Ensure destination wallet is not the same as source if it's a transfer
                                if (_selectedType == FinancialEventType.transfer && _selectedDestinationWalletId == newValue) {
                                  _selectedDestinationWalletId = (walletState.wallets.firstWhere(
                                        (Wallet w) => w.id != newValue,
                                    orElse: () => walletState.wallets.isNotEmpty ? walletState.wallets[0] : _initialWallets[0],
                                  )).id;
                                }
                              });
                            }
                          },
                          validator: (String? value) {
                            if (value == null) {
                              return 'Пожалуйста, выберите кошелек';
                            }
                            return null;
                          },
                        ),
                        if (_selectedType == FinancialEventType.transfer) ...<Widget>[
                          const SizedBox(height: 16.0),
                          DropdownButtonFormField<String>(
                            value: _selectedDestinationWalletId,
                            decoration: const InputDecoration(
                              labelText: 'Кошелек-получатель',
                              prefixIcon: Icon(Icons.send_to_mobile),
                            ),
                            items: walletState.wallets
                                .where((Wallet wallet) => wallet.id != _selectedWalletId) // Cannot transfer to same wallet
                                .map<DropdownMenuItem<String>>((Wallet wallet) {
                              return DropdownMenuItem<String>(
                                value: wallet.id,
                                child: Row(
                                  children: <Widget>[
                                    Icon(wallet.icon, color: wallet.color),
                                    const SizedBox(width: 10),
                                    Text(wallet.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedDestinationWalletId = newValue;
                                });
                              }
                            },
                            validator: (String? value) {
                              if (value == null) {
                                return 'Пожалуйста, выберите кошелек-получатель';
                              }
                              if (value == _selectedWalletId) {
                                return 'Кошелек-получатель не может быть тем же, что и кошелек-отправитель';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    );
                  }
                  return const SizedBox.shrink(); // Or a loading indicator
                },
              ),
              const SizedBox(height: 16.0),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата события',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  baseStyle: Theme.of(context).textTheme.titleMedium,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Icon(Icons.edit_calendar),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<RecurrenceType>(
                value: _selectedRecurrenceType,
                decoration: const InputDecoration(
                  labelText: 'Повторение',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: RecurrenceType.values.map<DropdownMenuItem<RecurrenceType>>((RecurrenceType type) {
                  return DropdownMenuItem<RecurrenceType>(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (RecurrenceType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedRecurrenceType = newValue;
                      // Reset end date and day of month if recurrence is none
                      if (_selectedRecurrenceType == RecurrenceType.none) {
                        _selectedRecurrenceEndDate = null;
                        _selectedRecurrenceDayOfMonth = null;
                      } else if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && _selectedRecurrenceDayOfMonth == null) {
                        _selectedRecurrenceDayOfMonth = _selectedDate.day; // Default to event's day
                      }
                    });
                  }
                },
              ),
              if (_selectedRecurrenceType != RecurrenceType.none) ...<Widget>[
                const SizedBox(height: 16.0),
                InkWell(
                  onTap: () => _selectRecurrenceEndDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата окончания повторения (необязательно)',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                    baseStyle: Theme.of(context).textTheme.titleMedium,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _selectedRecurrenceEndDate == null
                              ? 'Никогда'
                              : DateFormat('dd.MM.yyyy').format(_selectedRecurrenceEndDate!),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Icon(Icons.edit_calendar),
                      ],
                    ),
                  ),
                ),
              ],
              if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay) ...<Widget>[
                const SizedBox(height: 16.0),
                DropdownButtonFormField<int>(
                  value: _selectedRecurrenceDayOfMonth ?? _selectedDate.day, // Default to event date's day
                  decoration: const InputDecoration(
                    labelText: 'День месяца для повторения',
                    prefixIcon: Icon(Icons.calendar_view_day),
                  ),
                  items: List<int>.generate(31, (int i) => i + 1).map<DropdownMenuItem<int>>((int day) {
                    return DropdownMenuItem<int>(
                      value: day,
                      child: Text('День $day'),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedRecurrenceDayOfMonth = newValue;
                    });
                  },
                  validator: (int? value) {
                    if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && value == null) {
                      return 'Пожалуйста, выберите день месяца';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32.0),
              ElevatedButton.icon(
                onPressed: _saveEvent,
                icon: const Icon(Icons.save),
                label: Text(widget.event == null ? 'Сохранить событие' : 'Обновить событие'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinancialEventPlannerApp());
}