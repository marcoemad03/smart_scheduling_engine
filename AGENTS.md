# Flutter Smart Scheduling Engine - Development Guide

## Commands

### Run App (Development)
```bash
flutter run -d chrome
flutter run -d windows
```

### Build APK/AAB
```bash
flutter build apk --release
flutter build appbundle --release
```

### Run Tests
```bash
flutter test
flutter test --coverage
```

### Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Lint & Format
```bash
dart analyze
dart format .
flutter pub run custom_lint
```

## Architecture Notes
- Use Riverpod 2 for state management
- Follow repository pattern with clean architecture
- Feature-based folder structure
- All configurable values in systemSettings collection
- Store actual DateTime for shifts, never rely on shift templates alone