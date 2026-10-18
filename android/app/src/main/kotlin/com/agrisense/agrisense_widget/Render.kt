package com.agrisense.agrisense_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Turns the cached reading into RemoteViews, choosing the layout that fits the widget's current size. */
object Render {
    const val ACTION_REFRESH = "com.agrisense.agrisense_widget.REFRESH"
    private const val STALE_MS = 5 * 60_000L

    private fun component(c: Context) = ComponentName(c, AgriWidget::class.java)

    fun widgetIds(c: Context): IntArray =
        AppWidgetManager.getInstance(c).getAppWidgetIds(component(c))

    fun hasWidgets(c: Context) = widgetIds(c).isNotEmpty()

    fun updateAll(c: Context) {
        val mgr = AppWidgetManager.getInstance(c)
        apply(c, mgr, mgr.getAppWidgetIds(component(c)))
    }

    fun apply(c: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            try { mgr.updateAppWidget(id, build(c, mgr, id)) } catch (e: Exception) { /* a bad frame must never kill the loop */ }
        }
    }

    // ---- size classes (dp) ----
    private fun layoutFor(c: Context, mgr: AppWidgetManager, id: Int): Int {
        val o = mgr.getAppWidgetOptions(id)
        val land = c.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        var w = o.getInt(if (land) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        var h = o.getInt(if (land) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        if (w <= 0) w = 250
        if (h <= 0) h = 110
        return when {
            w >= 200 -> when {
                h < 80 -> R.layout.widget_strip
                h < 160 -> R.layout.widget_wide
                else -> R.layout.widget_large
            }
            h >= 110 -> R.layout.widget_stack
            w >= 110 -> R.layout.widget_strip
            else -> R.layout.widget_mini
        }
    }

    // ---- display state ----
    private class State(
        val temp: String, val hum: String, val soil: String, val soilPct: Int, val soilState: String,
        val label: String, val kind: Int, val updated: String,   // kind: 0 online, 1 offline, 2 stale / no data
    )

    private fun num(j: JSONObject, k: String): Double? = if (j.isNull(k) || !j.has(k)) null else j.optDouble(k).takeIf { !it.isNaN() }

    fun isoMs(raw: String?): Long? {
        if (raw.isNullOrEmpty() || raw.length < 19) return null
        return try {
            val s = raw.replace(' ', 'T')
            val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
            var ms = f.parse(s.substring(0, 19))!!.time
            val m = Regex("([+-])(\\d{2})(?::?(\\d{2}))?$").find(s.substring(19))
            if (m != null) {
                val sign = if (m.groupValues[1] == "-") -1 else 1
                ms -= sign * (m.groupValues[2].toLong() * 3_600_000L + (m.groupValues[3].toLongOrNull() ?: 0L) * 60_000L)
            }
            ms
        } catch (e: Exception) { null }
    }

    private fun clock(ms: Long): String = DateFormat.getTimeInstance(DateFormat.MEDIUM).format(Date(ms))
    private fun clockShort(ms: Long): String {
        val sameDay = SimpleDateFormat("yyyyMMdd", Locale.US).let { it.format(Date(ms)) == it.format(Date()) }
        return (if (sameDay) "" else SimpleDateFormat("MMM d, ", Locale.getDefault()).format(Date(ms))) + DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(ms))
    }

    private fun state(c: Context): State {
        if (Store.session(c) == null)
            return State("–", "–", "–", 0, "", "Sign in", 2, "Open AgriSense to sign in")
        val r = Store.reading(c)
            ?: return State("–", "–", "–", 0, "", if (Store.netOk(c)) "Waiting" else "No signal", 2, "Waiting for data…")

        val now = System.currentTimeMillis()
        val fetched = Store.fetchedAt(c)
        val netOk = Store.netOk(c)
        val stale = !netOk || now - fetched > STALE_MS
        val online = r.optBoolean("online", false)

        val t = num(r, "temp"); val h = num(r, "hum"); val s = num(r, "soil")
        val dry = r.optInt("dry", 40)
        val fault = r.optBoolean("soil_fault", false)
        val soilState = when {
            fault -> "Sensor fault"
            s == null -> "No reading"
            s < dry -> "Dry"
            s > 75 -> "Wet"
            else -> "Comfortable"
        }
        val seen = isoMs(if (r.isNull("updated_at")) null else r.optString("updated_at"))
        val updated = when {
            stale && fetched > 0 -> "As of " + clockShort(fetched)
            !online && seen != null -> "Last seen " + clockShort(seen)
            else -> "Updated " + clock(fetched)
        }
        return State(
            temp = t?.let { String.format(Locale.US, "%.1f°", it) } ?: "–",
            hum = h?.let { String.format(Locale.US, "%.0f%%", it) } ?: "–",
            soil = s?.let { String.format(Locale.US, "%.0f%%", it) } ?: "–",
            soilPct = s?.toInt()?.coerceIn(0, 100) ?: 0,
            soilState = soilState,
            label = when { !netOk -> "No signal"; stale -> "Stale"; online -> "Online"; else -> "Offline" },
            kind = when { stale -> 2; online -> 0; else -> 1 },
            updated = updated,
        )
    }

    private fun col(c: Context, id: Int): Int =
        if (android.os.Build.VERSION.SDK_INT >= 23) c.getColor(id) else c.resources.getColor(id)

    fun build(c: Context, mgr: AppWidgetManager, id: Int): RemoteViews {
        val rv = RemoteViews(c.packageName, layoutFor(c, mgr, id))
        val st = state(c)

        val tone = when (st.kind) { 0 -> R.color.ok; 1 -> R.color.bad; else -> R.color.stale }
        val dot = when (st.kind) { 0 -> R.drawable.dot_ok; 1 -> R.drawable.dot_bad; else -> R.drawable.dot_stale }
        val pill = when (st.kind) { 0 -> R.drawable.pill_ok; 1 -> R.drawable.pill_bad; else -> R.drawable.pill_stale }
        val valueColor = col(c, if (st.kind == 2) R.color.mute else R.color.ink)
        val heroColor = col(c, if (st.kind == 2) R.color.mute else R.color.matcha_ink)

        rv.setTextViewText(R.id.tv_temp, st.temp)
        rv.setTextViewText(R.id.tv_hum, st.hum)
        rv.setTextViewText(R.id.tv_soil, st.soil)
        rv.setTextColor(R.id.tv_temp, valueColor)
        rv.setTextColor(R.id.tv_hum, valueColor)
        rv.setTextColor(R.id.tv_soil, valueColor)
        rv.setTextViewText(R.id.tv_status, st.label)
        rv.setTextColor(R.id.tv_status, col(c, tone))
        rv.setTextViewText(R.id.tv_updated, st.updated)
        rv.setTextViewText(R.id.tv_soil_state, st.soilState)
        rv.setInt(R.id.dot_status, "setBackgroundResource", dot)
        rv.setInt(R.id.dot_pill, "setBackgroundResource", dot)
        rv.setInt(R.id.pill, "setBackgroundResource", pill)
        rv.setInt(R.id.root, "setBackgroundResource", if (st.kind == 1) R.drawable.bg_widget_off else R.drawable.bg_widget)
        rv.setProgressBar(R.id.pb_soil, 100, st.soilPct, false)
        // the big soil figure in the large layout uses the deeper ink
        if (layoutFor(c, mgr, id) == R.layout.widget_large) rv.setTextColor(R.id.tv_soil, heroColor)

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        c.packageManager.getLaunchIntentForPackage(c.packageName)?.let {
            rv.setOnClickPendingIntent(R.id.root, PendingIntent.getActivity(c, 0, it, flags))
        }
        val refresh = Intent(c, AgriWidget::class.java).setAction(ACTION_REFRESH)
        rv.setOnClickPendingIntent(R.id.btn_refresh, PendingIntent.getBroadcast(c, 1, refresh, flags))
        return rv
    }
}
