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
      backgroundColor: Color(0xFF1A1E2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
             color: Color(0xFF1A1E2B),
        ),
        elevation: 0,
        automaticallyImplyLeading: false, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.account_circle_outlined, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pushNamed(context, '/user-profile'),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? 'Guest',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.role.toUpperCase() ?? 'TEAM',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            Image.asset(
              'assets/images/logo.png',
              height: 78,
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
        backgroundColor: Color(0xFF2A2F3F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Color(0xFFFFFFFF).withOpacity(0.4),
            width: 1,
          ),
        ),
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Color(0xFFFFFFFF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction_rounded,
                color: Color(0xFFFFFFFF),
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Feature coming soon!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
          color: Color(0xFF2A2F3F),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
            highlightColor: Color(0xFF4CAF50).withOpacity(0.05),
            splashColor: Color(0xFF4CAF50).withOpacity(0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtitle != null && !comingSoon) ...[
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (comingSoon) ...
                [
                  SizedBox(height: 5),
                  Text(
                    'Coming Soon!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
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
