import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to home or login after 3 seconds
    Timer(Duration(seconds: 3), () async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Attempt auto-login with timeout to avoid hang
      try {
        await userProvider.tryAutoLogin().timeout(Duration(seconds: 4));
      } catch (e) {
        print('Auto-login failed or timed out: $e');
      }

      if (userProvider.isLoggedIn && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time
                  // Text(
                  //   '9:41',
                  //   style: TextStyle(
                  //     color: Colors.white,
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.w500,
                  //   ),
                  // ),
                  // Empty container for balance (or you can add settings icon later)
                  SizedBox(width: 40),
                ],
              ),
            ),

            // Main content - centered vertically
            Expanded(
              child: Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  builder: (context, double value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom footer text
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Text(
                'Developed by YSP Infotech Pvt.Ltd.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
