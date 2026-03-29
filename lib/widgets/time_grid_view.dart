import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:integrity/models/event_model.dart';
import 'package:integrity/models/task_model.dart';

class TimeGridView extends StatelessWidget {
  final DateTime selectedDate;
  final List<Event> events;
  final List<TaskModel> tasks;

  const TimeGridView({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: 1440, // 24 hours * 60 pixels per hour
        child: Stack(
          children: [
            _buildTimeGrid(),
            ...events.map((e) => _buildEventBlock(context, e)),
            ...tasks.map((t) => _buildTaskBlock(t)),
            _buildCurrentTimeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeGrid() {
    return Column(
      children: List.generate(24, (hour) {
        return Container(
          height: 60,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('h a').format(DateTime(2021, 1, 1, hour)),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
              const VerticalDivider(color: Colors.white12, width: 1),
              const Expanded(child: SizedBox()),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEventBlock(BuildContext context, Event event) {
    if (event.startTime == null) return const SizedBox();

    final double top = (event.startTime!.hour * 60.0) + event.startTime!.minute;
    final double height = event.endTime != null 
        ? ((event.endTime!.hour * 60.0) + event.endTime!.minute) - top
        : 60.0;

    return Positioned(
      top: top,
      left: 70,
      right: 16,
      height: height < 30 ? 30 : height,
      child: Container(
        decoration: BoxDecoration(
          color: _getColor(event).withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (height > 40)
              Text(
                '${event.startTime!.format(context)} - ${event.endTime?.format(context) ?? ""}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskBlock(TaskModel task) {
    // Tasks are typically point-in-time or 1 hour long for grid display
    final double top = (task.scheduledDate.hour * 60.0) + task.scheduledDate.minute;
    
    return Positioned(
      top: top,
      left: 80,
      right: 20,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71).withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
             Icon(
              task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    if (selectedDate.year != now.year || selectedDate.month != now.month || selectedDate.day != now.day) {
      return const SizedBox();
    }

    final double top = (now.hour * 60.0) + now.minute;

    return Positioned(
      top: top - 4,
      left: 60,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 2, color: Colors.red)),
        ],
      ),
    );
  }

  Color _getColor(Event event) {
    switch (event.type.toLowerCase()) {
      case 'holiday': return Colors.blueAccent;
      case 'notice': return Colors.orangeAccent;
      default: return Colors.purpleAccent;
    }
  }
}
