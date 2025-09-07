import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models/entry.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      title: 'Angel or Devil',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F3E3),
        primaryColor: const Color(0xFF8B6F4E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B6F4E),
          foregroundColor: Color(0xFFF8F3E3),
          elevation: 0,
        ),
        textTheme: GoogleFonts.patrickHandTextTheme(),
        fontFamily: GoogleFonts.patrickHand().fontFamily,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF8B6F4E),
          secondary: const Color(0xFF8B6F4E),
        ),
      ),
      home: const LaunchDecider(),
    );
  }
}

class LaunchDecider extends StatefulWidget {
  const LaunchDecider({super.key});

  @override
  State<LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<LaunchDecider> {
  bool? _firstLaunch;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seenPrompt = prefs.getBool('seenPrompt') ?? false;
    setState(() {
      _firstLaunch = !seenPrompt;
    });
    if (!seenPrompt) {
      await prefs.setBool('seenPrompt', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLaunch == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _firstLaunch!
        ? DailyPromptScreen(
            onComplete: () {
              setState(() {
                _firstLaunch = false;
              });
            },
          )
        : const MainTabView();
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [CalendarViewScreen(), InsightPlaceholderScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Insight',
          ),
        ],
        selectedItemColor: Color(0xFF8B6F4E),
        unselectedItemColor: Color(0xFFBCA18A),
        backgroundColor: Color(0xFFF8F3E3),
      ),
    );
  }
}

class InsightPlaceholderScreen extends StatelessWidget {
  const InsightPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insight'),
        backgroundColor: const Color(0xFF8B6F4E),
      ),
      body: const Center(
        child: Text(
          'Coming soon...',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// MVP Screen 1: Daily Prompt
class DailyPromptScreen extends StatelessWidget {
  final VoidCallback? onComplete;
  const DailyPromptScreen({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angel Baby'),
        backgroundColor: Colors.brown,
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
                  icon: SvgPicture.asset(
                    'assets/angel.svg',
                    width: 64,
                    height: 64,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryEntryScreen(isAngel: true),
                      ),
                    ).then((_) {
                      if (onComplete != null) onComplete!();
                    });
                  },
                  tooltip: 'Angel',
                ),
                const SizedBox(width: 48),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/devil.svg',
                    width: 64,
                    height: 64,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryEntryScreen(isAngel: false),
                      ),
                    ).then((_) {
                      if (onComplete != null) onComplete!();
                    });
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
        backgroundColor: Colors.brown,
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
                    ? SvgPicture.asset(
                        'assets/angel.svg',
                        width: 48,
                        height: 48,
                      )
                    : SvgPicture.asset(
                        'assets/devil.svg',
                        width: 48,
                        height: 48,
                      ),
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
                hintText: 'Write a few words/sentences... (optional)',
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

    // Calculate calendar grid range for full weeks
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday=0
    final lastDayOfMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month,
      daysInMonth,
    );
    final lastWeekday = lastDayOfMonth.weekday % 7;
    final gridStart = firstDayOfMonth.subtract(Duration(days: firstWeekday));
    final gridEnd = lastDayOfMonth.add(Duration(days: 6 - lastWeekday));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Calendar'),
        backgroundColor: const Color(0xFF8B6F4E),
        automaticallyImplyLeading: false,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDays
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B6F4E),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: totalDays,
                itemBuilder: (context, index) {
                  final date = gridStart.add(Duration(days: index));
                  final isCurrentMonth = date.month == _displayMonth.month;
                  final day = date.day;
                  // Get entry for any date, not just current month
                  final entry = box.get(date.toIso8601String());
                  final isToday = date == today;
                  final isFuture = date.isAfter(today);
                  return GestureDetector(
                    onTap: isFuture || !isCurrentMonth
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
                                  setState(() {});
                                },
                              ),
                            );
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isFuture || !isCurrentMonth
                            ? const Color(0xFFF3E9D7)
                            : isToday
                            ? const Color(0xFFEAD7B7)
                            : (entry != null
                                  ? const Color(0xFFF8F3E3)
                                  : const Color(0xFFF8F3E3)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFuture || !isCurrentMonth
                              ? const Color(0xFFBCA18A)
                              : const Color(0xFF8B6F4E),
                          width: 2,
                        ),
                      ),
                      child: Opacity(
                        opacity: isFuture ? 0.5 : 1.0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? const Color(0xFF6E2C00)
                                    : isFuture || !isCurrentMonth
                                    ? const Color(0xFFBCA18A)
                                    : null,
                              ),
                            ),
                            if (entry != null && !isFuture)
                              entry.isAngel
                                  ? SvgPicture.asset(
                                      'assets/angel.svg',
                                      width: 40,
                                      height: 40,
                                    )
                                  : SvgPicture.asset(
                                      'assets/devil.svg',
                                      width: 40,
                                      height: 40,
                                    ),
                          ],
                        ),
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
    final today = DateTime.now();
    final isToday =
        widget.entry.date.year == today.year &&
        widget.entry.date.month == today.month &&
        widget.entry.date.day == today.day;
    return AlertDialog(
      title: Text(
        // Show full date instead of just day number
        '${widget.entry.date.month.toString().padLeft(2, '0')}/${widget.entry.date.day.toString().padLeft(2, '0')}/${widget.entry.date.year}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: SvgPicture.asset(
                  'assets/angel.svg',
                  width: 32,
                  height: 32,
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
                icon: SvgPicture.asset(
                  'assets/devil.svg',
                  width: 32,
                  height: 32,
                ),
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
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: isToday
                  ? 'What’s on your mind (optional)'
                  : 'What was on your mind (optional)',
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
