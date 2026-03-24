import 'package:flutter/material.dart';
import '../models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../services/notification_service.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  Event? _selectedEvent;
  final NotificationService _notificationService = NotificationService();
  static const String _localEventsKey = 'local_events';
  static const String _filtersKey = 'calendar_filters';

  Map<String, bool> _filters = {
    'holiday': true,
    'notice': true,
    'task': true,
    'local': true,
  };

  EventProvider() {
    _loadLocalEvents();
    _loadFilters();
  }

  List<Event> get events => _events;
  Map<String, bool> get filters => _filters;
  bool get isLoading => _isLoading;
  Event? get selectedEvent => _selectedEvent;

  List<Event> get systemEvents => _events.where((e) => e.type != 'local').toList();
  List<Event> get localEvents => _events.where((e) => e.type == 'local').toList();

  List<Event> get filteredEvents {
    return _events.where((e) => _filters[e.type.toLowerCase()] ?? true).toList();
  }

  Future<void> _loadLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString(_localEventsKey);
    if (localData != null) {
      final List<dynamic> jsonList = jsonDecode(localData);
      final List<Event> loadedLocal = jsonList.map((e) => Event.fromJson(e)).toList();
      _events.addAll(loadedLocal);
      notifyListeners();
    }
  }

  Future<void> _saveLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final localOnly = localEvents;
    final String encoded = jsonEncode(localOnly.map((e) => e.toJson()).toList());
    await prefs.setString(_localEventsKey, encoded);
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? filterData = prefs.getString(_filtersKey);
    if (filterData != null) {
      _filters = Map<String, bool>.from(jsonDecode(filterData));
      notifyListeners();
    }
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filtersKey, jsonEncode(_filters));
  }

  void toggleFilter(String type) {
    if (_filters.containsKey(type)) {
      _filters[type] = !(_filters[type]!);
      _saveFilters();
      notifyListeners();
    }
  }

  Future<void> fetchSystemEvents(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/events', token: token);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedEvents = data.map((item) => Event.fromJson(item)).toList();
        
        // Cancel old system notifications before removal
        for (var e in _events) {
          if (e.type != 'local') {
            _notificationService.cancelEventNotifications(e);
          }
        }
        
        // Merge systems events with local ones
        _events.removeWhere((e) => e.type != 'local');
        _events.addAll(fetchedEvents);
        
        // Schedule notifications for new system events
        for (var event in fetchedEvents) {
          _notificationService.scheduleEventNotification(event);
        }
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addEvent(Event event) {
    // Ensure local event has a notification ID if not provided
    Event finalEvent = event;
    if (event.notificationId == null) {
      finalEvent = Event(
        id: event.id,
        title: event.title,
        description: event.description,
        date: event.date,
        startTime: event.startTime,
        endTime: event.endTime,
        type: event.type,
        createdBy: event.createdBy,
        category: event.category,
        reminders: event.reminders,
        sound: event.sound,
        isRepeating: event.isRepeating,
        repeatDays: event.repeatDays,
        notificationId: (DateTime.now().millisecondsSinceEpoch ~/ 1000).toSigned(31).toInt(),
      );
    }
    
    _events.add(finalEvent);
    if (finalEvent.type == 'local') _saveLocalEvents();
    _notificationService.scheduleEventNotification(finalEvent);
    notifyListeners();
  }

  void updateEvent(Event event) {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      final oldEvent = _events[index];
      // FIX 6: Cancel old alarm before update
      _notificationService.cancelEventNotifications(oldEvent);
      _events[index] = event;
      if (event.type == 'local') _saveLocalEvents();
      _notificationService.scheduleEventNotification(event);
      notifyListeners();
    }
  }

  void deleteEvent(String eventId) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final eventToDelete = _events[index];
      _notificationService.cancelEventNotifications(eventToDelete);
      _events.removeAt(index);
      if (eventToDelete.type == 'local') _saveLocalEvents();
      notifyListeners();
    }
  }

  void selectEvent(Event event) {
    _selectedEvent = event;
    notifyListeners();
  }

  void clearSelectedEvent() {
    _selectedEvent = null;
    notifyListeners();
  }

  List<Event> getEventsByDate(DateTime date) {
    return filteredEvents.where((e) => 
      e.date.year == date.year &&
      e.date.month == date.month &&
      e.date.day == date.day
    ).toList();
  }

  List<Event> getTodaysEvents() {
    final today = DateTime.now();
    return getEventsByDate(today);
  }
}
