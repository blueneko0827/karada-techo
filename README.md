# からだ手帖 (Karada Techo)

A Japanese health-measurement app built with Flutter. You record weight, blood pressure, heart rate, body temperature, blood glucose and body-fat percentage. It shows trends, pie-chart breakdowns, insights, goals and reminders, and makes a report to show your doctor. All data stays on the device.

## What's in it

| Screen | What it does |
|---|---|
| ホーム | Today's checklist (driven by reminders), latest value per metric with status chip and 14-day sparkline, morning blood-pressure pie chart, weekly insights |
| 推移 | Line chart for 7/30/90 days (tap or drag to read points), reference lines, stats, a pie chart of categories, and the list of readings with delete |
| 記録 | Input form for each metric with range checks, full-width digit support, date/time pickers, measuring tips, and notes |
| 目標 | Weight and body-fat goals with an estimated finish date, a morning blood-pressure target, and a weekly measuring habit |
| レポート | Doctor report preview, A4 PDF (print or share), copy as text |
| 設定 | Name and height (for BMI), reminder times, Apple Health / Health Connect sync, sample data, delete all data |

Status labels use Japanese reference ranges and are shown as general guidance, never as a diagnosis:
- Home blood pressure: JSH 2019
- BMI: JASSO
- Fasting glucose: JDS
- Fever guide: 37.5 ℃

## Requirements

- **Flutter 3.32 or newer** (`flutter --version`; update with `flutter upgrade`)
- Android Studio with an emulator, or an Android phone with USB debugging
- iOS builds need a Mac with Xcode (see below)

## Get a test APK without installing Flutter (GitHub Actions)

1. Create a new **private** repository on GitHub. It can be empty.
2. Push this folder to it:
   ```
   git init
   git add .
   git commit -m "first build"
   git branch -M main
   git remote add origin https://github.com/<you>/karada_techo.git
   git push -u origin main
   ```
3. Open the repo's **Actions** tab. The *Build test APK* run takes about 10 minutes.
4. When it finishes, open **Releases** on your phone (signed in to GitHub). Download `karada-techo-N.apk` from the newest "テストビルド" release.
5. Allow "提供元不明のアプリ" (install unknown apps) for your browser when Android asks, then install.

Every later push to `main` builds a new numbered APK. The APK is signed with a debug key, which is fine for testing but not for Google Play.

## Run it on Android (Windows)

```powershell
cd karada_techo
powershell -ExecutionPolicy Bypass -File .\setup.ps1
flutter run
```

`setup.ps1` does six things:
1. Generates the `android/` and `ios/` folders.
2. Installs the prepared AndroidManifest (notification, Health Connect and history permissions).
3. Adds the notification icon.
4. Switches `MainActivity` to `FlutterFragmentActivity`.
5. Sets `minSdk = 26` and enables core-library desugaring.
6. Runs `pub get` and generates the launcher icons from the logo.

**PDF font:** the PDF report needs a Japanese font. Put `NotoSansJP-Regular.ttf` in `assets/fonts/` (instructions in `assets/fonts/README.txt`). The rest of the app works without it.

**Tests:**

```powershell
flutter test
```

## iOS (on a Mac)

1. Run `flutter create --org jp.kaitosoft --platforms ios .`, then `flutter pub get`.
2. In `ios/Podfile`, set `platform :ios, '14.0'`.
3. Add the keys in `platform_setup/ios/Info.plist-additions.xml` to `ios/Runner/Info.plist`.
4. Replace `ios/Runner/AppDelegate.swift` with `platform_setup/ios/AppDelegate.swift`.
5. In Xcode, go to Runner → Signing & Capabilities and add **HealthKit**.
6. Run `flutter run` on a device. HealthKit doesn't work in the simulator.

## Project layout

```
lib/
  main.dart              open DB, load settings, schedule reminders
  app.dart               MaterialApp (ja-JP), onboarding vs home, auto health sync
  models/                Entry, metric definitions, settings (JSON)
  domain/                classification, insights, report data, chart math, sample data (pure Dart, unit-tested)
  data/                  SQLite (sqflite) database + repository
  state/providers.dart   Riverpod AppController — the only place state changes
  services/              reminders, Health sync, PDF report, SVG charts for the PDF
  theme/palette.dart     blue / green / gold / red palette, light + dark
  widgets/               logo, line/spark/pie charts (CustomPainter), shared UI
  screens/               the six screens + onboarding
platform_setup/          Android + iOS files the setup script copies in
```

The logo and every chart are drawn with `CustomPainter`, so there are no chart-library version issues.

## Decisions and next steps

- **Encryption at rest:** to encrypt the database file, swap `sqflite` for `sqflite_sqlcipher` and keep the key in `flutter_secure_storage`. Only `lib/data/database.dart` changes.
- **Time zone:** reminders use Asia/Tokyo. For other markets, add `flutter_timezone` in `NotificationService.init`.
- **Store release:**
  - Google Play requires the Health apps declaration and a privacy policy URL for Health Connect permissions.
  - Apple reviews HealthKit apps under guideline 5.1.3.
  - Keep insight wording as general guidance, as it is now.
- **Not yet built:** cloud backup / multi-device sync, family sharing, English UI.
