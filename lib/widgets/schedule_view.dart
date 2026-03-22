import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../providers/event_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../screens/event_details_screen.dart';

class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EventProvider, TaskProvider>(
      builder: (context, eventProvider, taskProvider, _) {
        final events = eventProvider.filteredEvents;
        final filters = eventProvider.filters;
        List<TaskModel> tasks = [];
        if (filters['task'] == true) {
          tasks = taskProvider.tasks;
        }

        // Combine and sort by date
        final List<dynamic> items = [...events, ...tasks];
        items.sort((a, b) {
          final dateA = (a is Event) ? a.date : (a as TaskModel).scheduledDate;
          final dateB = (b is Event) ? b.date : (b as TaskModel).scheduledDate;
          return dateA.compareTo(dateB);
        });

        // Group by Date
        final Map<String, List<dynamic>> groupedItems = {};
        for (var item in items) {
          final date = (item is Event) ? item.date : (item as TaskModel).scheduledDate;
          final key = DateFormat('yyyy-MM-dd').format(date);
          if (!groupedItems.containsKey(key)) {
            groupedItems[key] = [];
          }
          groupedItems[key]!.add(item);
        }

        final sortedKeys = groupedItems.keys.toList()..sort();

        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No scheduled items',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final dateKey = sortedKeys[index];
            final dateItems = groupedItems[dateKey]!;
            final date = DateTime.parse(dateKey);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateHeader(date),
                const SizedBox(height: 12),
                ...dateItems.map((item) => _buildItemCard(context, item, taskProvider)).toList(),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Row(
      children: [
        Container(
          width: 40,
          child: Column(
            children: [
              Text(
                DateFormat('EEE').format(date).toUpperCase(),
                style: TextStyle(
                  color: isToday ? const Color(0xFF2ECC71) : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('d').format(date),
                style: TextStyle(
                  color: isToday ? const Color(0xFF2ECC71) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, dynamic item, TaskProvider taskProvider) {
    final bool isTask = item is TaskModel;
    final Color color = _getColor(item);
    final String title = item.title;
    final String time = isTask ? item.timeString : item.timeRange;
    final String description = item.description;

    return Container(
      margin: const EdgeInsets.only(left: 52, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3F),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: ListTile(
        onTap: () {
          if (!isTask) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventDetailsScreen(event: item)),
            );
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: (isTask && item.isCompleted) ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (time != 'All Day')
              Text(
                time,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
        trailing: isTask ? Checkbox(
          value: item.isCompleted,
          onChanged: (_) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            taskProvider.toggleTaskCompletion(item.id, userProvider.token ?? '');
          },
          activeColor: const Color(0xFF2ECC71),
        ) : null,
      ),
    );
  }

  Color _getColor(dynamic item) {
    if (item is TaskModel) return const Color(0xFF2ECC71);
    final event = item as Event;
    switch (event.type.toLowerCase()) {
      case 'holiday': return Colors.blueAccent;
      case 'notice': return Colors.orangeAccent;
      default: return Colors.purpleAccent;
    }
  }
}
