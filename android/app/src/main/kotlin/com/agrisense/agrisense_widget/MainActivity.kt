package com.agrisense.agrisense_widget

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agrisense/widget").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getSession" -> {
                        val s = Store.session(this)
                        result.success(s?.let { mapOf("access" to it.access, "refresh" to it.refresh, "email" to it.email) })
                    }
                    "saveSession" -> {
                        Store.saveSession(this, call.argument<String>("access") ?: "", call.argument<String>("refresh") ?: "", call.argument<String>("email") ?: "")
                        result.success(null)
                    }
                    "clearSession" -> {
                        Store.clearSession(this)
                        Render.updateAll(this)
                        result.success(null)
                    }
                    "pushReading" -> {
                        Store.saveReading(this, call.argument<String>("json") ?: "{}", true)
                        Render.updateAll(this)
                        result.success(null)
                    }
                    "markOffline" -> {
                        Store.markNetFail(this)
                        Render.updateAll(this)
                        result.success(null)
                    }
                    "setLive" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        Store.setLive(this, on)
                        if (on) {
                            askNotificationPermission()
                            Live.start(this)
                        } else Live.stop(this)
                        result.success(null)
                    }
                    "isLive" -> result.success(Store.live(this))
                    "pinWidget" -> {
                        val mgr = AppWidgetManager.getInstance(this)
                        if (Build.VERSION.SDK_INT >= 26 && mgr.isRequestPinAppWidgetSupported) {
                            mgr.requestPinAppWidget(ComponentName(this, AgriWidget::class.java), null, null)
                            result.success(true)
                        } else result.success(false)
                    }
                    "widgetCount" -> result.success(Render.widgetIds(this).size)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native", e.message, null)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        // The app is in the foreground, so Android allows (re)starting the live refresher here.
        if (Store.live(this) && Store.session(this) != null && Render.hasWidgets(this)) Live.start(this)
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
    }
}
