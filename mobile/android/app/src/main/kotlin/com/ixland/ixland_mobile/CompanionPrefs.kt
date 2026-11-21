package com.ixland.ixland_mobile

import android.content.Context

/**
 * Companion settings saved on the device: the chosen style and the customization choices for
 * each style, which Dart stores as a JSON string.
 *
 * Both Flutter engines read them through native channels, because the overlay engine doesn't
 * register plugins.
 */
internal object CompanionPrefs {
    private const val FILE = "companion"
    private const val STYLE = "style"
    private const val CHOICES = "choices"

    /** The saved look in the form `CompanionLook.fromMap` reads. */
    fun look(context: Context): Map<String, String?> {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        return mapOf("style" to prefs.getString(STYLE, null), "choices" to prefs.getString(CHOICES, null))
    }

    fun setLook(context: Context, style: String?, choices: String?) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putString(STYLE, style)
            .putString(CHOICES, choices)
            .apply()
    }
}
