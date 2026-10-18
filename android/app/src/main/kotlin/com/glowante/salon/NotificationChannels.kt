package com.glowante.salon

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * The single notification channel of the partner app. Every notification,
 * whatever type the backend sent, is posted here and plays the urgent 10 s
 * "coin/money" sound (`res/raw/glowante_booking_request`). See
 * docs/PUSH_SOUND.md before changing anything.
 *
 * Created from [GlowantePartnerApplication.onCreate], not from Dart: the FCM
 * SDK displays background messages itself, without starting the Flutter
 * engine, and it does so right after starting the app process. The first
 * push after a Play Store upgrade, before the user has opened the app, must
 * therefore find the channel already created, or the SDK falls back to its
 * own "Miscellaneous" channel with the default sound.
 *
 * The id and name come from res/values/strings.xml so the channel and the
 * manifest's `default_notification_channel_id` can never diverge. The Dart
 * side (lib/services/push_notification_service.dart) posts to the same id.
 *
 * Upgrade path: builds before the coin sound used [LEGACY_ID] with the
 * system default sound. Android fixes a channel's sound when it is first
 * created, so a new id was required. A user who muted or disabled the old
 * channel must not start hearing notifications again just because they now
 * arrive on a new channel: the first time the new channel is created, its
 * importance and sound are capped by what the user chose on the old one.
 * The old channel is deleted afterwards.
 */
object NotificationChannels {

    private const val TAG = "PushSound"

    /** Channel id of builds before the coin sound; deleted after migration. */
    const val LEGACY_ID = "glowante_default_channel"

    /** Importance the legacy channel shipped with; anything lower is user-set. */
    internal const val LEGACY_SHIPPED_IMPORTANCE = NotificationManager.IMPORTANCE_HIGH

    /** Raw resource name of the coin sound, without extension. */
    const val SOUND_RESOURCE = "glowante_booking_request"

    fun ensureCreated(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        val channelId = context.getString(R.string.default_notification_channel_id)
        val channelName = context.getString(R.string.default_notification_channel_name)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val legacy = manager.getNotificationChannel(LEGACY_ID)
        // Explicit user choices on the legacy channel, applied only when the
        // new channel is being created for the first time. Afterwards each
        // channel keeps its own user settings (Android ignores importance and
        // sound on re-creation).
        val overrides = legacy
            ?.takeIf { manager.getNotificationChannel(channelId) == null }
            ?.let { old ->
                val canReadUserFlags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
                legacyOverrides(
                    userSetImportance = if (canReadUserFlags) old.hasUserSetImportance() else null,
                    importance = old.importance,
                    userSetSound = if (canReadUserFlags) old.hasUserSetSound() else null,
                    sound = old.sound
                )
            }

        val importance = overrides?.importanceFor(NotificationManager.IMPORTANCE_HIGH)
            ?: NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel(channelId, channelName, importance).apply {
            description = "Booking requests and updates about bookings, branches, and offers."
            enableLights(true)
            enableVibration(true)
            setShowBadge(true)
            if (overrides != null && overrides.applySound) {
                setSound(overrides.sound, overrides.sound?.let { audioAttributes })
            } else {
                setSound(rawResourceUri(context, SOUND_RESOURCE), audioAttributes)
            }
        }
        manager.createNotificationChannel(channel)
        if (overrides != null) {
            Log.i(TAG, "Channel $channelId created with legacy user settings: $overrides")
        }

        if (legacy != null) {
            manager.deleteNotificationChannel(LEGACY_ID)
            Log.i(TAG, "Legacy channel $LEGACY_ID deleted")
        }
    }

    /**
     * What an upgrading user explicitly chose on the legacy channel.
     * [importance] is null when the user never touched it. [applySound] is
     * true when the user picked a sound, or silence ([sound] == null),
     * themselves; otherwise the coin sound is used.
     */
    internal data class LegacyOverrides<S>(
        val importance: Int?,
        val applySound: Boolean,
        val sound: S?
    ) {
        /** Never louder than intended, never louder than the user allowed. */
        fun importanceFor(intended: Int): Int = importance?.let { minOf(intended, it) } ?: intended
    }

    /**
     * Pure decision, free of Android types so it can be unit tested.
     *
     * [userSetImportance] and [userSetSound] are the channel's
     * hasUserSetImportance / hasUserSetSound flags (API 29+), or null on
     * older devices. Without the flags the legacy channel's shipped values
     * are the reference: an importance below [LEGACY_SHIPPED_IMPORTANCE] can
     * only come from the user, and so can a null sound, because the channel
     * shipped with the system default sound.
     */
    internal fun <S> legacyOverrides(
        userSetImportance: Boolean?,
        importance: Int,
        userSetSound: Boolean?,
        sound: S?
    ): LegacyOverrides<S> {
        val importanceIsUserSet = userSetImportance ?: (importance < LEGACY_SHIPPED_IMPORTANCE)
        val soundIsUserSet = userSetSound ?: (sound == null)
        return LegacyOverrides(
            importance = importance.takeIf { importanceIsUserSet },
            applySound = soundIsUserSet,
            sound = sound.takeIf { soundIsUserSet }
        )
    }

    private fun rawResourceUri(context: Context, resourceName: String): Uri =
        Uri.parse("android.resource://${context.packageName}/raw/$resourceName")
}
