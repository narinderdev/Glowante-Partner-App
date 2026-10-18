package com.glowante.salon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Upgrade rule: explicit user choices on the legacy channel cap the new
 * channel on its first creation. Importance values mirror
 * NotificationManager.IMPORTANCE_* (none 0, low 2, default 3, high 4).
 */
class NotificationChannelsTest {

    private val none = 0
    private val low = 2
    private val default = 3
    private val high = 4

    @Test
    fun untouchedLegacyChannelChangesNothing() {
        val o = NotificationChannels.legacyOverrides(
            userSetImportance = false, importance = high,
            userSetSound = false, sound = "system_default_sound"
        )
        assertNull(o.importance)
        assertFalse(o.applySound)
        assertNull(o.sound)
        assertEquals(high, o.importanceFor(high))
    }

    @Test
    fun blockedLegacyChannelBlocksNewChannel() {
        val o = NotificationChannels.legacyOverrides<String>(
            userSetImportance = true, importance = none,
            userSetSound = false, sound = null
        )
        assertEquals(none, o.importanceFor(high))
    }

    @Test
    fun loweredImportanceCarriesOverButNeverRaises() {
        val lowered = NotificationChannels.legacyOverrides<String>(
            userSetImportance = true, importance = low,
            userSetSound = false, sound = null
        )
        assertEquals(low, lowered.importanceFor(high))

        val raised = NotificationChannels.legacyOverrides<String>(
            userSetImportance = true, importance = high,
            userSetSound = false, sound = null
        )
        assertEquals(default, raised.importanceFor(default))
        assertEquals(high, raised.importanceFor(high))
    }

    @Test
    fun silencedLegacyChannelSilencesNewChannel() {
        val o = NotificationChannels.legacyOverrides<String>(
            userSetImportance = false, importance = high,
            userSetSound = true, sound = null
        )
        assertTrue(o.applySound)
        assertNull(o.sound)
    }

    @Test
    fun userChosenSoundCarriesOver() {
        val o = NotificationChannels.legacyOverrides(
            userSetImportance = false, importance = high,
            userSetSound = true, sound = "content://ringtone/7"
        )
        assertTrue(o.applySound)
        assertEquals("content://ringtone/7", o.sound)
    }

    @Test
    fun withoutUserFlagsShippedValuesAreTheReference() {
        // Pre-API-29: importance below the shipped HIGH, or a null sound, can
        // only have come from the user.
        val untouched = NotificationChannels.legacyOverrides(
            userSetImportance = null, importance = high,
            userSetSound = null, sound = "system_default_sound"
        )
        assertNull(untouched.importance)
        assertFalse(untouched.applySound)

        val muted = NotificationChannels.legacyOverrides<String>(
            userSetImportance = null, importance = low,
            userSetSound = null, sound = null
        )
        assertEquals(low, muted.importanceFor(high))
        assertTrue(muted.applySound)
        assertNull(muted.sound)
    }
}
