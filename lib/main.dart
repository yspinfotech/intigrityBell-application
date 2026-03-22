import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;

// Providers
import 'providers/user_provider.dart';
import 'providers/task_provider.dart';
import 'providers/event_provider.dart';
import 'providers/note_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/plan_day_provider.dart';
import 'providers/category_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_screen.dart';
import 'screens/add_event_screen.dart';
import 'screens/event_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/note_list_screen.dart';
import 'screens/add_note_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/plan_day_screen.dart';
import 'screens/stats_dashboard_screen.dart';
import 'package:alarm/alarm.dart';
import 'screens/alarm_ring_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Alarm Package (Step 1)
  await Alarm.init();
  debugPrint('⏰ Alarm system initialized');
  
  // Initialize timezone database for local notifications
  // This is required for zonedSchedule() to work correctly
  tz.initializeTimeZones();
  debugPrint('✅ Timezone database initialized');
  
  // Initialize Notification Service
  // This must be done before runApp() to ensure notifications work
  final notificationService = NotificationService();
  notificationService.navigatorKey = navigatorKey; 
  try {
    await notificationService.initialize();
    debugPrint('✅ Notification Service initialized');
  } catch (e) {
    debugPrint('⚠️ Notification Service initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PlanDayProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'INTIGrity-Bell',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2ECC71),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2ECC71),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF1A1E2B),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => SplashScreen(),
              '/login': (context) => LoginScreen(),
              '/home': (context) => MainDashboardScreen(),
              '/calendar': (context) => HomeScreen(),
              '/notifications': (context) => NotificationsScreen(),
              '/user-profile': (context) => UserProfileScreen(),
              '/add-event': (context) => AddEventScreen(),
              '/events': (context) => EventScreen(),
              '/notes': (context) => NoteListScreen(),
              '/add-note': (context) => AddNoteScreen(),
              '/tasks': (context) => TaskScreen(),
              '/plan': (context) => TaskScreen(),
              '/plan-my-day': (context) => PlanDayScreen(),
              '/plan-day': (context) => PlanDayScreen(),
              '/stats-dashboard': (context) => StatsDashboardScreen(),
              '/alarm-ring': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return AlarmRingScreen(
                  id: args?['id'] ?? 0,
                  title: args?['title'] ?? 'Alarm',
                  soundUri: args?['soundUri'] ?? 'default',
                );
              },
            },
          );
        },
      ),
    );
  }
}