# HabitMove Flutter App

A full-featured student mobile app for the [HabitMove Yoga platform](https://habitmove.com), built with Flutter.

---

## Features

| Screen | Description |
|---|---|
| **Login / Register** | Full auth flow with forgot password |
| **Dashboard** | Progress overview, stats, recent courses |
| **Courses** | Browse, search & filter all yoga courses |
| **Course Detail** | About, reviews, and full enroll flow |
| **Enroll** | Coupon validation + Stripe/PayPal payment |
| **Quizzes** | Take quizzes, submit answers, view results |
| **Leaderboard** | Top scorers per quiz or globally |
| **Certificates** | View & download earned certificates |
| **Support Tickets** | Create, view, reply to tickets with status tracking |
| **Zoom Scheduler** | View live sessions, join, watch recordings, set reminders |
| **Offline Mode** | Hive cache for courses/dashboard/quizzes, connectivity banner |

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.22.0 |
| Dart SDK | ≥ 3.2.0 |
| Android Studio / Xcode | Latest stable |
| Android: minSdkVersion | 21 (Android 5.0+) |
| iOS: deployment target | 13.0+ |

Install Flutter: https://docs.flutter.dev/get-started/install

---

## Setup

### 1. Get dependencies

```bash
flutter pub get
```

### 2. Add fonts (required)

Download and place these font files in `assets/fonts/`:

```
assets/fonts/
├── DMSerifDisplay-Regular.ttf
├── DMSerifDisplay-Italic.ttf
├── DMSans-Regular.ttf
├── DMSans-Medium.ttf
└── DMSans-SemiBold.ttf
```

Download from: https://fonts.google.com/specimen/DM+Serif+Display  
and: https://fonts.google.com/specimen/DM+Sans

### 3. Create asset directories

```bash
mkdir -p assets/images assets/icons assets/fonts
touch assets/images/.gitkeep assets/icons/.gitkeep
```

### 4. Run the app

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# List available devices
flutter devices
```

### 5. Build for release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Xcode + Apple Developer account)
flutter build ios --release
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, bottom nav shell, auth gate
├── api/
│   └── api_client.dart              # All HTTP calls, ApiException, global `api` singleton
├── models/
│   └── models.dart                  # UserModel, CourseModel, QuizModel, etc.
├── providers/
│   └── auth_provider.dart           # Auth state (ChangeNotifier), localStorage persistence
├── theme/
│   └── app_theme.dart               # AppColors, AppTextStyles, AppTheme.light
├── widgets/
│   └── widgets.dart                 # PrimaryButton, AppTextField, CourseImage, etc.
└── screens/
    ├── auth/
    │   ├── login_screen.dart         # Sign in + forgot password
    │   └── register_screen.dart     # Create account
    ├── dashboard/
    │   ├── dashboard_screen.dart    # Stats + recent learning
    │   └── profile_screen.dart     # User profile + settings
    ├── courses/
    │   ├── courses_screen.dart      # Browse + search grid
    │   └── course_detail_screen.dart # Tabs: about / reviews / enroll
    ├── quiz/
    │   └── quiz_screen.dart         # Quiz list + play flow + leaderboard
    ├── membership/
    │   └── membership_screen.dart   # Plan selector, subscribe, active card, cancel
    ├── discussion/
    │   └── discussion_screen.dart   # Course chat, image attachments, pagination
    ├── tickets/
    │   └── tickets_screen.dart      # List, create, reply to support tickets
    ├── zoom/
    │   └── zoom_sessions_screen.dart # Live sessions, recordings, calendar, reminders
    └── offline/
        └── offline_manager_screen.dart  # Cache stats, clear, connectivity status

services/
├── notification_service.dart        # FCM + local notifications
└── offline_cache_service.dart       # Hive cache with TTL + connectivity watcher

widgets/
├── widgets.dart                     # Shared UI components
└── offline_banner.dart              # Animated offline banner + connectivity dot
```

---

## API

Base URL: `https://habitmove.com/api/v1`  
Auth: Laravel Sanctum bearer tokens, persisted via `shared_preferences`.

All calls are in `lib/api/api_client.dart`. The global `api` singleton is imported wherever needed:

```dart
import 'package:habitmove/api/api_client.dart';

final courses = await api.getCourses(search: 'beginner');
```

---

## Customisation

### Change brand colors
Edit `lib/theme/app_theme.dart` — update `AppColors.sage*` and `AppColors.warm*`.

### Change API base URL
Edit the `_base` constant at the top of `lib/api/api_client.dart`.

### Add a new screen
1. Create `lib/screens/my_feature/my_screen.dart`
2. Add a tab in `_MainShell` in `lib/main.dart`, or navigate via `Navigator.push`

### State management
The app uses `provider`. For larger teams, the `api_client.dart` pattern can be replaced with `Riverpod` or `Bloc` — the API layer is framework-agnostic.

---

## Troubleshooting

**`flutter pub get` fails** → ensure you're on Flutter ≥ 3.22: `flutter upgrade`

**Font not showing** → check `pubspec.yaml` paths match exactly and run `flutter clean && flutter pub get`

**iOS build fails** → open `ios/Runner.xcworkspace` in Xcode, set your Team in Signing & Capabilities, and ensure deployment target is 13.0+

**Android: cleartext traffic error** → the manifest already sets `usesCleartextTraffic="false"` since the API is HTTPS

**Payment redirect not returning to app** → configure a URL scheme in `ios/Runner/Info.plist` and Android's `AndroidManifest.xml` (already done for `habitmove://`)
