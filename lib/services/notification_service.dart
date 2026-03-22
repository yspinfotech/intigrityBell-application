import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/alarm_ring_screen.dart';
import 'dart:typed_data';

/// Singleton service for managing local notifications with robust permission handling
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isAlarmPlaying = false;
  String? _currentlyPlayingUri;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<String?> activeAlarmTitle = ValueNotifier<String?>(null);
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? navigatorKey;
  String? _pendingAlarmPayload;

  // Track scheduled notifications for validation
  final Map<int, Map<String, dynamic>> _scheduledNotifications = {};

  /// Initialize the notification service and request necessary permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔔 Initializing Notification Service...');
    
    // Initialize timezone database
    tzdata.initializeTimeZones();
    final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('✅ Timezone initialized securely to $timeZoneName');

    // Setup Local Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Notification tapped: ${response.payload} action: ${response.actionId}');
        if (response.actionId == 'stop_alarm' && response.payload != null) {
            final parts = response.payload!.split('|');
            if (parts.length >= 4) {
                int id = int.tryParse(parts[1]) ?? 0;
                stopAlarmSound(id);
            }
        } else if (response.payload != null && response.payload!.contains('alarm')) {
             _handleAlarmTrigger(response.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: _notificationBackgroundCallback,
    );

    // Check if app was launched from a notification (Step 3)
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        print("🔔 [DEBUG] App launched by notification, payload: $payload");
        if (payload != null && payload.contains('alarm')) {
            _handleAlarmTrigger(payload);
        }
    }

    // FIX STEP 1, 2, 3: Listen to Alarm Ring Stream
    Alarm.ringStream.stream.listen((alarmSettings) async {
      debugPrint('⏰ Alarm is ringing from package: ${alarmSettings.id}');
      
      // Retrieve the specific sound URI for this alarm instance (saved during scheduling)
      final prefs = await SharedPreferences.getInstance();
      final soundUri = prefs.getString('alarm_sound_${alarmSettings.id}') ?? 'default';
      
      // Trigger the existing AlarmRingScreen via payload handler
      final payload = 'alarm|${alarmSettings.id}|$soundUri|${alarmSettings.notificationTitle}';
      _handleAlarmTrigger(payload);
    });

    // Create the alarm channel explicitly for Android to enforce highest priority with sound
    if (Platform.isAndroid) {
      final alarmChannels = [
        const AndroidNotificationChannel(
          'alarm_channel', 'Alarm Notifications',
          description: 'High importance channel for alarm alerts',
          importance: Importance.max, 
          playSound: true,
          enableVibration: false, // FIX 1 & 4: DISABLE vibration from notification channel (source prevention)
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        const AndroidNotificationChannel(
          'reminder_channel', 'Event Reminders',
          description: 'Channel for event reminders',
          importance: Importance.high,
          playSound: true,
        ),
        const AndroidNotificationChannel(
          'task_channel', 'Task Notifications',
          description: 'Channel for task reminders',
          importance: Importance.high,
          playSound: true,
        ),
      ];

      for (var ch in alarmChannels) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(ch);
      }
    }

    // Handle Cross-Version Android Permissions
    await checkAndRequestPermissions();

    debugPrint('✅ Local Notifications initialized');

    _isInitialized = true;
    debugPrint('✅ Notification Service fully initialized');
  }

  /// Request permissions based on Android version
  Future<void> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    debugPrint('📱 Android SDK Version: $sdkInt');

    // 1. Handle Notification Permission (Android 13+ / SDK 33)
    if (sdkInt >= 33) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        debugPrint('Asking for notification permission...');
        await Permission.notification.request();
      }
    }

    // 2. Handle Exact Alarm Permission (Android 12+ / SDK 31)
    if (sdkInt >= 31) {
      final status = await Permission.scheduleExactAlarm.status;
      debugPrint('Exact alarm status: $status');
      
      if (!status.isGranted) {
        debugPrint('Exact alarm permission not granted. Opening settings...');
        const intent = AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          data: 'package:com.example.intigrity',
        );
        try {
          await intent.launch();
        } catch (e) {
          debugPrint('Could not launch exact alarm settings: $e');
        }
      }
    }

    // 3. Request Ignoring Battery Optimizations (Critical for Alarms)
    if (sdkInt >= 23) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('Battery optimization status: $status');
      if (!status.isGranted) {
        debugPrint('Requesting battery optimization ignore...');
        const intent = AndroidIntent(
          action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
          data: 'package:com.example.intigrity',
        );
        try {
          await intent.launch();
        } catch (e) {
          debugPrint('Could not launch battery optimization settings: $e');
        }
      }
    }

    // 4. Audio/Storage access for custom ringtones (Step 7)
    if (sdkInt >= 33) {
      if (!(await Permission.audio.isGranted)) {
        await Permission.audio.request();
      }
    } else {
      if (!(await Permission.storage.isGranted)) {
        await Permission.storage.request();
      }
    }
  }

  @pragma('vm:entry-point')
  static void _notificationBackgroundCallback(NotificationResponse response) {
    print("🔔 [DEBUG] Background Notification Callback: ${response.payload} (Action: ${response.actionId})");
    if (response.actionId == 'stop_alarm' && response.payload != null) {
        final parts = response.payload!.split('|');
        if (parts.length >= 4) {
            int id = int.tryParse(parts[1]) ?? 0;
            NotificationService().stopAlarmSound(id);
        }
    } else if (response.payload != null && response.payload!.contains('alarm')) {
        NotificationService()._handleAlarmTrigger(response.payload!);
    }
  }

  static const _alarmChannel = MethodChannel('com.example.intigrity/alarm');

  void _handleAlarmTrigger(String payload) {
    try {
        debugPrint('🔔 Triggering alarm from payload: $payload');
        final parts = payload.split('|');
        // New structure: "alarm|id|soundUri|title"
        if (parts.length >= 4) {
            int id = int.tryParse(parts[1]) ?? 0;
            String soundUri = parts[2];
            String title = parts[3];
            
            // FIX 8 / 7: DEBUG LOGS
            print("Alarm triggered");
            
            if (navigatorKey?.currentState != null) {
                print("🔔 [DEBUG] Navigating to AlarmRingScreen with ID: $id");
                
                // FIX 2, 3, 5: Manual Sound Playback (Native & Asset-based bridge)
                _playAlarmSound(id, title, soundUri);
                
                navigatorKey!.currentState!.push(
                  MaterialPageRoute(
                    builder: (context) => AlarmRingScreen(
                      id: id,
                      title: title,
                      soundUri: 'assets/alarm.mp3',
                    ),
                  ),
                );
            } else {
                print("⚠️ [DEBUG] Navigator not ready. Storing pending alarm.");
                _pendingAlarmPayload = payload;
            }
        }
    } catch (e) {
        debugPrint('Error handling alarm trigger: $e');
    }
  }

  /// Process any alarm that triggered before the navigator was ready (Step 7)
  void processPendingAlarm() {
    if (_pendingAlarmPayload != null) {
        print("🔔 [DEBUG] Processing pending alarm: $_pendingAlarmPayload");
        final payload = _pendingAlarmPayload!;
        _pendingAlarmPayload = null;
        _handleAlarmTrigger(payload);
    }
  }

  Future<void> _playAlarmSound(int id, String? title, String? soundUri) async {
    try {
      _isAlarmPlaying = true;
      print("Playing sound (Native Service)");
      
      // FIX: Use Native AlarmService for maximum reliability on Oppo/ColorOS
      await _alarmChannel.invokeMethod('startAlarmService', {
        'id': id,
        'title': title ?? 'Alarm',
        'soundUri': soundUri
      });
      
      // Keep state locally too
      debugPrint('🎵 Native AlarmService triggered for ID: $id');
    } catch (e) {
      debugPrint('Error playing native alarm sound: $e');
    }
  }

  Future<void> stopAlarmSound(int id) async {
    try {
      print("🛑 Stopping alarm completely (ID: $id)");
      _isAlarmPlaying = false;
      
      // Cleanup persisted sound info
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_sound_$id');
      
      // === STRICT ORDER: Audio → Alarm → Notification → Vibration ===
      
      // 1. Stop native AlarmService (audio + foreground notification)
      await _alarmChannel.invokeMethod('stopAlarmService');
      
      // 2. Stop Flutter audio player
      await _audioPlayer.stop();
      
      // 3. Stop Alarm package (this should kill its internal vibration loop)
      await Alarm.stop(id);
      
      // 4. Cancel the notification (THIS IS CRITICAL - notification channel drives system vibration)
      await _notificationsPlugin.cancel(id);
      await _notificationsPlugin.cancelAll(); // Nuclear option: kill ALL lingering notifications
      
      // 5. Force cancel vibration at hardware level (DOUBLE CANCEL)
      try {
        await _alarmChannel.invokeMethod('cancelVibration');
        await Future.delayed(const Duration(milliseconds: 200));
        await _alarmChannel.invokeMethod('cancelVibration');
      } catch (e) {
        print("Vibration cancel error: $e");
      }
      
      debugPrint('🔇 Alarm stopped completely (ID: $id)');
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  /// Check if notification service is initialized
  bool get isInitialized => _isInitialized;

  /// Get information about scheduled notifications
  int get scheduledNotificationCount => _scheduledNotifications.length;

  tz.TZDateTime _nextInstanceOfAlarm(int hour, int minute, [int? weekday]) {
    final DateTime now = DateTime.now();
    
    // FIX 1: Force exact time (seconds = 0)
    DateTime dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0, // MUST be 0
    );

    // FIX 2: Use TZDateTime properly (conversion source)
    tz.TZDateTime scheduledTime = tz.TZDateTime.from(dateTime, tz.local);

    // FIX 3: Ensure future time (No past scheduling)
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // FIX 7: DEBUG LOGS
    print("Selected Time: $dateTime");
    print("Scheduled Time: $scheduledTime");

    if (weekday != null) {
      while (scheduledTime.weekday != weekday) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    }

    debugPrint('🕒 Next instance calculated: $scheduledTime (Day: ${scheduledTime.weekday})');
    return scheduledTime;
  }



  /// Schedule a notification for an event
  Future<List<int>> scheduleEventNotification(Event event) async {
    if (!_isInitialized) await initialize();
    
    List<int> scheduledIds = [];

    try {
      final int hour = event.startTime?.hour ?? 9; 
      final int minute = event.startTime?.minute ?? 0;
      final int baseId = event.notificationId ?? (event.id.hashCode % 100000000).abs();

      if (event.isRepeating && event.repeatDays.isNotEmpty) {
        // Schedule for each selected day
        for (int day in event.repeatDays) {
          final scheduledTime = _nextInstanceOfAlarm(hour, minute, day);
          final dailyId = baseId + day; // Unique ID for each weekday instance
          
          await _scheduleEventAtTime(event, scheduledTime, dailyId, isRepeat: true);
          scheduledIds.add(dailyId);
        }
      } else if (event.isRepeating) {
        // Default repeat (weekly on the event's original weekday)
        final scheduledTime = _nextInstanceOfAlarm(hour, minute, event.date.weekday);
        await _scheduleEventAtTime(event, scheduledTime, baseId, isRepeat: true);
        scheduledIds.add(baseId);
      } else {
        // FIX 1: Force exact time (seconds = 0)
        DateTime dateTime = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          hour,
          minute,
          0, // MUST be 0
        );

        // FIX 2: Use TZDateTime properly (conversion source)
        tz.TZDateTime scheduledTime = tz.TZDateTime.from(dateTime, tz.local);

        // FIX 3: Ensure future time
        if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        
        // FIX 7: DEBUG LOGS
        print("Selected Time: $dateTime");
        print("Scheduled Time: $scheduledTime");

        await _scheduleEventAtTime(event, scheduledTime, baseId, isRepeat: false);
        scheduledIds.add(baseId);
      }

      // Reminder Notification (similarly handled if needed, but for simplicity we keep it as is or slightly improved)
      if (event.reminderTime != null && event.reminderTime! > 0) {
        // Basic reminder logic - usually for non-repeating or standard first instance
        final mainTime = event.isRepeating 
          ? _nextInstanceOfAlarm(hour, minute, event.repeatDays.isNotEmpty ? event.repeatDays.first : event.date.weekday)
          : DateTime(event.date.year, event.date.month, event.date.day, hour, minute, 0);
          
        final reminderTime = mainTime.subtract(Duration(minutes: event.reminderTime!));
        
        if (reminderTime.isAfter(DateTime.now())) {
          final reminderId = baseId + 100; // Unique offset for reminder
          
          await _schedule(
            id: reminderId,
            title: '⏰ Reminder: ${event.title}',
            body: 'Starts in ${event.reminderTime} minutes',
            scheduledDate: reminderTime,
            channelId: 'reminder_channel',
            channelName: 'Event Reminders',
            sound: event.sound,
            matchDateTimeComponents: event.isRepeating ? DateTimeComponents.dayOfWeekAndTime : null,
          );
          
          scheduledIds.add(reminderId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error scheduling event notification: $e');
    }
    
    return scheduledIds;
  }

  /// Helper to schedule the actual event notification
  Future<void> _scheduleEventAtTime(Event event, tz.TZDateTime time, int id, {bool isRepeat = false}) async {
    // 1. Immediately Prep Sound Info (No async gap for Alarm package)
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_sound_$id', event.sound);
    
    // 2. Convert to CLEAN local DateTime for alarm package (no TZ artifacts)
    final DateTime cleanTime = DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
      0, // FORCE seconds = 0
      0, // FORCE milliseconds = 0
    );
    
    // 3. FIX STEP 2 & 3: Use Alarm Package
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: cleanTime, // USE CLEAN TIME — no timezone conversion artifacts
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: false,
      volume: 1.0,
      fadeDuration: 0,
      notificationTitle: event.title,
      notificationBody: 'Alarm is ringing — tap to open',
      enableNotificationOnKill: true,
    );

    // FIX 7: DEBUG LOGS
    print("⏰ Alarm ID: $id");
    print("⏰ Original Scheduled Time: $time");
    print("⏰ Clean Playback Time: $cleanTime");
    print("⏰ Activating: ${event.title}");

    try {
      await Alarm.set(alarmSettings: alarmSettings);

      _scheduledNotifications[id] = {
        'title': event.title,
        'type': 'event',
        'scheduledFor': time,
        'eventId': event.id,
      };
      
      debugPrint('✅ Alarm package scheduled: ${event.title} at $time (ID: $id, Repeat: $isRepeat)');
    } catch (e) {
      debugPrint('❌ Error scheduling Alarm package: $e');
    }
  }

  /// Schedule a notification for a task (with 15 minute default reminder)
  /// 
  /// Tasks are reminded 15 minutes before the scheduled time
  /// 
  /// Returns the notification ID that was scheduled (or -1 if not scheduled)
  Future<int> scheduleTaskNotification(TaskModel task) async {
    if (!_isInitialized) await initialize();

    try {
      final scheduledDate = task.scheduledDate;
      final notificationTime = scheduledDate.subtract(const Duration(minutes: 15));

      if (notificationTime.isAfter(DateTime.now())) {
        final id = (task.id.hashCode % 100000000).abs();
        
        await _schedule(
          id: id,
          title: '📋 Task Reminder: ${task.title}',
          body: task.description.isNotEmpty ? 
            task.description : 'Your task is due soon',
          scheduledDate: notificationTime,
          channelId: 'task_channel',
          channelName: 'Task Notifications',
        );
        
        _scheduledNotifications[id] = {
          'title': task.title,
          'type': 'task',
          'scheduledFor': notificationTime,
          'taskId': task.id,
        };
        
        debugPrint('✅ Task notification scheduled for ${task.title}');
        return id;
      }
    } catch (e) {
      debugPrint('❌ Error scheduling task notification: $e');
    }
    
    return -1;
  }

  /// Internal method to schedule a notification with exact timing
  /// 
  /// Uses zonedSchedule() for exact time scheduling that:
  /// - Works even when app is closed
  /// - Respects timezone changes
  /// - Uses exact timing (no delays)
  /// - Can survive device reboots (on Android)
  /// 
  /// @param id: Unique notification ID
  /// @param title: Notification title
  /// @param body: Notification body/content
  /// @param scheduledDate: Exact DateTime to show notification
  /// @param channelId: Android notification channel ID
  /// @param channelName: Android notification channel name (for users)
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
    String? sound,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      // Convert to timezone-aware DateTime for exact scheduling
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      final String payload = 'alarm|$id|${sound ?? 'default'}|$title';

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Notifications for $channelName',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
            color: const Color(0xFF2ECC71),
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: sound ?? 'default',
            badgeNumber: null,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      
      debugPrint('✅ Notification scheduled: ID=$id at $tzDateTime');
    } catch (e) {
      debugPrint('❌ Error scheduling notification ID=$id: $e');
      if (e.toString().contains('exact_alarm')) {
        debugPrint('⚠️ Refetching exact alarm permission might be needed.');
        // Fallback to inexact if needed, but exact is required for alarms
        // We re-check permissions for next time
        checkAndRequestPermissions();
      }
      rethrow;
    }
  }

  /// Cancel a scheduled notification and its associated reminder
  /// 
  /// Cancels both the main notification, weekday instances, and reminder
  /// 
  /// @param id: The base notification ID to cancel
  Future<void> cancelNotification(int id) async {
    try {
      // FIX STEP 8: Cancel via Alarm package
      await Alarm.stop(id);
      await _notificationsPlugin.cancel(id);
      debugPrint('✅ Base notification/alarm cancelled: ID=$id');
      
      // Cancel possible weekday instances (1-7)
      for (int i = 1; i <= 7; i++) {
        await Alarm.stop(id + i);
        await _notificationsPlugin.cancel(id + i);
      }
      
      // Cancel reminder (baseId + 100)
      await _notificationsPlugin.cancel(id + 100);
      
      // Remove from tracking (more comprehensive cleanup)
      _scheduledNotifications.removeWhere((key, value) => 
        key == id || (key >= id + 1 && key <= id + 7) || key == id + 100);
        
      debugPrint('✅ All associated notifications for ID=$id cancelled');
    } catch (e) {
      debugPrint('❌ Error canceling notification ID=$id: $e');
    }
  }

  /// Cancel all scheduled notifications
  /// 
  /// Use with caution - this removes all pending notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      _scheduledNotifications.clear();
      debugPrint('✅ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error canceling all notifications: $e');
    }
  }

  /// Show an instant notification immediately (not scheduled)
  /// 
  /// Use for:
  /// - Notifications that need to display immediately
  /// - Firebase Cloud Messaging notifications
  /// - User action feedback
  /// 
  /// @param title: Notification title
  /// @param body: Notification content
  /// @param payload: Optional data for the notification
  Future<void> showInstantNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'instant_channel',
            'Instant Notifications',
            channelDescription: 'For immediate notifications',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: payload,
      );
      
      debugPrint('✅ Instant notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing instant notification: $e');
    }
  }

  /// Get information about a scheduled notification
  /// 
  /// Returns notification details or null if not found
  Map<String, dynamic>? getScheduledNotificationInfo(int id) {
    return _scheduledNotifications[id];
  }

  /// Get list of all scheduled notification IDs
  List<int> getScheduledNotificationIds() {
    return _scheduledNotifications.keys.toList();
  }
}
