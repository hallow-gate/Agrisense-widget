package com.agrisense.agrisense_widget

import android.content.Context
import android.content.Intent
import android.os.Build

object Live {
    /** Best effort: Android may refuse to start a foreground service from the background. */
    fun start(c: Context) {
        try {
            val i = Intent(c.applicationContext, LiveService::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.applicationContext.startForegroundService(i) else c.applicationContext.startService(i)
        } catch (e: Exception) { /* the widget still refreshes on tap and on its schedule */ }
    }

    fun stop(c: Context) {
        try { c.applicationContext.stopService(Intent(c.applicationContext, LiveService::class.java)) } catch (e: Exception) { }
    }
}
