import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/event_provider.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Consumer2<TaskProvider, EventProvider>(
        builder: (context, taskProvider, eventProvider, _) {
          final notifications = _buildNotifications(context, taskProvider, eventProvider);

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Task deadlines and events will appear here',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), fontSize: 12),
                  ),
                ],
              ),
            );
          }

          // Group: Overdue | Due Today | Upcoming | Events
          final overdue = notifications.where((n) => n['urgency'] == 'overdue').toList();
          final today = notifications.where((n) => n['urgency'] == 'today').toList();
          final upcoming = notifications.where((n) => n['urgency'] == 'upcoming').toList();
          final events = notifications.where((n) => n['urgency'] == 'event').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
               if (overdue.isNotEmpty) ...[
                _sectionHeader('🔴 Overdue Tasks', Colors.redAccent),
                ...overdue.map((n) => _notificationCard(n, context)),
                const SizedBox(height: 12),
              ],
               if (today.isNotEmpty) ...[
                _sectionHeader('🟡 Due Today', Colors.orangeAccent),
                ...today.map((n) => _notificationCard(n, context)),
                const SizedBox(height: 12),
              ],
               if (upcoming.isNotEmpty) ...[
                _sectionHeader('🟢 Upcoming', Theme.of(context).primaryColor),
                ...upcoming.map((n) => _notificationCard(n, context)),
                const SizedBox(height: 12),
              ],
               if (events.isNotEmpty) ...[
                _sectionHeader('📢 Events & Notices', Colors.blueAccent),
                ...events.map((n) => _notificationCard(n, context)),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildNotifications(
      BuildContext context, TaskProvider taskProvider, EventProvider eventProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifications = <Map<String, dynamic>>[];

    // Task-based notifications
    for (final task in taskProvider.tasks) {
      if (task.isCompleted) continue;

      final taskDay = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );

      final isOverdue = taskDay.isBefore(today);
      final isDueToday = taskDay.isAtSameMomentAs(today);
      final isUpcoming = taskDay.isAfter(today) &&
          taskDay.isBefore(today.add(const Duration(days: 7)));

      if (!isOverdue && !isDueToday && !isUpcoming) continue;

      String urgency;
      Color color;
      IconData icon;
      String timeLabel;

      if (isOverdue) {
        urgency = 'overdue';
        color = Colors.redAccent;
        icon = Icons.warning_rounded;
        final daysAgo = today.difference(taskDay).inDays;
        timeLabel = daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago';
      } else if (isDueToday) {
        urgency = 'today';
        color = Colors.orangeAccent;
        icon = Icons.schedule_rounded;
        timeLabel = 'Due at ${DateFormat('h:mm a').format(task.scheduledDate)}';
      } else {
        urgency = 'upcoming';
        color = Theme.of(context).primaryColor;
        icon = Icons.event_available_rounded;
        final daysLeft = taskDay.difference(today).inDays;
        timeLabel = daysLeft == 1 ? 'Tomorrow' : 'In $daysLeft days';
      }

      notifications.add({
        'icon': icon,
        'color': color,
        'title': task.title,
        'description': task.description.isNotEmpty
            ? task.description
            : 'Priority: ${task.priority}',
        'time': timeLabel,
        'urgency': urgency,
        'priority': task.priority.toLowerCase(),
      });
    }

    // Event-based notifications
    for (final event in eventProvider.events) {
      final eventDay = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      final daysUntil = eventDay.difference(today).inDays;
      if (daysUntil < 0 || daysUntil > 14) continue;

      String timeLabel;
      if (daysUntil == 0) {
        timeLabel = 'Today';
      } else if (daysUntil == 1) {
        timeLabel = 'Tomorrow';
      } else {
        timeLabel = 'In $daysUntil days';
      }

      IconData icon;
      switch (event.type.toLowerCase()) {
        case 'holiday':
          icon = Icons.celebration_rounded;
          break;
        case 'leave':
          icon = Icons.beach_access_rounded;
          break;
        default:
          icon = Icons.campaign_rounded;
      }

      notifications.add({
        'icon': icon,
        'color': Colors.blueAccent,
        'title': event.title,
        'description': event.description,
        'time': timeLabel,
        'urgency': 'event',
      });
    }

    return notifications;
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> notification, BuildContext context) {
    final color = notification['color'] as Color;
    final String urgency = notification['urgency'] ?? '';

    // Priority badge color
    Color? priorityColor;
    if (notification['priority'] == 'high') {
      priorityColor = Colors.redAccent;
    } else if (notification['priority'] == 'medium') {
      priorityColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: urgency == 'overdue'
            ? Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notification['icon'] as IconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (priorityColor != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (notification['priority'] as String).toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if ((notification['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification['description'] as String,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  notification['time'] as String,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
