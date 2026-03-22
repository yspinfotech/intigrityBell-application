import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/event_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../providers/plan_day_provider.dart';
import '../models/plan_day_model.dart';
import '../widgets/calendar_drawer.dart';
import '../widgets/schedule_view.dart';
import '../widgets/time_grid_view.dart';
import '../services/notification_service.dart';
import 'event_details_screen.dart';
import 'plan_day_screen.dart';
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
        context.read<TaskProvider>().fetchTasks(userProvider.token!);
        context.read<EventProvider>().fetchSystemEvents(userProvider.token!);
      }
      
      // Process any alarm that fired while app was starting (Step 7)
      NotificationService().processPendingAlarm();
    });
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1E2B),
      drawer: const CalendarDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E2B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            _buildViewSwitcher(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/user-profile'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-event'),
        backgroundColor: const Color(0xFF2ECC71),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: _buildCurrentView(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF2A2F3F),
        selectedItemColor: const Color(0xFF2ECC71),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add Event'),
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Plan Day'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
        onTap: (index) {
          if (index == 0) {
            setState(() => _currentIndex = 0);
          } else {
            switch (index) {
              case 1:
                Navigator.pushNamed(context, '/add-event');
                break;
              case 2:
                Navigator.push(context, MaterialPageRoute(builder: (context) => PlanDayScreen(initialDate: _selectedDay ?? DateTime.now())));
                break;
              case 3:
                Navigator.pushNamed(context, '/stats-dashboard');
                break;
            }
          }
        },
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return PopupMenuButton<CalendarViewType>(
      initialValue: _viewType,
      offset: const Offset(0, 40),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
      onSelected: (view) {
        setState(() {
          _viewType = view;
          if (view == CalendarViewType.month) _calendarFormat = CalendarFormat.month;
          if (view == CalendarViewType.week) _calendarFormat = CalendarFormat.week;
          if (view == CalendarViewType.day) _calendarFormat = CalendarFormat.week; 
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: CalendarViewType.schedule, child: Text("Schedule")),
        const PopupMenuItem(value: CalendarViewType.day, child: Text("Day (Grid)")),
        const PopupMenuItem(value: CalendarViewType.week, child: Text("Week (Grid)")),
        const PopupMenuItem(value: CalendarViewType.month, child: Text("Month")),
      ],
    );
  }

  Widget _buildCurrentView() {
    if (_viewType == CalendarViewType.schedule) {
      return const ScheduleView();
    }

    if (_viewType == CalendarViewType.day || _viewType == CalendarViewType.week) {
        return _buildGridView();
    }

    return Column(
      children: [
        _buildCalendarHeader(),
        Expanded(
          child: _buildAgendaList(),
        ),
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
        color: const Color(0xFF2A2F3F),
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
        calendarStyle: const CalendarStyle(
          defaultTextStyle: TextStyle(color: Colors.white),
          weekendTextStyle: TextStyle(color: Colors.white70),
          outsideTextStyle: TextStyle(color: Colors.grey),
          selectedDecoration: BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
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
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Consumer3<EventProvider, TaskProvider, PlanDayProvider>(
            builder: (context, eventProvider, taskProvider, planDayProvider, _) {
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
                  if (plans.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Daily Plans", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlanDayScreen(initialDate: _selectedDay ?? DateTime.now()))),
                            child: const Text("View All", style: TextStyle(color: Colors.blue, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    ...plans.map((plan) => _buildPlanCard(plan, planDayProvider)),
                    const Divider(color: Colors.white24, height: 32),
                  ],
                  if (events.isNotEmpty) ...events.map((event) => _buildEventCard(event)),
                  if (tasks.isNotEmpty) ...tasks.map((task) => _buildTaskCard(task, taskProvider)),
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
            const Text('No plans for today', style: TextStyle(color: Colors.white54, fontSize: 16)),
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
        color: const Color(0xFF2A2F3F),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)));
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Text(event.timeRange, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
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
        color: const Color(0xFF2A2F3F),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF2ECC71), width: 4)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (value) {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              taskProvider.toggleTaskCompletion(task.id, userProvider.token ?? '');
            },
            activeColor: const Color(0xFF2ECC71),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(task.timeString, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          _buildPriorityBadge(task.priority),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PlanDayModel plan, PlanDayProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3F),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.blue, width: 4)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: plan.isCompleted,
            onChanged: (_) => provider.togglePlanStatus(plan.id),
            activeColor: const Color(0xFF2ECC71),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (plan.description.isNotEmpty)
                  Text(plan.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (plan.voiceNotePath != null)
            const Icon(Icons.mic, color: Colors.blue, size: 16),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high': color = Colors.redAccent; break;
      case 'medium': color = Colors.orangeAccent; break;
      default: color = const Color(0xFF2ECC71);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getEventColor(dynamic event) {
    switch (event.type.toLowerCase()) {
      case 'holiday': return Colors.blueAccent;
      case 'notice': return Colors.orangeAccent;
      default: return Colors.purpleAccent;
    }
  }
}