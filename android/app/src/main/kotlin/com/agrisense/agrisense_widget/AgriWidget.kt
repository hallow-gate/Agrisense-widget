package com.agrisense.agrisense_widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

class AgriWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        Render.apply(context, mgr, ids)               // instant paint from the cache
        syncInBackground(context)                      // then fetch fresh numbers
    }

    // Called every time the user resizes the widget: swap to the layout that fits.
    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, newOptions: Bundle) {
        Render.apply(context, mgr, intArrayOf(id))
    }

    override fun onEnabled(context: Context) {
        if (Store.live(context) && Store.session(context) != null) Live.start(context)
    }

    override fun onDisabled(context: Context) {
        Live.stop(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Render.ACTION_REFRESH) {
            if (Store.live(context) && Store.session(context) != null) Live.start(context)
            syncInBackground(context)
        }
    }

    private fun syncInBackground(context: Context) {
        val app = context.applicationContext
        val pending = goAsync()
        Thread {
            try {
                Net.sync(app)
                Render.updateAll(app)
            } catch (e: Exception) {
            } finally {
                pending.finish()
            }
        }.start()
    }
}
