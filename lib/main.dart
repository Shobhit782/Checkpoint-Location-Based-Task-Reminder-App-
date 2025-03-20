import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones(); // Initialize time zones

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleNotification(String title, DateTime scheduledTime) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      title, // Notification Title
      "Reminder is due!", // Notification Body
      tz.TZDateTime.from(scheduledTime, tz.local), // Convert DateTime to TZDateTime
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel_id',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init(); // Ensure init() is called properly
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.deepPurple,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final List<Map<String, dynamic>> _reminders = [];

  void _addReminder(String title, String location, DateTime deadline, String taskType) {
    setState(() {
      _reminders.add({
        'title': title,
        'location': location,
        'deadline': deadline,
        'taskType': taskType,
      });
    });
    NotificationService().scheduleNotification(title, deadline);
  }

  void _removeReminder(int index) {
    setState(() {
      _reminders.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Smaller Calendar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.deepPurple),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.deepPurple),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(color: Colors.deepPurple[300]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedList(
              key: UniqueKey(), // Force rebuild on state change
              initialItemCount: _reminders.length,
              itemBuilder: (context, index, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: ReminderCard(
                    title: _reminders[index]['title'],
                    date: _reminders[index]['deadline'],
                    taskType: _reminders[index]['taskType'],
                    onDelete: () => _removeReminder(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddReminderScreen(onAdd: _addReminder),
                ),
              ).then((_) => setState(() {})), // Refresh the list after adding a reminder
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Add Reminder', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final String title;
  final DateTime date;
  final String taskType;
  final VoidCallback onDelete;

  const ReminderCard({
    Key? key,
    required this.title,
    required this.date,
    required this.taskType,
    required this.onDelete,
  }) : super(key: key);

  // Define colors for each task type
  Color _getTaskTypeColor(String taskType) {
    switch (taskType.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.green;
      case 'shopping':
        return Colors.orange;
      case 'health':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.notifications_active, color: Colors.deepPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd HH:mm').format(date)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: _getTaskTypeColor(taskType).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                taskType,
                style: TextStyle(
                  color: _getTaskTypeColor(taskType),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class AddReminderScreen extends StatefulWidget {
  final Function(String, String, DateTime, String) onAdd;

  const AddReminderScreen({Key? key, required this.onAdd}) : super(key: key);

  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDateTime;
  String _taskType = "Unknown";
  bool _isLoading = false;

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _predictTaskType(String task) async {
    if (task.isEmpty) {
      setState(() {
        _taskType = "Unknown";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("http://10.12.78.147:5000/predict"), // Update with backend IP if needed
        headers: {"Content-Type": "application/json"},
        body: json.encode({"task": task}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _taskType = data["category"];
        });
      } else {
        setState(() {
          _taskType = "Error: Unable to predict";
        });
      }
    } catch (e) {
      setState(() {
        _taskType = "Error: Server not reachable";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (value) => _predictTaskType(value),
            ),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickDateTime,
              child: Text(_selectedDateTime == null ? 'Pick Date & Time' : 'Selected: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!)}'),
            ),
            const SizedBox(height: 10),
            _isLoading ? CircularProgressIndicator() : Text("Task Type: $_taskType", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_selectedDateTime != null) {
                  widget.onAdd(_titleController.text, _locationController.text, _selectedDateTime!, _taskType);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}