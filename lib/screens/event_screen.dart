import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/user_provider.dart';
import '../models/event_model.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.token != null) {
        context.read<EventProvider>().fetchSystemEvents(userProvider.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'System Noticeboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          final events = eventProvider.systemEvents;

          if (eventProvider.isLoading && events.isEmpty) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          }

          if (events.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                final userProvider = context.read<UserProvider>();
                await eventProvider.fetchSystemEvents(userProvider.token ?? '');
              },
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 64, color: textColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No active notices', style: TextStyle(color: textColor.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final userProvider = context.read<UserProvider>();
              await eventProvider.fetchSystemEvents(userProvider.token ?? '');
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventCard(context, event, isDarkMode);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, bool isDarkMode) {
    Color typeColor;
    IconData typeIcon;

    switch (event.type) {
      case 'holiday':
        typeColor = Colors.orangeAccent;
        typeIcon = Icons.celebration_rounded;
        break;
      case 'leave':
        typeColor = Colors.blueAccent;
        typeIcon = Icons.exit_to_app_rounded;
        break;
      case 'notice':
      default:
        typeColor = Theme.of(context).primaryColor;
        typeIcon = Icons.info_outline_rounded;
        break;
    }

    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      Text(
                        event.type.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  event.dateString,
                  style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.description,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (event.createdBy != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: textColor.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    'Posted by: ${event.createdBy}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
