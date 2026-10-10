# Architecture Documentation

## Overview

This Flutter application follows a modern feature-based architecture with clean separation of concerns. The app is a financial tracking and investment management tool with local data storage.

## Project Structure

```
lib/
├── core/                    # Core application components
│   ├── app.dart            # Main application widget with routing
│   ├── db.dart             # SQLite database setup and migrations
│   ├── scaffold.dart       # Adaptive navigation scaffold
│   ├── theme/              # Material 3 theme configuration
│   └── utils/              # Utility functions
├── data/                   # Data layer
│   ├── models/            # Data models (Account, Tool, Activity, etc.)
│   └── repository/         # Data access repositories
├── feature/                # Feature-based modules
│   ├── account/           # Account management (BLoC-based)
│   ├── activity/          # Activity tracking
│   ├── event/             # Financial events
│   ├── report/            # Reports and analytics
│   └── tool_detail/       # Tool details view
└── src/                    # Legacy source code (being migrated)
```

## Architectural Patterns

### 1. BLoC (Business Logic Component) Pattern
The primary state management pattern used throughout the app:

```dart
class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  // Handles business logic for account management
}
```

**Key features:**
- Immutable states using sealed classes
- Event-driven architecture
- Clear separation of UI and business logic

### 2. Repository Pattern
Abstraction layer for data access:

```dart
class AccountRepository {
  Future<int> insert(Account action) async { ... }
  Future<Account> get(String id) async { ... }
  // Other CRUD operations
}
```

**Benefits:**
- Single source of truth for data operations
- Easy to test and mock
- Decouples business logic from data sources

### 3. Feature-Based Module Architecture
Each feature is self-contained with its own:

- **Presentation layer** (screens, widgets)
- **Logic layer** (BLoC/Cubit)
- **Data layer** (models, states)

## Technical Stack

### Dependencies
- **State Management**: flutter_bloc ^9.1.1
- **Navigation**: go_router ^15.0.0
- **Database**: sqflite with FFI support
- **Charts**: fl_chart ^1.1.1
- **Navigation**: adaptive_navigation
- **UUID**: uuid ^4.5.1

### Database
- **SQLite** as local database
- **Migration system** for schema changes
- **Event replay pattern** for data consistency

## Key Design Decisions

### 1. Local-First Architecture
- All data stored locally using SQLite
- No backend dependencies
- Offline-first approach

### 2. Event Replay Pattern
When data changes, the system:
1. Resets all tool values to zero
2. Replays all activities from database
3. Recalculates current values

This ensures consistency but may impact performance with large datasets.

### 3. Adaptive Design
- Uses `adaptive_navigation` for desktop support
- Consistent UI across all platforms
- Material 3 design system

### 4. UUID v7 for All IDs
- Uses UUID version 7 for all entity IDs
- Ensures unique identifiers
- Time-sortable for better indexing

## State Management Strategy

### BLoC Events Structure
```dart
@immutable
sealed class AccountsEvent {}

class AddAccountEvent extends AccountsEvent {
  final AccountSummary account;
  AddAccountEvent(this.account);
}

class ChangeAccountEvent extends AccountsEvent {
  final String accountId;
  final bool hideEvents;
  final bool excludeFromTotal;
  final bool remove;
}
```

### State Management Flow
1. UI triggers an event
2. BLoC processes the event
3. BLoC emits new state
4. UI rebuilds based on new state

## Data Layer

### Database Schema
- **accounts**: User accounts with settings
- **tools**: Financial instruments (stocks, bonds, etc.)
- **activities**: Buy/sell transactions
- **scheduled_transactions**: Recurring transactions

### Repository Pattern Implementation
Each repository provides:
- Create, Read, Update, Delete operations
- Domain-specific methods (e.g., `getExecutableEvents`)
- Clean API for business logic

## Tools (Typed Instruments)

An account holds any number of tools of any kind (`ToolType`: money, deposit,
credit, stocks, bonds, cryptocurrency, other) — multiple deposits/credits per
account are allowed.

Domain models: `lib/data/models/tools/`
- `typed_tool.dart` — sealed hierarchy `TypedTool` (Money/Deposit/Credit/Stock/Bond/Crypto/Other)
- `tool_kind.dart` — `ToolType/PayoutType/CreditPaymentType` enums
- `typed_tool_mapper.dart` — DB row ↔ typed model mapping (unknown kind → ArgumentError)

Strategies: `lib/feature/tools/domain/`
- `tool_valuation.dart` — value per kind: deposit = principal + daily accrued
  interest; credit = outstanding body (stored as a negative liability);
  money = quantity; securities = quantity × price; other = manual estimate
- `credit_schedule.dart` — annuity/differentiated: payment, interest/principal split
- `tool_operations.dart` — operations allowed per kind

Aggregation: account balance = Σ tool values (`AccountData._toolAccountValue`);
Total = Σ accounts with `excludeFromTotal=false`. Tool values are replayed from
`activities` (the DB row keeps metadata only). Executing a scheduled event
advances `next_execution_date`; the planner `Event.date` equals it.

Typing plan and its status: see `REFACTORING_PLAN.md`.

## Navigation

### GoRouter Configuration
- **Shell routes** for bottom navigation
- **Nested routes** for feature-specific navigation
- **Deep linking** support
- **Authentication guard** for protected routes

