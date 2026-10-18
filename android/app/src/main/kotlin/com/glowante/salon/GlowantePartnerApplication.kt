package com.glowante.salon

import android.app.Application

/**
 * Registered in AndroidManifest.xml. Runs whenever the process starts,
 * including when the FCM service starts it to display a background push,
 * so the notification channel exists before the first notification is
 * posted. See NotificationChannels and docs/PUSH_SOUND.md.
 */
class GlowantePartnerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NotificationChannels.ensureCreated(this)
    }
}
