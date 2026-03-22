import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1E2B),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1E2B),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('User Profile', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.currentUser;

          if (user == null) {
            return Center(
              child: Text('No user logged in', style: TextStyle(color: Colors.white)),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // User Info
                Text(
                  user.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 30),
                // Settings Section
                _SettingsTile(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Manage notification settings',
                  trailing: Switch(
                    value: user.notificationsEnabled,
                    onChanged: (value) {
                      userProvider.updateNotificationSettings(value);
                    },
                    activeColor: Color(0xFF2ECC71),
                  ),
                ),
                // SizedBox(height: 12),
                // _SettingsTile(
                //   icon: Icons.dark_mode,
                //   title: 'Dark Mode',
                //   subtitle: 'Toggle dark theme',
                //   trailing: Switch(
                //     value: user.darkModeEnabled,
                //     onChanged: (value) {
                //       userProvider.updateDarkMode(value);
                //       final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                //       themeProvider.setDarkMode(value);
                //     },
                //     activeColor: Color(0xFF2ECC71),
                //   ),
                // ),
                SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.person,
                  title: 'Account',
                  subtitle: 'Edit account details',
                  onTap: () {},
                ),
                SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.help,
                  title: 'Help',
                  subtitle: 'Get help and support',
                  onTap: () {},
                ),
                SizedBox(height: 30),
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      userProvider.logoutUser();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF2A2F3F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF2ECC71), size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
    );
  }
}
