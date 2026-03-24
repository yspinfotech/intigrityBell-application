package com.example.intigrity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.app.PendingIntent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        
        // Step 5: Wake Lock
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        val wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "IntigrityBell::AlarmWakeLock")
        wakeLock.acquire(10 * 1000L) // 10 seconds should be enough to start service
        
        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("id", id)
            putExtra("title", intent.getStringExtra("title"))
            putExtra("soundUri", intent.getStringExtra("soundUri"))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // Handle weekly repeating
        val isRepeat = intent.getBooleanExtra("isRepeat", false)
        if (isRepeat) {
            val oldTime = intent.getLongExtra("timeInMillis", 0L)
            if (oldTime > 0) {
                val calendar = java.util.Calendar.getInstance().apply {
                    timeInMillis = oldTime
                    add(java.util.Calendar.WEEK_OF_YEAR, 1)
                }
                val nextTime = calendar.timeInMillis
                
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                val newIntent = Intent(context, AlarmReceiver::class.java).apply {
                    action = intent.action
                    putExtras(intent)
                    putExtra("timeInMillis", nextTime)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, id, newIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val showIntent = Intent(context, MainActivity::class.java)
                val showPendingIntent = PendingIntent.getActivity(
                    context, id, showIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                val clockInfo = android.app.AlarmManager.AlarmClockInfo(nextTime, showPendingIntent)
                alarmManager.setAlarmClock(clockInfo, pendingIntent)
            }
        }
    }
}

