# Tool Detail Feature

This feature provides a detailed view of financial tools (stocks, bonds, deposits, etc.).

## Architecture

The feature follows the documented architecture patterns:

### Structure
```
lib/feature/tool_detail/
├── data/
│   ├── tool_detail_models.dart    # Feature-specific data models
│   └── toolDetailRepository.dart   # Repository for data access
├── presentation/
│   └── toolDetailScreen.dart       # UI screen
├── toolDetailBloc.dart             # BLoC for state management
├── toolDetailEvent.dart            # Events handled by BLoC
├── toolDetailState.dart            # States emitted by BLoC
└── test/
    └── toolDetailBloc_test.dart     # Unit tests for BLoC
```

### Key Components

#### 1. BLoC Pattern
- `ToolDetailBloc`: Handles business logic for loading tool details
- Uses sealed classes for immutable states
- Event-driven architecture

#### 2. Feature Isolation
- No cross-module dependencies
- Own data layer with `ToolDetailDisplay` model
- Repository pattern for data access

#### 3. State Management
- **ToolDetailLoading**: Loading in progress
- **ToolDetailLoaded**: Successfully loaded tool details
- **ToolDetailError**: Error occurred during loading

## Key Features

1. **Tool Detail Display**: Shows comprehensive information about a financial tool
2. **Error Handling**: Graceful error handling with user-friendly messages
3. **Type Safety**: Uses Dart's strong typing for all data models

## Dependencies

- Uses `ToolRepository` from `data` layer (external dependency)
- No dependencies on other features (account, activities, etc.)

## Usage

```dart
// Create and provide BLoC
BlocProvider(
  create: (_) => ToolDetailBloc(),
  child: ToolDetailScreen(
    accountId: 'account-id',
    toolId: 'tool-id',
  ),
);
```

## Notes

- The current implementation doesn't calculate quantity and currentValue from events.
- These values would need to be calculated using the event replay pattern from the account feature.
- This is a limitation of the current architecture where event replay is centralized.