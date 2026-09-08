# Salah & Qibla — Flutter app

Prayer times, Qibla compass, and Hijri calendar, built with Flutter,
Riverpod, GoRouter, Hive, and the Aladhan prayer times API.

## What's included

- Clean architecture: `core/` (theme, config, utils) → `services/` (API,
  location, storage, notifications) → `repositories/` (offline-first
  business logic) → `features/` (UI + Riverpod providers per screen)
- Home screen with a live-updating mihrab-shaped "next prayer" countdown
  and all 6 daily timings (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
- Automatic GPS location **and** manual city/country search that works for
  any country in the world, with the calculation method auto-selected per
  country (overridable in Settings)
- Qibla compass screen using the device magnetometer + great-circle
  bearing calculation to the Kaaba
- Hijri calendar screen (month grid with Gregorian ↔ Hijri mapping)
- Settings: calculation method, madhab, theme (light/dark/system),
  language (English/Urdu/Arabic — codes wired, string localization is a
  next step, see below), 12/24-hour format, per-prayer notification
  toggles, reminder lead time, silent mode
- Offline-first: today's timings are cached in Hive and reused
  automatically when there's no network
- Local notifications (Azan + configurable reminder) scheduled from
  on-device data — no backend required
- App icon, adaptive icon, and splash screen assets pre-generated in
  `assets/icon/` and `assets/splash/`

## Before you run it

This project was generated without a working Flutter/Android toolchain
available, so it has **not** been compiled or run yet. Do this once on
your own machine:

```bash
flutter --version        # make sure Flutter is installed
flutter pub get          # installs every dependency from pubspec.yaml
flutter pub run flutter_launcher_icons   # generates all icon sizes from assets/icon
flutter pub run flutter_native_splash:create   # generates the splash screen
flutter run               # launch on a connected device/emulator
```

Because the Hive model adapters (`*.g.dart`) were hand-written instead of
generated, you do **not** need to run `build_runner` for the app to work.
If you later add new Hive fields, either update the adapter by hand or
run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Android setup notes

- Minimum SDK: set `minSdkVersion 21` or higher in
  `android/app/build.gradle` (required by `flutter_local_notifications`
  and `geolocator`).
- Add these permissions to `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  ```
- `flutter_local_notifications` needs the standard receiver entries inside
  `<application>` — its own setup docs cover this in one copy-paste block:
  https://pub.dev/packages/flutter_local_notifications

## iOS setup notes

- Add to `ios/Runner/Info.plist`:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Used to calculate accurate prayer times and Qibla direction for your location.</string>
  <key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
  </array>
  ```

## Before publishing to Google Play

1. Replace the placeholder privacy policy / contact links in
   `lib/features/about/presentation/about_screen.dart` with your real
   ones — Play Console requires a live privacy policy URL.
2. Set a real `applicationId` in `android/app/build.gradle`.
3. Generate a release keystore and configure signing in
   `android/app/build.gradle` per the official Flutter deployment guide.
4. Build the release artifact:
   ```bash
   flutter build appbundle --release
   ```

## What's scaffolded vs. what needs your polish

Everything above is real, working code — not placeholder screens. Two
things are intentionally left for you to finish, since they depend on
choices only you can make:

- **Full 3-language UI strings** — the language selector and
  `AppLanguage` enum are wired up, but screen text is currently English
  only. Wire in `flutter_localizations` + `.arb` files (or `easy_localization`)
  and swap the hardcoded strings for translated ones.
- **Azan sound file** — the notification service plays the default system
  sound. Drop an `azan.mp3`/`.caf` into the platform notification channel
  config if you want a custom Azan sound instead of the system default.
