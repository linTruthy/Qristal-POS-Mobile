# Qristal Mobile (POS Terminal)

The offline-first POS terminal application for the Qristal POS system. Built with Flutter, it runs on Android, iOS, and Windows and is designed for waitstaff and cashiers at the point of sale.

Developed and maintained by **[Truthy Systems](https://truthysystems.com)**.

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **Local database:** Drift (SQLite)
- **State management:** Riverpod
- **Auth:** JWT stored via `flutter_secure_storage`
- **Printing:** Bluetooth thermal receipt printer
- **Error tracking:** Sentry
- **Real-time:** WebSocket (connected to `qristal_api`)

---

## Features

- PIN-based login with role-aware UI (Cashier, Waiter, Kitchen, Manager, Owner)
- Offline-first order taking — works without internet
- Background sync — push unsynced orders/payments/shifts, pull menu and table updates
- Cart management with product modifiers and sides
- Kitchen routing — items dispatched to Kitchen, Bar, Barista, etc.
- Table & floor plan selection
- Shift management — open/close shifts with starting and actual cash reconciliation
- Receipt printing via Bluetooth thermal printer
- Kitchen display screen (KDS) for kitchen staff
- Real-time order status updates via WebSocket

---

## Prerequisites

- Flutter SDK 3.x
- Android SDK / Xcode (for mobile targets) or Visual Studio (for Windows)
- A running instance of `qristal_api`

---

## Setup

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Configure the API URL

Edit `lib/core/constants/api_constants.dart`:

```dart
static String get baseUrl {
  return 'https://your-api-url.com'; // Replace with your API endpoint
}
```

### 3. Generate Drift database code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the app

```bash
# Android
flutter run

# Windows
flutter run -d windows
```

---

## Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Windows
flutter build windows --release
```

---

## Project Structure

```
lib/
  core/
    constants/        # API endpoints, role definitions
    providers/        # Database provider
    theme/            # App theme
  database/           # Drift database schema & generated code
  features/
    auth/             # Login screen, auth service, auth provider
    hardware/         # Bluetooth printer service & receipt generator
    kitchen/          # Kitchen display screen
    pos/              # Dashboard, cart, menu provider, order service, payment modal
    shifts/           # Open/close shift screens and provider
    sync/             # Sync provider and queue
    tables/           # Floor plan screen
  services/
    sync_service.dart     # Pull/push sync logic
    websocket_service.dart
  main.dart
```

---

## Sync Architecture

The mobile app uses a timestamp-based sync strategy:

- **Pull** — fetches menu, tables, and shifts updated since the last sync timestamp
- **Push** — sends unsynced orders, payments, shifts, and table status changes to the API
- Sync runs on app start and can be triggered manually

---

## Supported Platforms

| Platform | Status |
|----------|--------|
| Android | ✅ Supported |
| Windows | ✅ Supported |
| iOS | 🔧 Configured (not primary target) |

---

## Developer

Built by **[Truthy Systems](https://truthysystems.com)**.