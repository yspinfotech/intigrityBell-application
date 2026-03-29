import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';

class CalendarDrawer extends StatelessWidget {
  const CalendarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    final filters = eventProvider.filters;

    return Drawer(
      backgroundColor: const Color(0xFF1A1E2B),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                   Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Integrity Bell',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.campaign_outlined, color: Colors.orangeAccent),
              title: const Text('System Noticeboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('View all company notices', style: TextStyle(color: Colors.white54, fontSize: 10)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushNamed(context, '/events');
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text('Calendar Settings', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(
    BuildContext context,
    String title,
    String type,
    Color color,
    bool isSelected,
    EventProvider provider,
  ) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => provider.toggleFilter(type),
        activeColor: color,
        checkColor: Colors.white,
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontSize: 16,
        ),
      ),
      onTap: () => provider.toggleFilter(type),
    );
  }
}