```dart
routes: [
  ShellRoute(
    navigatorKey: appShellNavigatorKey,
    routes: [
      GoRoute(path: '/accounts', builder: ...),
      GoRoute(path: '/activities', builder: ...),
    ],
  ),
]
```

## Performance Considerations

### Event Replay Optimization
- Tools reset to zero before replay
- Only relevant activities processed
- Debug logging for performance monitoring

### Database Optimization
- Indexes on frequently queried fields
- Batch operations for bulk inserts
- Connection pooling through sqflite

## Testing Strategy

### Unit Tests
- Repository layer tests
- BLoC logic tests
- Model validation tests

### Integration Tests
- Navigation flow testing
- Database operations testing
- UI interaction testing

## Future Improvements

1. **Dependency Injection**: Add provider or get_it
2. **Error Handling**: Global error handler
3. **Caching**: Implement data caching layer
4. **Testing**: Comprehensive test suite
5. **Performance**: Optimize event replay for large datasets

## Migration Guidelines

When adding new features:
1. Create feature module under `feature/`
2. Follow existing BLoC pattern
3. Add repository for data access
4. Implement tests
5. Update navigation routes

## File Naming Requirements

### Feature Modules
All feature modules must follow this naming pattern:
```
lib/feature/{feature_name}/
├── data/
│   ├── {feature_name}_models.dart
│   └── {feature_name}_repository.dart
├── presentation/
│   └── {feature_name}_{screen_name}.dart
├── {feature_name}_{component_type}.dart  # BLoC, Event, State files
└── test/
    └── {feature_name}_{component_type}_test.dart
```

### File Naming Conventions

#### File Names (snake_case)
All Dart files must use **snake_case** for filenames:
```dart
// ✅ Correct:
tool_detail_bloc.dart
tool_detail_event.dart
tool_detail_state.dart
tool_detail_screen.dart
tool_detail_models.dart
tool_detail_repository.dart
tool_detail_bloc_test.dart

// ❌ Incorrect:
toolDetailBloc.dart
toolDetailEvent.dart
toolDetailScreen.dart
```

#### Class Names (PascalCase)
Classes inside files must use **PascalCase**:
```dart
// ✅ Correct:
class ToolDetailBloc { ... }
class LoadToolDetail { ... }
class ToolDetailState { ... }
class ToolDetailScreen extends StatelessWidget { ... }
class ToolDetailDisplay { ... }

// ❌ Incorrect:
class tool_detail_bloc { ... }
class load_tool_detail { ... }
```

#### Variables and Methods (camelCase)
Use **camelCase** for variables, methods, and properties:
```dart
// ✅ Correct:
String toolName = 'Test';
void loadToolDetail() { ... }
final toolRepository = ToolRepository();
final List<Tool> tools = [];

// ❌ Incorrect:
String ToolName = 'Test';
void LoadToolDetail() { ... }
final ToolRepository = ToolRepository();
```

#### Constants (PascalCase or SCREAMING_SNAKE_CASE)
Use **PascalCase** for public constants or **SCREAMING_SNAKE_CASE** for private:
```dart
// ✅ Correct:
const double MAX_VALUE = 100.0;
const String DEFAULT_NAME = 'Default';
const int _PRIVATE_CONSTANT = 42;

// ❌ Incorrect:
const double maxValue = 100.0;
const String default_name = 'Default';
```

#### Enum Names (PascalCase)
Use **PascalCase** for enum types and **snake_case** for enum values:
```dart
// ✅ Correct:
enum ToolType {
  money,
  deposit,
  stock,
  bond
}

// ❌ Incorrect:
enum tool_type {
  Money,
  Deposit,
  Stock,
  Bond
}
```

### Examples
```dart
// File: tool_detail_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

// Class name (PascalCase)
class ToolDetailBloc extends Bloc<ToolDetailEvent, ToolDetailState> {
  // Variable name (camelCase)
  final ToolDetailRepository repository;
  
  // Method name (camelCase)
  Future<void> loadToolDetail() async {
    // Local variable (camelCase)
    final tool = await repository.get('toolId');
    return tool;
  }
}

// File: tool_detail_event.dart
import 'package:equatable/equatable.dart';

// Class name (PascalCase)
class LoadToolDetail extends Equatable {
  // Parameter name (camelCase)
  final String toolId;
  
  const LoadToolDetail(this.toolId);
  
  @override
  List<Object> get props => [toolId];
}
```

### Core Components
Files in `core/` directory use **snake_case** filenames but **PascalCase** class names:
```dart
// Files: snake_case
app.dart
db.dart
scaffold.dart

// Classes: PascalCase
class InvestApp extends StatelessWidget { ... }
class DatabaseHelper { ... }
class AdaptiveScaffold extends StatefulWidget { ... }
```

### Data Models
Models in `data/models/` follow the same pattern:
```dart
// Files: snake_case
tool.dart
account.dart
event.dart

// Classes: PascalCase
class Tool { ... }
class Account { ... }
class Event { ... }
```

## Code Style Guidelines

- Use `dart format` for consistent formatting
- Follow Dart/Flutter style guide
- Document public APIs
- Use meaningful variable names
- Keep functions small and focused
- Follow the file naming conventions above

