import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class MainDashboardScreen extends StatelessWidget {
  MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final isManager = userProvider.isManager;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
             color: Theme.of(context).scaffoldBackgroundColor,
        ),
        elevation: 0,
        automaticallyImplyLeading: false, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.account_circle_outlined, color: Theme.of(context).textTheme.bodyLarge?.color, size: 28),
                  onPressed: () => Navigator.pushNamed(context, '/user-profile'),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? 'Guest',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      user?.role.toUpperCase() ?? 'TEAM',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        fontSize: 10, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Image.asset(
              'assets/images/logo.png',
              height: 60,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1.0,
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  children: [
                    _buildDashboardCard(
                      context,
                      title: 'Calendar',
                      icon: Icons.calendar_today_rounded,
                      subtitle: 'Local planning',
                      onTap: () => Navigator.pushNamed(context, '/calendar'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Task',
                      icon: Icons.check_circle_outline,
                      subtitle: isManager ? 'Assign & Track' : 'My Tasks',
                      onTap: () => Navigator.pushNamed(context, '/tasks'),
                    ),
                    _buildDashboardCard(
                      context,
                      title:'Event',
                      icon: Icons.campaign_rounded,
                      subtitle: 'System Notices',
                      onTap: () => Navigator.pushNamed(context, '/events'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Note',
                      icon: Icons.edit_note_rounded,
                      subtitle: 'Personal & AI',
                      onTap: () => Navigator.pushNamed(context, '/notes'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'Report',
                      icon: Icons.insert_chart_outlined_rounded,
                      comingSoon: true,
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'App',
                      icon: Icons.grid_view_rounded,
                      comingSoon: true,
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Feature coming soon!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? subtitle,
    bool comingSoon = false,
  }) {
    final card = Opacity(
      opacity: comingSoon ? 0.75 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
            splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, letterSpacing: 0.5),
                ),
                if (subtitle != null && !comingSoon) ...[
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
                if (comingSoon) ...
                [
                  SizedBox(height: 5),
                  Text(
                    'Coming Soon!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return card;
  }
}
