import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/event_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../providers/plan_day_provider.dart';
import '../widgets/calendar_drawer.dart';
import '../widgets/schedule_view.dart';
import '../widgets/time_grid_view.dart';
import '../services/notification_service.dart';
import 'event_details_screen.dart';
import '../models/task_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

enum CalendarViewType { schedule, day, week, month }

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarViewType _viewType = CalendarViewType.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.token != null) {
        context.read<TaskProvider>().fetchTasks();
        context.read<EventProvider>().fetchSystemEvents(userProvider.token!);
      }

      // Process any alarm that fired while app was starting (Step 7)
      NotificationService().processPendingAlarm();

      // Show battery optimization guide if needed (Post-alarm-fix polish)
      _checkAndShowBatteryGuide();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAndShowBatteryGuide() async {
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isDenied || status.isLimited) {
        _showBatteryOptimizationGuide();
      }
    }
  }

  void _showBatteryOptimizationGuide() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(Icons.battery_saver, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(
              'Alarm Reliability',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        content: Text(
          'To ensure your alarms ring exactly on time, please disable battery optimizations for Integrity Bell.\n\nThis prevents the system from delaying or killing the alarm service.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              NotificationService().requestIgnoreBatteryOptimizations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const CalendarDrawer(),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Theme.of(context).iconTheme.color),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.account_circle_outlined,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => Navigator.pushNamed(context, '/user-profile'),
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_none_outlined,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-event'),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: _buildCurrentView(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Event',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            setState(() => _currentIndex = 0);
          } else if (index == 1) {
            Navigator.pushNamed(context, '/add-event');
          }
        },
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_viewType == CalendarViewType.schedule) {
      return const ScheduleView();
    }

    if (_viewType == CalendarViewType.day ||
        _viewType == CalendarViewType.week) {
      return _buildGridView();
    }

    return Column(
      children: [
        _buildCalendarHeader(),
        Expanded(child: _buildAgendaList()),
      ],
    );
  }

  Widget _buildGridView() {
    return Consumer2<EventProvider, TaskProvider>(
      builder: (context, eventProvider, taskProvider, _) {
        final selectedDate = _selectedDay ?? DateTime.now();
        final events = eventProvider.getEventsByDate(selectedDate);
        final filters = eventProvider.filters;
        List<TaskModel> tasks = [];
        if (filters['task'] == true) {
          tasks = taskProvider.getTasksByDate(selectedDate);
        }

        return Column(
          children: [
            _buildCalendarHeader(),
            Expanded(
              child: TimeGridView(
                selectedDate: selectedDate,
                events: events,
                tasks: tasks,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        headerVisible: false,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          weekendTextStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.7),
          ),
          outsideTextStyle: const TextStyle(color: Colors.grey),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: const BoxDecoration(
            color: Color(0xFF6C63FF),
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.grey, fontSize: 12),
          weekendStyle: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAgendaList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Agenda for ${DateFormat('MMM dd').format(_selectedDay ?? DateTime.now())}",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Consumer3<EventProvider, TaskProvider, PlanDayProvider>(
            builder:
                (context, eventProvider, taskProvider, planDayProvider, _) {
                  final selectedDate = _selectedDay ?? DateTime.now();
                  final events = eventProvider.getEventsByDate(selectedDate);
                  final plans = planDayProvider.getPlansByDate(selectedDate);

                  final filters = eventProvider.filters;
                  List<dynamic> tasks = [];
                  if (filters['task'] == true) {
                    tasks = taskProvider.getTasksByDate(selectedDate);
                  }

                  if (events.isEmpty && tasks.isEmpty && plans.isEmpty) {
                    return _buildEmptyAgenda();
                  }

                  return Column(
                    children: [
                      if (events.isNotEmpty)
                        ...events.map((event) => _buildEventCard(event)),
                      if (tasks.isNotEmpty)
                        ...tasks.map(
                          (task) => _buildTaskCard(task, taskProvider),
                        ),
                    ],
                  );
                },
          ),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildEmptyAgenda() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_note, color: Colors.grey[600], size: 64),
            const SizedBox(height: 16),
            Text(
              'No plans for today',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final Color color = _getEventColor(event);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.timeRange,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task, TaskProvider taskProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (value) {
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              taskProvider.toggleTaskCompletion(
                task.id,
                userProvider.token ?? '',
              );
            },
            activeColor: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.timeString,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildPriorityBadge(task.priority),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.redAccent;
        break;
      case 'medium':
        color = Colors.orangeAccent;
        break;
      default:
        color = Theme.of(context).primaryColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getEventColor(dynamic event) {
    switch (event.type.toLowerCase()) {
      case 'holiday':
        return Colors.blueAccent;
      case 'notice':
        return Colors.orangeAccent;
      default:
        return Colors.purpleAccent;
    }
  }
}
