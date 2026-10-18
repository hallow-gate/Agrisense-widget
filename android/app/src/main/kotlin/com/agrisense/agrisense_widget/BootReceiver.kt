package com.agrisense.agrisense_widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED && Store.live(context) && Store.session(context) != null && Render.hasWidgets(context)) {
            Live.start(context)
        }
    }
}
