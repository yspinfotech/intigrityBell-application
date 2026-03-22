package com.example.intigrity

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "alarm_service_channel"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_ALARM") {
            // Kill everything: audio, vibration, foreground service, notifications
            stopAudio()
            stopVibration()
            
            // Dismiss all alarm notifications from this service
            val notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notifManager.cancelAll()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent?.getIntExtra("id", 0) ?: 0
        val title = intent?.getStringExtra("title") ?: "Alarm"
        val soundUriStr = intent?.getStringExtra("soundUri")

        createNotificationChannel()

        // 1. Start MediaPlayer
        startAudio(soundUriStr)

        // 2. Create FullScreen Intent to launch MainActivity
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("trigger_alarm", true)
            putExtra("id", id)
            putExtra("title", title)
            putExtra("soundUri", soundUriStr)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, id, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 3. Create Stop Action
        val stopIntent = Intent(this, AlarmService::class.java).apply {
            action = "STOP_ALARM"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, id + 1000, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 4. Build Notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $title")
            .setContentText("Alarm is ringing — tap to open or press STOP")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .addAction(0, "STOP ALARM", stopPendingIntent)
            .build()

        startForeground(id, notification)

        return START_NOT_STICKY
    }

    private fun startAudio(uriStr: String?) {
        try {
            stopAudio()
            
            // FIX 1 & 4: Support Custom res/raw assets + System Ringtones
            if (uriStr != null && (uriStr == "alarm" || uriStr == "alarm1" || uriStr == "alarm2")) {
                val resId = when(uriStr) {
                    "alarm1" -> R.raw.alarm1
                    "alarm2" -> R.raw.alarm2
                    else -> R.raw.alarm
                }
                mediaPlayer = MediaPlayer.create(applicationContext, resId).apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                    }
                    isLooping = true
                    start()
                }
            } else {
                val uri: Uri = if (uriStr != null && uriStr.startsWith("content://")) {
                    Uri.parse(uriStr)
                } else {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                }

                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, uri)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                    }
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (e: Exception) {
            // Fallback to absolute default
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, uri)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                    }
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (e2: Exception) {}
        }
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    private fun stopVibration() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.cancel()
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service Channel",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Channel for ringing alarms"
                setSound(null, null) // No sound, we play it via MediaPlayer!
                enableVibration(false) // FIX: DISABLE channel vibration (prevents system-level vibration that cannot be cancelled)
                vibrationPattern = longArrayOf(0) // Empty pattern = no vibration
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopAudio()
        stopVibration()
        super.onDestroy()
    }
}
