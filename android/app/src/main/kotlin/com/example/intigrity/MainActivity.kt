package com.example.intigrity

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.os.Vibrator
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val RINGTONE_CHANNEL = "com.example.intigrity/ringtone"
    private val ALARM_CHANNEL = "com.example.intigrity/alarm"
    private var pendingResult: MethodChannel.Result? = null
    private var flutterEngineInstance: FlutterEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Critical for Alarm: Bypass lock screen and turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineInstance = flutterEngine

        // Ringtone Picker Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    pendingResult = result
                    val existingUriStr = call.argument<String>("existingUri")
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                    intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                    intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Sound")
                    intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    if (existingUriStr != null && existingUriStr.startsWith("content://")) {
                        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(existingUriStr))
                    }
                    startActivityForResult(intent, 999)
                }
                "getDefaultAlarmUri" -> {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    result.success(uri?.toString())
                }
                else -> result.notImplemented()
            }
        }

        // Native Alarm Scheduling Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val title = call.argument<String>("title") ?: "Alarm"
                    val soundUri = call.argument<String>("soundUri")

                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    val intent = Intent(this, AlarmReceiver::class.java).apply {
                        putExtra("id", id)
                        putExtra("title", title)
                        putExtra("soundUri", soundUri)
                        // This prevents PendingIntent reuse from overriding extras if we schedule multiple
                        action = "ALARM_ACTION_$id" 
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val showIntent = Intent(this, MainActivity::class.java)
                    val showPendingIntent = PendingIntent.getActivity(
                        this, id, showIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    
                    val clockInfo = android.app.AlarmManager.AlarmClockInfo(timeInMillis, showPendingIntent)
                    alarmManager.setAlarmClock(clockInfo, pendingIntent)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    val intent = Intent(this, AlarmReceiver::class.java).apply {
                        action = "ALARM_ACTION_$id"
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    alarmManager.cancel(pendingIntent)
                    result.success(true)
                }
                "stopAlarmService" -> {
                    val stopIntent = Intent(this, AlarmService::class.java).apply {
                        action = "STOP_ALARM"
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                "getInitialAlarm" -> {
                    if (intent.getBooleanExtra("trigger_alarm", false)) {
                        val id = intent.getIntExtra("id", 0)
                        val title = intent.getStringExtra("title")
                        val soundUri = intent.getStringExtra("soundUri")
                        
                        intent.removeExtra("trigger_alarm")
                        
                        result.success(mapOf(
                            "id" to id,
                            "title" to title,
                            "soundUri" to soundUri
                        ))
                    } else {
                        result.success(null)
                    }
                }
                "startAlarmService" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Alarm"
                    val soundUri = call.argument<String>("soundUri")
                    val intent = Intent(this, AlarmService::class.java).apply {
                        putExtra("id", id)
                        putExtra("title", title)
                        putExtra("soundUri", soundUri)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "cancelVibration" -> {
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        vibrator.cancel()
                    } catch (e: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("trigger_alarm", false)) {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Alarm"
            val soundUri = intent.getStringExtra("soundUri")
            
            intent.removeExtra("trigger_alarm")
            
            flutterEngineInstance?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, ALARM_CHANNEL)
                    .invokeMethod("onAlarmRing", mapOf("id" to id, "title" to title, "soundUri" to soundUri))
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 999) {
            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                pendingResult?.success(uri?.toString())
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}

