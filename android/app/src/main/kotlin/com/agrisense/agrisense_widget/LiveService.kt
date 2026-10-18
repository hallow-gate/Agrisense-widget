package com.agrisense.agrisense_widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Keeps the widget "realtime": while the screen is on it pulls fresh readings every few seconds,
 * and it sleeps while the screen is off. It stops by itself when the last widget is removed.
 */
class LiveService : Service() {
    @Volatile private var running = false
    private var worker: Thread? = null

    private val screenOn = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { worker?.interrupt() }   // wake and refresh right away
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val f = IntentFilter(Intent.ACTION_SCREEN_ON)
        try {
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenOn, f, Context.RECEIVER_NOT_EXPORTED) else registerReceiver(screenOn, f)
        } catch (e: Exception) { }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!promote()) { stopSelf(); return START_NOT_STICKY }
        if (!running) {
            running = true
            worker = Thread { loop() }.also { it.isDaemon = true; it.start() }
        }
        return START_STICKY
    }

    private fun promote(): Boolean {
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val b: Notification.Builder
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(NotificationChannel(CHANNEL, getString(R.string.agri_live_channel), NotificationManager.IMPORTANCE_MIN))
                b = Notification.Builder(this, CHANNEL)
            } else {
                b = Notification.Builder(this)
            }
            b.setSmallIcon(R.drawable.ic_stat).setContentTitle("AgriSense").setContentText(getString(R.string.agri_live_text))
                .setOngoing(true).setShowWhen(false)
            packageManager.getLaunchIntentForPackage(packageName)?.let {
                b.setContentIntent(PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            val n = b.build()
            if (Build.VERSION.SDK_INT >= 34) startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(ID, n)
            true
        } catch (e: Exception) { false }
    }

    private fun sleep(ms: Long) {
        try { Thread.sleep(ms) } catch (e: InterruptedException) { /* woken early */ }
    }

    private fun loop() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        while (running) {
            try {
                if (!Store.live(this) || !Render.hasWidgets(this)) break
                if (Store.session(this) == null) { sleep(30_000); continue }
                if (pm.isInteractive) {
                    Net.sync(this)
                    Render.updateAll(this)
                    sleep(INTERVAL_MS)
                } else {
                    sleep(60_000)
                }
            } catch (e: Exception) {
                sleep(INTERVAL_MS)
            }
        }
        running = false
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        try { unregisterReceiver(screenOn) } catch (e: Exception) { }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "agrisense_live"
        private const val ID = 4107
        private const val INTERVAL_MS = 8_000L
    }
}
