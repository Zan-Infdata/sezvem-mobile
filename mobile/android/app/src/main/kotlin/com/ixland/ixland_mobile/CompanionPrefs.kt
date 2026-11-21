package com.ixland.ixland_mobile

import android.content.Context

/**
 * Companion settings saved on the device.
 *
 * Both Flutter engines read them through native channels, because the overlay engine doesn't
 * register plugins.
 */
internal object CompanionPrefs {
    private const val FILE = "companion"
    private const val STYLE = "style"

    fun styleId(context: Context): String? =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(STYLE, null)

    fun setStyleId(context: Context, id: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putString(STYLE, id).apply()
    }
}
