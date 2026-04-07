# Building HabitMove for Android

Complete guide to producing a debug APK (for device testing) and a release
AAB (for Play Store distribution).

---

## Prerequisites

| Tool | Version | Download |
|---|---|---|
| Flutter SDK | ≥ 3.22 | https://docs.flutter.dev/get-started/install |
| Java (JDK) | 17 | https://adoptium.net |
| Android Studio | Latest | https://developer.android.com/studio |
| Android SDK | API 34 | via Android Studio SDK Manager |

Verify your setup:
```bash
flutter doctor -v
```
All items should show ✓. Fix anything that shows ✗ before building.

---

## Step 1 — Add fonts

Download and place font files in `assets/fonts/`:

```
assets/fonts/
├── DMSerifDisplay-Regular.ttf    ← https://fonts.google.com/specimen/DM+Serif+Display
├── DMSerifDisplay-Italic.ttf
├── DMSans-Regular.ttf            ← https://fonts.google.com/specimen/DM+Sans
├── DMSans-Medium.ttf
└── DMSans-SemiBold.ttf
```

---

## Step 2 — Install dependencies

```bash
cd habitmove_flutter
flutter pub get
```

---

## Step 3 — Debug APK (for testing on a device)

No signing required. Installs alongside other apps.

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Install directly on a connected device
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Install on a specific device
```bash
adb devices                          # list connected devices
adb -s DEVICE_ID install app-debug.apk
```

---

## Step 4 — Create a release keystore (one-time)

> ⚠️ Keep your keystore file and passwords safe forever.
> If you lose them, you cannot update your app on the Play Store.

```bash
keytool -genkey -v \
  -keystore android/app/habitmove-release.keystore \
  -alias habitmove \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

You'll be prompted for a password and organisation details.

---

## Step 5 — Configure signing

Copy the example and fill in your values:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:
```properties
storeFile=habitmove-release.keystore
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=habitmove
keyPassword=YOUR_KEY_PASSWORD
```

> `android/key.properties` is in `.gitignore` — it will never be committed.

---

## Step 6 — Release AAB (for Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

This is the file you upload to the Google Play Console.

---

## Step 7 — Release APK (for sideloading / direct download)

Split by ABI for smaller download sizes:

```bash
flutter build apk --release --split-per-abi
```

Outputs:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk    ← modern phones (use this for testing)
├── app-armeabi-v7a-release.apk  ← older 32-bit phones
└── app-x86_64-release.apk       ← emulators
```

---

## Automated build script

The `build.sh` script handles everything above interactively:

```bash
chmod +x build.sh
./build.sh
```

It will:
1. Run `flutter clean && flutter pub get`
2. Build the debug APK
3. Prompt you to generate a keystore (if one doesn't exist)
4. Build the release AAB
5. Optionally build split release APKs
6. Copy all outputs to `build/outputs/`

---

## Uploading to Google Play

1. Go to https://play.google.com/console
2. Create a new app → Android → App
3. Complete store listing (name, description, screenshots)
4. Go to **Release → Production → Create new release**
5. Upload `app-release.aab`
6. Fill in release notes
7. Review → Roll out

### Minimum required assets for submission:
- 1 screenshot (phone, min 320px)
- High-res icon: 512×512 PNG
- Feature graphic: 1024×500 PNG
- Privacy policy URL

---

## Common issues

**`Execution failed for task ':app:processReleaseResources'`**
→ Run `flutter clean && flutter pub get` then rebuild.

**`keystore was tampered with, or password was incorrect`**
→ Check passwords in `android/key.properties` — they must match the keystore.

**`Gradle task assembleRelease failed with exit code 1`**
→ Check `flutter doctor`, ensure Android SDK is installed and licensed:
```bash
flutter doctor --android-licenses
```

**AAB rejected by Play Store — "You uploaded an APK or Android App Bundle that was signed in debug mode"**
→ Ensure `key.properties` exists and `signingConfig` in `build.gradle` points to it.

**App crashes on launch (release build only)**
→ Check ProGuard rules in `android/app/proguard-rules.pro` — a class may be getting obfuscated.
   Run with `--no-shrink` to test:
```bash
flutter build apk --release --no-shrink
```

---

## iOS build (for reference)

Requires a Mac with Xcode and an Apple Developer account ($99/year).

```bash
flutter build ipa --release
```

Then open Xcode → Organizer → Distribute App → App Store Connect.

---

## Version bumping

Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2   # format: versionName+versionCode
#          ↑ ↑
#          |  └─ versionCode (integer, must increment on every Play Store upload)
#          └──── versionName (shown to users, e.g. "1.0.1")
```
