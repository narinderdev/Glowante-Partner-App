# Glowante-Partner-App
LOGIN
OTP VERIFY
UPDATE PROFILE
CREATE,GET,DELETE & UPDATE SALON
CREATE,GET,DELETE & UPDATE BRANCH
ADD CATEGORY,SUBCATEGORY,SERVICES(INSIDE CATEGORY & SUBCATEGORY)
PREDEFINED SERVICES
ADD,GET,UPDATE,DELETE TEAM MEMBER
ASSIGN TEAM MEMBER
ADD BOOKING(CHECK SLOTS CAREFULLY),GET BOOKINGS,ACCEPT JOB,START JOB,END JOB,Add invetory,CHECK REVIEW WORKING FINE
ADD CUSTOMER
ADD,GET,UPDATE,DELETE PACKAGES &DEALS
LOGOUT
DELETE ACCOUNT
RESEND OTP

## App Flavors (dev / staging / prod)

Three separate installable apps, one per environment — they install side by side on the same device/TestFlight/Play Console without overwriting each other.

| Flavor | Android `applicationId` | iOS bundle ID | dart-define `APP_FLAVOR` | API base URL (`lib/config/app_environment.dart`) |
|---|---|---|---|---|
| `dev` | `com.glowante.salon.dev` | `com.glowante.salon.dev` | `dev` | `dev2-api.glowante.com` |
| `staging` (iOS/Android scheme name) | `com.glowante.salon.test` | `com.glowante.salon.test` | `test` | `test-api.glowante.com` |
| `prod` | `com.glowante.salon` | `com.glowante.salon` | `prod` | `api.glowante.com` |

Android's Gradle flavor and iOS's Xcode scheme are both named `staging` (not `test`) because Android's build tool reserves flavor names starting with `test`. The `APP_FLAVOR` dart-define stays `test` regardless — that's just what `app_environment.dart`'s enum is called.

**Always pass `--flavor` and the matching `--dart-define=APP_FLAVOR=...` together** — they're independent flags and nothing keeps them in sync automatically. Easiest way: use the wrapper script instead of typing both by hand:

```bash
scripts/flutter_flavor.sh dev run -d <device-id>
scripts/flutter_flavor.sh staging build apk --release
scripts/flutter_flavor.sh prod build ipa --release
```

## Deploying — build once, push all flavors to TestFlight / Play Console internal testing

One-time setup (credentials, already done for this project — see `ios/fastlane/.env` and `android/fastlane/.env`, both gitignored):
```bash
cd ios && bundle install
cd android && bundle install
```

**Push everything (dev + staging + prod) in one shot:**
```bash
cd ios && bundle exec fastlane ios all       # → TestFlight, all 3 apps
cd android && bundle exec fastlane android all   # → Play Console internal testing, all 3 apps
```

**Push just one flavor** (e.g. after dev's been tested and you only want staging or prod to go out):
```bash
cd ios && bundle exec fastlane ios dev
cd ios && bundle exec fastlane ios staging
cd ios && bundle exec fastlane ios prod

cd android && bundle exec fastlane android dev
cd android && bundle exec fastlane android staging
cd android && bundle exec fastlane android prod
```

Each lane runs `flutter build ipa`/`flutter build appbundle` for that flavor, then uploads it — no manual Xcode scheme-switching or drag-and-drop uploads needed.

## Force Update (Firebase Remote Config)

Lets you lock users out of the app until they update, without shipping a new release — just change a value in Firebase Console.

**Where:** [console.firebase.google.com](https://console.firebase.google.com) → project `glowante-8eb45` → Remote Config → parameter `min_supported_version`.

- Set it to a version number (e.g. `2.1.0`) → **Publish changes**. Anyone on an older installed version gets a non-dismissible "Update Required" modal — on cold launch, on app resume, and every 20 minutes if the app stays open continuously. There's no way past it except tapping "Update Now" (opens the Play Store / App Store listing).
- Leave it blank, or set it to the current shipped version, and nobody is gated.

Optional parameters (fall back to sensible built-in defaults if unset): `update_message`, `android_store_url`, `ios_store_url`.

Relevant files: `lib/services/app_update_service.dart` (the version check), `lib/screens/update_required_dialog.dart` (the modal UI), `lib/screens/splash_screen.dart` + `lib/main.dart` (where/when it's triggered).