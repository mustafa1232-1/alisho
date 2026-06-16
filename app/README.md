# Alisho Library App

Single Flutter application for customer, admin, and delivery roles.

## Highlights

- Role-based navigation after login
- Arabic-first RTL presentation with optional English support
- Riverpod state management
- go_router navigation
- dio API client
- secure token storage
- printing preview integration for desktop/mobile print flows
- responsive admin dashboard for Windows desktop

## Run

Windows desktop:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Android emulator:

```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

Use `http://10.0.2.2:4000` for the standard Android emulator bridge if you are not overriding the base URL in code.

## Quality Checks

```bash
flutter analyze
flutter test
flutter build windows
```
