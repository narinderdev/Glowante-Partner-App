# Push notification sound (Partner App)

Every push notification this app shows plays the urgent 10 s "coin/money"
sound (`glowante_booking_request`), whatever notification type the backend
sent. This is a product decision for the salon-side app. The customer apps
play the calm `glowante_glow` sound instead.

The backend (`backend-glowante`, `src/notifications/push-sound.ts`) picks a
sound per type and cannot change right now, so this app overrides it on the
client. Each FCM message carries:

| Type | `android.notification.channel_id` | `android.notification.sound` | `apns.payload.aps.sound` |
|---|---|---|---|
| `appointment_requested` | `glowante_booking_requests` | `glowante_booking_request` | `glowante_booking_request.caf` |
| every other type | `glowante_default` | `glowante_glow` | `glowante_glow.caf` |

Both rows must end up playing the coin sound here. Two deliberate tricks make
that happen. Please read them before "fixing" anything that looks odd.

## Android: one app-owned channel plus the manifest default fallback

- Channel id `glowante_partner_alerts` ("Glowante alerts", importance high,
  sound `res/raw/glowante_booking_request.wav`) is created at startup in
  `lib/services/push_notification_service.dart` and used for every local
  notification the app posts (foreground `onMessage` and the background
  handler for data-only messages).
- `android/app/src/main/res/values/strings.xml` sets
  `default_notification_channel_id` to the same id. The FCM SDK uses that
  manifest default for auto-displayed background messages whenever the
  payload names a channel the app has never created. The backend's ids
  `glowante_default` and `glowante_booking_requests` are never created here
  on purpose, so both fall back to the partner channel and its coin sound.
  Creating a channel with one of the backend ids would silently split the
  behaviour again.
- Android fixes a channel's sound the moment it is created on a device. The
  earlier channel id `glowante_default_channel` already shipped with the
  system default sound, so it could not be reused; the app now deletes it at
  startup. If the sound ever has to change again, pick a new channel id.
- `android.notification.sound` in the payload is irrelevant on Android 8+;
  the channel decides. `AndroidNotificationDetails(sound:, playSound:)` in the
  Dart code only matters for pre-Oreo devices.

## iOS: the coin audio is bundled under two file names

iOS plays whichever file `aps.sound` names from the app bundle. The backend
names `glowante_glow.caf` for non-request types, so this app ships the coin
audio twice in `ios/Runner/Sounds/`:

- `glowante_booking_request.caf`
- `glowante_glow.caf` (same bytes, different name)

Do not replace `glowante_glow.caf` with the calm sound in this repo. Both
files are registered in `ios/Runner.xcodeproj/project.pbxproj` under the
`Sounds` group and the Runner `Resources` build phase. Local notifications the
app presents itself use `DarwinNotificationDetails(sound:
'glowante_booking_request.caf')`.

Audio source of truth: `backend-glowante` `assets/push-sound/` on `main`
(README there has the licence note). Copy the files byte-for-byte; never
re-encode. 10.0 s, mono, 44.1 kHz, 16-bit.

## Device verification recipe

Use a partner account on a real device with the app newly installed.
Uninstall any older build first so the stale `glowante_default_channel` is
gone and the new channel is created fresh.

1. Trigger a booking request (`appointment_requested`) and one other type
   (for example a booking confirmation or cancellation).
2. Repeat with the app in the foreground, in the background, and force-closed.
3. Expected on every run: the 10 s coin sound. On Android, Settings >
   Notifications for the app should list only "Glowante alerts".
4. Upgrade check: install the previous build, open it once, upgrade in place,
   and confirm "General Notifications" disappears and the coin sound plays.
