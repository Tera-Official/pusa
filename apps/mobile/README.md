# Pusa Mobile — Flutter (Android first)

This folder contains the Flutter mobile client for Pusa. The Next.js web application remains at the repository root. Both clients will use the same Pusa backend and financial ledger; the mobile app must never update balances directly.

## Current status

- Flutter app shell and Material 3 design foundation.
- Home dashboard, pockets, activity and profile tabs.
- Sample figures are clearly marked as demo data.
- Supabase Flutter SDK dependency and compile-time configuration hook are included.
- Authentication, live account data, financial operations and push notifications are not connected yet.

## Requirements

- Flutter SDK (stable channel; Flutter 3.24 or newer).
- Android Studio with Android SDK and platform tools.
- Android phone with Developer options and USB debugging enabled, or an Android emulator.

## Generate the Android platform project

From this directory, run:

```bash
flutter create --platforms=android --org com.pusa.smart_saving .
flutter pub get
flutter doctor
```

This generates the native Android Gradle wrapper and platform project using the installed Flutter SDK.

## Run on your Android phone

1. Enable Developer options on the phone (tap Build number seven times).
2. Enable USB debugging.
3. Connect the phone by USB and accept the debugging prompt.
4. Confirm the device is visible:

```bash
flutter devices
```

5. Run the app:

```bash
flutter run
```

Flutter hot reload is enabled in debug mode. Save a Dart file and press `r` in the running terminal to apply supported UI changes.

## Connect the Pusa Supabase project later

Pass the project URL and publishable key at run time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Only the Supabase publishable key belongs in a mobile app. Never put a service-role or secret key in Flutter, GitHub, or any client build.

## Build an installable Android APK

```bash
flutter build apk --release
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

## Important financial safety boundary

The initial app uses illustrative sample balances only. No real deposits, withdrawals, payment credentials or customer funds are handled in demo mode. A verified backend event and ledger posting must be the only way to change authoritative financial balances.
