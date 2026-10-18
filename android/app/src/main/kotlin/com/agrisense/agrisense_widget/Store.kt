package com.agrisense.agrisense_widget

import android.content.Context
import org.json.JSONObject

/** Everything the widget needs lives in one private SharedPreferences file shared by the app, the service and the widget. */
object Store {
    private fun p(c: Context) = c.applicationContext.getSharedPreferences("agrisense_widget", Context.MODE_PRIVATE)

    data class Session(val access: String, val refresh: String, val email: String)

    fun session(c: Context): Session? {
        val s = p(c)
        val a = s.getString("access", "") ?: ""
        val r = s.getString("refresh", "") ?: ""
        if (a.isEmpty() && r.isEmpty()) return null
        return Session(a, r, s.getString("email", "") ?: "")
    }

    fun saveSession(c: Context, access: String, refresh: String, email: String) {
        p(c).edit().putString("access", access).putString("refresh", refresh).putString("email", email).apply()
    }

    fun clearSession(c: Context) {
        p(c).edit().remove("access").remove("refresh").remove("email").remove("reading").remove("fetched_at").apply()
    }

    /** reading = {temp, hum, soil, online, soil_fault, updated_at} */
    fun saveReading(c: Context, json: String, netOk: Boolean = true) {
        p(c).edit().putString("reading", json).putLong("fetched_at", System.currentTimeMillis()).putBoolean("net_ok", netOk).apply()
    }

    fun markNetFail(c: Context) { p(c).edit().putBoolean("net_ok", false).apply() }

    fun reading(c: Context): JSONObject? =
        try { p(c).getString("reading", null)?.let { JSONObject(it) } } catch (e: Exception) { null }

    fun fetchedAt(c: Context): Long = p(c).getLong("fetched_at", 0L)
    fun netOk(c: Context): Boolean = p(c).getBoolean("net_ok", true)

    fun live(c: Context): Boolean = p(c).getBoolean("live", true)
    fun setLive(c: Context, on: Boolean) { p(c).edit().putBoolean("live", on).apply() }
}
