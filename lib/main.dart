import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;

// Providers
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
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
import 'screens/alarm_ring_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
            title: 'Integrity Bell',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              primaryColor: const Color(0xFFE53935),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFE53935),
                secondary: Color(0xFF1A237E),
                surface: Colors.white,
                background: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1A237E),
                elevation: 0,
                iconTheme: IconThemeData(color: Color(0xFFE53935)),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFF1A237E)),
                bodyMedium: TextStyle(color: Color(0xFF1A237E)),
                titleLarge: TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: const IconThemeData(
                color: Color(0xFFE53935),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 4,
              ),
              snackBarTheme: const SnackBarThemeData(
                backgroundColor: Colors.white,
                contentTextStyle: TextStyle(color: Color(0xFF1A237E)),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE53935)),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              primaryColor: const Color(0xFFE53935),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFE53935),
                secondary: Color(0xFF1A237E),
                surface: Colors.white,
                background: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1A237E),
                elevation: 0,
                iconTheme: IconThemeData(color: Color(0xFFE53935)),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFF1A237E)),
                bodyMedium: TextStyle(color: Color(0xFF1A237E)),
                titleLarge: TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: const IconThemeData(
                color: Color(0xFFE53935),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 4,
              ),
              snackBarTheme: const SnackBarThemeData(
                backgroundColor: Colors.white,
                contentTextStyle: TextStyle(color: Color(0xFF1A237E)),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE53935)),
                ),
              ),
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