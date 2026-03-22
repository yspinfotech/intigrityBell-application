import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String type; // 'holiday', 'notice', 'leave', 'local'
  final String? createdBy;
  final String category;
  final int? notificationId;
  final int? reminderTime; // Minutes before event
  final String sound; // 'default', 'alarm1', 'alarm2'
  final bool isRepeating;
  final List<int> repeatDays; // [1, 2, 3...] 1=Mon, 7=Sun

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.startTime,
    this.endTime,
    this.type = 'local',
    this.createdBy,
    this.category = 'General',
    this.notificationId,
    this.reminderTime,
    this.sound = 'default',
    this.isRepeating = false,
    this.repeatDays = const [],
  });

  String get dateString => DateFormat('MMM dd, yyyy').format(date);
  
  String get timeRange {
    if (startTime == null || endTime == null) return 'All Day';
    return '${_formatTimeOfDay(startTime!)} - ${_formatTimeOfDay(endTime!)}';
  }
  
  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      startTime: (json['startTimeHour'] != null) ? TimeOfDay(
        hour: json['startTimeHour'],
        minute: json['startTimeMinute'] ?? 0,
      ) : null,
      endTime: (json['endTimeHour'] != null) ? TimeOfDay(
        hour: json['endTimeHour'],
        minute: json['endTimeMinute'] ?? 0,
      ) : null,
      type: (json['type'] ?? 'local').toString(),
      createdBy: (json['createdBy'] is Map) ? (json['createdBy']['name'] ?? '').toString() : json['createdBy']?.toString(),
      category: (json['category'] ?? 'General').toString(),
      notificationId: json['notificationId'],
      reminderTime: json['reminderTime'],
      sound: (json['sound'] ?? 'default').toString(),
      isRepeating: json['isRepeating'] ?? false,
      repeatDays: List<int>.from(json['repeatDays'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'category': category,
      'notificationId': notificationId,
      'reminderTime': reminderTime,
      'sound': sound,
      'isRepeating': isRepeating,
      'repeatDays': repeatDays,
    };
    if (startTime != null) {
      map['startTimeHour'] = startTime!.hour;
      map['startTimeMinute'] = startTime!.minute;
    }
    if (endTime != null) {
      map['endTimeHour'] = endTime!.hour;
      map['endTimeMinute'] = endTime!.minute;
    }
    return map;
  }
}
