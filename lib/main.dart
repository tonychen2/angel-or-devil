import 'package:flutter/material.dart';
import 'models/entry.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(DiaryEntryAdapter());
  await Hive.openBox<DiaryEntry>('entries');
  runApp(const AngelDevilApp());
}

class AngelDevilApp extends StatelessWidget {
  const AngelDevilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angel Baby',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
        fontFamily: 'Nunito',
      ),
      home: const DailyPromptScreen(),
    );
  }
}

// MVP Screen 1: Daily Prompt
class DailyPromptScreen extends StatelessWidget {
  const DailyPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angel Baby'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Was your baby a little angel or a little devil today?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.emoji_emotions,
                    color: Colors.yellow[700],
                    size: 48,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryEntryScreen(isAngel: true),
                      ),
                    );
                  },
                  tooltip: 'Angel',
                ),
                const SizedBox(width: 48),
                IconButton(
                  icon: Icon(Icons.mood_bad, color: Colors.redAccent, size: 48),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryEntryScreen(isAngel: false),
                      ),
                    );
                  },
                  tooltip: 'Devil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// MVP Screen 2: Optional Diary Entry
class DiaryEntryScreen extends StatefulWidget {
  final bool isAngel;
  const DiaryEntryScreen({super.key, required this.isAngel});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _saveEntry() async {
    print('Save button pressed');
    try {
      final box = Hive.box<DiaryEntry>('entries');
      final today = DateTime.now();
      final entry = DiaryEntry(
        date: DateTime(today.year, today.month, today.day),
        isAngel: widget.isAngel,
        note: _controller.text.trim(),
      );
      await box.put(entry.date.toIso8601String(), entry);
      print('Entry saved successfully');
    } catch (e) {
      print('Error saving entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Entry'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.isAngel
                    ? Icon(
                        Icons.emoji_emotions,
                        color: Colors.yellow[700],
                        size: 48,
                      )
                    : Icon(Icons.mood_bad, color: Colors.redAccent, size: 48),
                const SizedBox(width: 16),
                Text(
                  widget.isAngel ? 'Angel Day' : 'Devil Day',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('What’s on your mind?'),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Write a few sentences... (optional)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _saveEntry();
                print('Attempting navigation to CalendarViewScreen');
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalendarViewScreen(),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// MVP Screen 3: Monthly Calendar View (placeholder)
class CalendarViewScreen extends StatelessWidget {
  const CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CalendarViewBody();
  }
}

class _CalendarViewBody extends StatefulWidget {
  @override
  State<_CalendarViewBody> createState() => _CalendarViewBodyState();
}

class _CalendarViewBodyState extends State<_CalendarViewBody> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<DiaryEntry>('entries');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final entries = box.values
        .where(
          (entry) =>
              entry.date.year == _displayMonth.year &&
              entry.date.month == _displayMonth.month,
        )
        .toList();
    Map<int, DiaryEntry> dayToEntry = {
      for (var entry in entries) entry.date.day: entry,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Calendar'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_displayMonth.year} - ${_displayMonth.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: daysInMonth + firstDayOfMonth.weekday - 1,
                itemBuilder: (context, index) {
                  if (index < firstDayOfMonth.weekday - 1) {
                    return const SizedBox();
                  }
                  final day = index - (firstDayOfMonth.weekday - 2);
                  final date = DateTime(
                    _displayMonth.year,
                    _displayMonth.month,
                    day,
                  );
                  final entry = dayToEntry[day];
                  final isToday = date == today;
                  final isFuture = date.isAfter(today);
                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (context) => _DayDetailDialog(
                                day: day,
                                entry:
                                    entry ??
                                    DiaryEntry(
                                      date: date,
                                      isAngel: true,
                                      note: '',
                                    ),
                                onSave: (updatedEntry) {
                                  final box = Hive.box<DiaryEntry>('entries');
                                  box.put(
                                    updatedEntry.date.toIso8601String(),
                                    updatedEntry,
                                  );
                                  Navigator.pop(context);
                                  setState(() {}); // Refresh calendar
                                },
                              ),
                            );
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.blue[100]
                            : entry != null
                            ? Colors.pink[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.pinkAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isToday ? Colors.blue : null,
                            ),
                          ),
                          if (entry != null)
                            entry.isAngel
                                ? Icon(
                                    Icons.emoji_emotions,
                                    color: Colors.yellow[700],
                                    size: 24,
                                  )
                                : Icon(
                                    Icons.mood_bad,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DayDetailDialog extends StatefulWidget {
  final int day;
  final DiaryEntry entry;
  final void Function(DiaryEntry) onSave;
  const _DayDetailDialog({
    required this.day,
    required this.entry,
    required this.onSave,
  });

  @override
  State<_DayDetailDialog> createState() => _DayDetailDialogState();
}

class _DayDetailDialogState extends State<_DayDetailDialog> {
  late bool _isAngel;
  late TextEditingController _controller;
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _isAngel = widget.entry.isAngel;
    _controller = TextEditingController(text: widget.entry.note);
    _controller.addListener(() {
      setState(() {
        _edited =
            _isAngel != widget.entry.isAngel ||
            _controller.text != widget.entry.note;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Day ${widget.day}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.emoji_emotions,
                  color: Colors.yellow[700],
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _isAngel = true;
                    _edited = true;
                  });
                },
                color: _isAngel ? Colors.yellow[700] : Colors.grey,
              ),
              IconButton(
                icon: Icon(Icons.mood_bad, color: Colors.redAccent, size: 32),
                onPressed: () {
                  setState(() {
                    _isAngel = false;
                    _edited = true;
                  });
                },
                color: !_isAngel ? Colors.redAccent : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(_isAngel ? 'Angel Day' : 'Devil Day'),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Write a few sentences... (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _edited
              ? () {
                  final updatedEntry = DiaryEntry(
                    date: widget.entry.date,
                    isAngel: _isAngel,
                    note: _controller.text.trim(),
                  );
                  widget.onSave(updatedEntry);
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
