package com.seagomezar.flutepracticecoach

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class CaptureForegroundService : Service() {
    private val activeCaptureCounts = mutableMapOf<String, Int>()

    companion object {
        private const val ACTION_BEGIN = "com.seagomezar.flutepracticecoach.BEGIN_CAPTURE"
        private const val ACTION_END = "com.seagomezar.flutepracticecoach.END_CAPTURE"
        private const val EXTRA_KIND = "kind"
        private const val CHANNEL_ID = "practice_capture"
        private const val NOTIFICATION_ID = 4101

        fun start(context: Context, kind: String) {
            val intent = Intent(context, CaptureForegroundService::class.java).apply {
                action = ACTION_BEGIN
                putExtra(EXTRA_KIND, kind)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context, kind: String) {
            val intent = Intent(context, CaptureForegroundService::class.java).apply {
                action = ACTION_END
                putExtra(EXTRA_KIND, kind)
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_END -> {
                val kind = intent.getStringExtra(EXTRA_KIND).orEmpty()
                val count = activeCaptureCounts[kind] ?: 0
                if (count <= 1) {
                    activeCaptureCounts.remove(kind)
                } else {
                    activeCaptureCounts[kind] = count - 1
                }
                if (activeCaptureCounts.isEmpty()) {
                    stopForeground(true)
                    stopSelfResult(startId)
                }
            }

            else -> {
                val kind = intent?.getStringExtra(EXTRA_KIND).orEmpty()
                activeCaptureCounts[kind] = (activeCaptureCounts[kind] ?: 0) + 1
                val notification = buildNotification(kind)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(true)
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Practice audio capture",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps recording and tuner capture active while the screen is locked."
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(kind: String): Notification {
        val title = if (kind == "pitchTracking") {
            "Tuner capture active"
        } else {
            "Practice recording active"
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                },
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText("Audio capture continues while the screen is locked")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }
}
