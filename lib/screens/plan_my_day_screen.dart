import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../models/task_model.dart';

class PlanMyDayScreen extends StatefulWidget {
  const PlanMyDayScreen({super.key});

  @override
  _PlanMyDayScreenState createState() => _PlanMyDayScreenState();
}

class _PlanMyDayScreenState extends State<PlanMyDayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.token != null) {
        context.read<TaskProvider>().fetchTasks(userProvider.token!, currentUserId: userProvider.currentUser?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1E2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E2B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Plan My Day', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-event'),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final todaysTasks = taskProvider.getTodaysTasks();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auto Plan button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Auto Plan My Day'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Timeline
                if (todaysTasks.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today, 
                            color: Colors.grey[600], size: 48),
                          const SizedBox(height: 12),
                          Text('No tasks scheduled for today',
                            style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(
                      todaysTasks.length,
                      (index) {
                        final task = todaysTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2F3F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (value) {
                                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                                    taskProvider.toggleTaskCompletion(task.id, userProvider.token ?? '');
                                  },
                                  fillColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFF2ECC71);
                                    }
                                    return Colors.transparent;
                                  }),
                                  side: const BorderSide(
                                    color: Color(0xFF2ECC71),
                                    width: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                          decoration: task.isCompleted 
                                            ? TextDecoration.lineThrough 
                                            : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        task.timeString,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(task.priority),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.priority,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
