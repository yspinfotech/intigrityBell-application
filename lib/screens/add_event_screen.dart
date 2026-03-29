import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';

class AddEventScreen extends StatefulWidget {
  final Event? existingEvent;
  const AddEventScreen({super.key, this.existingEvent});

  @override
  _AddEventScreenState createState() => _AddEventScreenState();
}


class _AddEventScreenState extends State<AddEventScreen> {
  static const platform = MethodChannel('com.example.intigrity/ringtone');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
  bool _isRepeating = false;
  List<int> _selectedRepeatDays = [];
  List<int> _selectedReminders = []; // Changed to List
  String _selectedSound = 'default';

  final List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!.title;
      _descriptionController.text = widget.existingEvent!.description;
      _selectedDate = widget.existingEvent!.date;
      _startTime = widget.existingEvent!.startTime ?? TimeOfDay.now();
      _endTime = widget.existingEvent!.endTime ?? TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
      _isRepeating = widget.existingEvent!.isRepeating;
      _selectedRepeatDays = List<int>.from(widget.existingEvent!.repeatDays);
      _selectedReminders = List<int>.from(widget.existingEvent!.reminders);
      _selectedSound = widget.existingEvent!.sound;
    }
  }

  void _toggleReminder(int minutes) {
    setState(() {
      if (_selectedReminders.contains(minutes)) {
        _selectedReminders.remove(minutes);
      } else {
        _selectedReminders.add(minutes);
      }
    });
  }

  String _getReminderLabel(int minutes) {
    if (minutes == 0) return 'At time of event';
    if (minutes < 60) return '$minutes mins before';
    return '${minutes ~/ 60} hour before';
  }

  void _toggleRepeatDay(int day) {
    setState(() {
      if (_selectedRepeatDays.contains(day)) {
        _selectedRepeatDays.remove(day);
      } else {
        _selectedRepeatDays.add(day);
      }
      if (_selectedRepeatDays.isNotEmpty) {
        _isRepeating = true;
      }
    });
  }

  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(String sound) async {
    try {
      if (sound.startsWith('content://')) {
        await _previewPlayer.play(UrlSource(sound));
      } else {
        // Just play alarm.mp3 for preview since we only have one real asset currently
        await _previewPlayer.play(AssetSource('alarm.mp3'));
      }
      // Stop preview after 3 seconds
      Future.delayed(Duration(seconds: 3), () => _previewPlayer.stop());
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  Future<void> _showSoundPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Alarm Sound', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _buildSoundOption(
                icon: Icons.notifications_active,
                title: 'Digital Alarm (Default)',
                value: 'default',
                onTap: () {
                  setState(() => _selectedSound = 'default');
                  _playPreview('default');
                  Navigator.pop(context);
                },
              ),
              _buildSoundOption(
                icon: Icons.alarm,
                title: 'Gentle Wakeup',
                value: 'alarm2',
                onTap: () {
                  setState(() => _selectedSound = 'alarm2');
                  _playPreview('alarm2');
                  Navigator.pop(context);
                },
              ),
              Divider(color: Colors.grey.withOpacity(0.2)),
              _buildSoundOption(
                icon: Icons.phonelink_setup,
                title: 'Device System Ringtone...',
                value: 'picker',
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final String? uri = await platform.invokeMethod('pickRingtone', {'existingUri': _selectedSound});
                    if (uri != null) {
                      setState(() => _selectedSound = uri);
                      _playPreview(uri);
                    }
                  } catch (e) {
                    debugPrint('Error picking ringtone: $e');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundOption({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    final isSelected = _selectedSound == value || (_selectedSound.startsWith('content://') && value == 'picker');
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: onTap,
    );
  }

  void _saveEvent() {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    final event = Event(
      id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      description: _descriptionController.text,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      type: 'local',
      category: 'General',
      reminders: _selectedReminders,
      sound: _selectedSound,
      isRepeating: _isRepeating,
      repeatDays: _selectedRepeatDays,
      notificationId: widget.existingEvent?.notificationId ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toInt(),
    );

    if (widget.existingEvent != null) {
      Provider.of<EventProvider>(context, listen: false).updateEvent(event);
    } else {
      Provider.of<EventProvider>(context, listen: false).addEvent(event);
    }
    
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.existingEvent != null ? 'Event updated' : 'Event saved'),
        backgroundColor: Colors.green
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Event', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              Text('Title', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Event title',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              SizedBox(height: 20),
              // Description Field
              Text('Description', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Event description',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              SizedBox(height: 20),
              // Date Picker
              Text('Date', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: today,
                    lastDate: today.add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Time Range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Time', style: Theme.of(context).textTheme.bodyMedium),
                        SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) setState(() => _startTime = picked);
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Text(
                              _startTime.format(context),
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Time', style: Theme.of(context).textTheme.bodyMedium),
                        SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _endTime,
                            );
                            if (picked != null) setState(() => _endTime = picked);
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Text(
                              _endTime.format(context),
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Reminder Selection (Multi-select)
              Text('Reminders', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0, 5, 10, 15, 30, 60].map((minutes) {
                  final isSelected = _selectedReminders.contains(minutes);
                  return FilterChip(
                    label: Text(_getReminderLabel(minutes)),
                    selected: isSelected,
                    onSelected: (_) => _toggleReminder(minutes),
                    backgroundColor: Theme.of(context).cardColor,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor.withOpacity(0.8),
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              // Sound Selection
              Text('Alarm Sound', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _showSoundPicker,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.music_note, color: Theme.of(context).primaryColor, size: 20),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSound.startsWith('content://') 
                                    ? 'System: Ringtone' 
                                    : _selectedSound == 'alarm2' ? 'Digital: Gentle' : 'Digital: Classic',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                              ),
                              Text(
                                _selectedSound.startsWith('content://') ? 'Selected from device' : 'In-app sound asset',
                                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Repeat Toggle & Days
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Repeat Alarm', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                      Switch(
                        value: _isRepeating,
                        onChanged: (value) {
                          setState(() {
                            _isRepeating = value;
                            if (value && _selectedRepeatDays.isEmpty) {
                              // Default to current day
                              _selectedRepeatDays.add(_selectedDate.weekday);
                            } else if (!value) {
                              _selectedRepeatDays.clear();
                            }
                          });
                        },
                        activeColor: Color(0xFF2ECC71),
                      ),
                    ],
                  ),
                  if (_isRepeating) ...[
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final day = index + 1; // 1=Mon, 7=Sun
                        final isSelected = _selectedRepeatDays.contains(day);
                        return GestureDetector(
                          onTap: () => _toggleRepeatDay(day),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _weekDays[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 30),
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Event',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
