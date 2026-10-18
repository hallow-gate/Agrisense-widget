package com.agrisense.agrisense_widget

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Native copy of the app's API calls so the widget keeps updating while the app is closed. */
object Net {
    const val BASE = "https://agrisense-1-0.onrender.com"

    private class Resp(val code: Int, val body: String)

    private fun call(path: String, method: String, body: String?, token: String?): Resp {
        var con: HttpURLConnection? = null
        return try {
            con = (URL(BASE + path).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 8000
                readTimeout = 10000
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                if (!token.isNullOrEmpty()) setRequestProperty("Authorization", "Bearer $token")
                if (body != null) { doOutput = true; outputStream.use { it.write(body.toByteArray()) } }
            }
            val code = con.responseCode
            val stream = if (code in 200..299) con.inputStream else con.errorStream
            Resp(code, stream?.bufferedReader()?.use { it.readText() } ?: "")
        } catch (e: Exception) {
            Resp(-1, "")
        } finally {
            con?.disconnect()
        }
    }

    /** Returns true when the session was refreshed (or someone else already did). */
    @Synchronized
    private fun refresh(c: Context, usedAccess: String): Boolean {
        val s = Store.session(c) ?: return false
        if (s.access.isNotEmpty() && s.access != usedAccess) return true      // the app refreshed it meanwhile
        if (s.refresh.isEmpty()) return false
        val r = call("/api/auth/refresh", "POST", JSONObject().put("refresh_token", s.refresh).toString(), null)
        if (r.code in 200..299) {
            return try {
                val j = JSONObject(r.body)
                Store.saveSession(c, j.getString("access_token"), j.getString("refresh_token"), j.optJSONObject("user")?.optString("email") ?: s.email)
                true
            } catch (e: Exception) { false }
        }
        if (r.code == 401 || r.code == 403) Store.clearSession(c)                // refused for good: signed out
        return false
    }

    /** Fetch /api/status and cache it. Returns true on success. */
    fun sync(c: Context): Boolean {
        val s = Store.session(c) ?: return false
        var token = s.access
        var r = if (token.isNotEmpty()) call("/api/status", "GET", null, token) else Resp(401, "")
        if (r.code == 401) {
            if (!refresh(c, token)) { if (Store.session(c) != null) Store.markNetFail(c); return false }
            token = Store.session(c)?.access ?: return false
            r = call("/api/status", "GET", null, token)
        }
        if (r.code !in 200..299) { Store.markNetFail(c); return false }
        return try {
            val j = JSONObject(r.body)
            val t = j.optJSONObject("telemetry")
            val out = JSONObject()
            fun num(k: String) = if (t == null || t.isNull(k)) JSONObject.NULL else t.getDouble(k)
            out.put("temp", num("temp_c")).put("hum", num("humidity")).put("soil", num("soil_pct"))
                .put("online", j.optBoolean("online", false))
                .put("soil_fault", t != null && t.optBoolean("soil_fault", false))
                .put("dry", j.optJSONObject("settings")?.optInt("soil_dry_pct", 40) ?: 40)
                .put("updated_at", if (t == null || t.isNull("updated_at")) JSONObject.NULL else t.getString("updated_at"))
            Store.saveReading(c, out.toString(), true)
            true
        } catch (e: Exception) { Store.markNetFail(c); false }
    }
}
