import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models/entry.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

final logger = Logger();
const platform = MethodChannel('angel_or_devil/debug');
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> showImmediateTestNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'angel_devil_channel',
    'Angel or Devil',
    channelDescription: 'Immediate test notification',
    importance: Importance.max,
    priority: Priority.high,
  );
  final iosDetails = DarwinNotificationDetails(
    categoryIdentifier: 'angelDevilCategory',
  );
  final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  await flutterLocalNotificationsPlugin.show(
    1,
    'Angel Baby (Test)',
    'Immediate test notification',
    details,
    payload: '',
  );
  logger.i('Immediate test notification posted');
}

Future<void> initializeNotifications() async {
  await Permission.notification.request();

  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    notificationCategories: [
      DarwinNotificationCategory(
        'angelDevilCategory',
        actions: [
          DarwinNotificationAction.plain('angel', 'Angel'),
          DarwinNotificationAction.plain('devil', 'Devil'),
        ],
      ),
    ],
  );
  final InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      logger.i("Notification tapped! Payload: ${response.payload}");

      // Wait a brief moment to allow the navigator to initialize, especially on cold start
      await Future.delayed(const Duration(milliseconds: 500));

      if (navigatorKey.currentState != null) {
        // Use pushReplacement to make DailyPromptScreen the current top route.
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => DailyPromptScreen(
              onComplete: () {
                // This callback is executed when DailyPromptScreen signals completion.
                // Navigate to MainTabView, making it the new root of the navigation stack.
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState!.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainTabView()),
                    (Route<dynamic> route) => false, // Removes all previous routes
                  );
                  logger.i("DailyPromptScreen (from notification) completed. Navigated to MainTabView.");
                } else {
                  logger.e("Navigator state was null when trying to navigate from DailyPromptScreen's onComplete (notification context).");
                }
              },
            ),
          ),
        );
        logger.i("Successfully pushed DailyPromptScreen (from notification) with onComplete handler.");
      } else {
        logger.e("Navigator state was null when trying to push from notification. Navigation failed.");
        // Consider a fallback here, e.g., setting a global flag that LaunchDecider can check.
      }
    },
  );
}

Future<void> scheduleDailyAngelDevilNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'angel_devil_channel',
    'Angel or Devil',
    channelDescription: 'Daily prompt to log your day',
    importance: Importance.max,
    priority: Priority.high,
  );
  final iosDetails = DarwinNotificationDetails(
    categoryIdentifier: 'angelDevilCategory',
  );
  final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  final now = DateTime.now();
  final time = DateTime(now.year, now.month, now.day, 19, 0); // 7:00 PM
  // Always schedule for next 7:00 PM
  var scheduledTime = time.isAfter(now) ? time : time.add(const Duration(days: 1));
  final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

  // Robustness: Cancel any existing notification with ID 0 before scheduling a new one.
  await flutterLocalNotificationsPlugin.cancel(0);
  logger.i('Cancelled any existing daily notification with ID 0.');

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0, // Notification ID
    'Angel Baby',
    'Was your baby a little angel or a little devil today?',
    tzScheduledTime,
    details,
    androidScheduleMode: AndroidScheduleMode.inexact,
    matchDateTimeComponents: DateTimeComponents.time, // This makes it repeat daily
    payload: '',
  );
  logger.i('Daily notification scheduled for $tzScheduledTime with ID 0.');
}

// Shared helper for angel/devil text
String getAngelDevilText(bool isAngel, bool isToday) {
  return isToday
      ? isAngel
            ? 'Hoo-ray! What an angel baby you have'
            : 'Ah little devil! Parenting is hard for everyone so don’t be too harsh on yourself. Perhaps tomorrow will be a better day?'
      : isAngel
      ? 'Angel Day'
      : 'Devil Day';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  String localTimeZone = 'UTC';
  try {
    localTimeZone = await FlutterTimezone.getLocalTimezone();
  } catch (e) {
    // fallback to UTC
  }
  tz.setLocalLocation(tz.getLocation(localTimeZone));
  await Hive.initFlutter();
  Hive.registerAdapter(DiaryEntryAdapter());
  await Hive.openBox<DiaryEntry>('entries');
  await initializeNotifications();
  await showImmediateTestNotification();
  await scheduleDailyAngelDevilNotification();
  runApp(const AngelDevilApp());
}

class AngelDevilApp extends StatelessWidget {
  const AngelDevilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angel or Devil',
      navigatorKey: navigatorKey,
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

class _LaunchDeciderState extends State<LaunchDecider> with WidgetsBindingObserver {
  bool? _showPrompt;
  bool _loading = true;
  Widget? _restoredPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _decideInitialScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      logger.i('App resumed. Re-evaluating prompt and re-scheduling daily notification.');
      await _checkPromptOnResume();
      await scheduleDailyAngelDevilNotification();
    }
  }

  Future<void> _decideInitialScreen() async {
    final now = DateTime.now();
    final fivePM = DateTime(now.year, now.month, now.day, 17, 0);
    final box = Hive.box<DiaryEntry>('entries');
    final todayKey = DateTime(now.year, now.month, now.day).toIso8601String();
    final entry = box.get(todayKey);

    Widget restoredPage = const MainTabView();

    if (now.isAfter(fivePM) && entry == null) {
      setState(() {
        _showPrompt = true;
        _loading = false;
        _restoredPage = null;
      });
    } else {
      setState(() {
        _showPrompt = false;
        _loading = false;
        _restoredPage = restoredPage;
      });
    }
  }

  Future<void> _checkPromptOnResume() async {
    final now = DateTime.now();
    final fivePM = DateTime(now.year, now.month, now.day, 17, 0);
    final box = Hive.box<DiaryEntry>('entries');
    final todayKey = DateTime(now.year, now.month, now.day).toIso8601String();
    final entry = box.get(todayKey);
    if (now.isAfter(fivePM) && entry == null) {
      // Only navigate if not already showing prompt
      if (_showPrompt != true) {
        setState(() {
          _showPrompt = true;
          _restoredPage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showPrompt == true) {
      return DailyPromptScreen(
        onComplete: () {
          setState(() {
            _showPrompt = false;
            _restoredPage = const MainTabView();
          });
        },
      );
    }
    return _restoredPage ?? const MainTabView();
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
    final box = Hive.box<DiaryEntry>('entries');
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day).toIso8601String();
    final entry = box.get(todayKey);
    bool? selected = entry?.isAngel; // null if no entry

    return Scaffold(
      appBar: AppBar(
        title: const Text('Angel Baby'),
        backgroundColor: Colors.brown,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Was your baby a little angel or a little devil today?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final newEntry = DiaryEntry(
                        date: DateTime(today.year, today.month, today.day),
                        isAngel: true,
                        note: entry?.note ?? '',
                      );
                      await box.put(todayKey, newEntry);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiaryEntryScreen(isAngel: true, note: newEntry.note),
                        ),
                      ).then((_) {
                        if (onComplete != null) onComplete!();
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected == true ? Colors.yellow[100] : Colors.transparent,
                        border: Border.all(
                          color: selected == true ? Colors.yellow[700]! : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        'assets/angel.svg',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final newEntry = DiaryEntry(
                        date: DateTime(today.year, today.month, today.day),
                        isAngel: false,
                        note: entry?.note ?? '',
                      );
                      await box.put(todayKey, newEntry);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiaryEntryScreen(isAngel: false, note: newEntry.note),
                        ),
                      ).then((_) {
                        if (onComplete != null) onComplete!();
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected == false ? Colors.red[100] : Colors.transparent,
                        border: Border.all(
                          color: selected == false ? Colors.redAccent : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        'assets/devil.svg',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MVP Screen 2: Optional Diary Entry
class DiaryEntryScreen extends StatefulWidget {
  final bool isAngel;
  final String note;
  const DiaryEntryScreen({super.key, required this.isAngel, this.note = ''});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late TextEditingController _controller;

  bool _isAngelSelected = true;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<DiaryEntry>('entries');
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day).toIso8601String();
    final entry = box.get(todayKey);
    _isAngelSelected = entry?.isAngel ?? widget.isAngel;
    _controller = TextEditingController(text: entry?.note ?? widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Entry'),
        backgroundColor: Colors.brown,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAngelSelected = true;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isAngelSelected
                                ? Colors.yellow[100]
                                : Colors.transparent,
                            border: Border.all(
                              color: _isAngelSelected
                                  ? Colors.yellow[700]!
                                  : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: SvgPicture.asset(
                            'assets/angel.svg',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAngelSelected = false;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isAngelSelected
                                ? Colors.red[100]
                                : Colors.transparent,
                            border: Border.all(
                              color: !_isAngelSelected
                                  ? Colors.redAccent
                                  : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: SvgPicture.asset(
                            'assets/devil.svg',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: Text(
                          getAngelDevilText(_isAngelSelected, true),
                          style: const TextStyle(fontSize: 18),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
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
                      // Use _isAngelSelected for saving
                      final box = Hive.box<DiaryEntry>('entries');
                      final today = DateTime.now();
                      final entry = DiaryEntry(
                        date: DateTime(today.year, today.month, today.day),
                        isAngel: _isAngelSelected,
                        note: _controller.text.trim(),
                      );
                      await box.put(entry.date.toIso8601String(), entry);
                      logger.i('Entry saved successfully');
                      logger.i('Attempting navigation to CalendarViewScreen');
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
          ),
        ),
      ),
    );
  }
}

// MVP Screen 3: Monthly Calendar View
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

class _CalendarViewBodyState extends State<_CalendarViewBody> with WidgetsBindingObserver {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      setState(() {
        _displayMonth = DateTime(now.year, now.month);
      });
    }
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Use a smaller icon size and ensure scaling
                        double iconSize = constraints.maxWidth * 0.4;
                        iconSize = iconSize.clamp(16.0, 24.0); // keep icons small
                        return Container(
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
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                  textAlign: TextAlign.center,
                                ),
                                if (entry != null && !isFuture)
                                  SizedBox(
                                    width: iconSize,
                                    height: iconSize,
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: entry.isAngel
                                          ? SvgPicture.asset(
                                              'assets/angel.svg',
                                              width: iconSize,
                                              height: iconSize,
                                            )
                                          : SvgPicture.asset(
                                              'assets/devil.svg',
                                              width: iconSize,
                                              height: iconSize,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAngel = true;
                      _edited = true;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isAngel
                          ? Colors.yellow[100]
                          : Colors.transparent,
                      border: Border.all(
                        color: _isAngel ? Colors.yellow[700]! : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/angel.svg',
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAngel = false;
                      _edited = true;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_isAngel ? Colors.red[100] : Colors.transparent,
                      border: Border.all(
                        color: !_isAngel ? Colors.redAccent : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/devil.svg',
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                getAngelDevilText(_isAngel, isToday),
                softWrap: true,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: isToday
                    ? 'What’s on your mind'
                    : 'What was on your mind',
              ),
            ),
          ],
        ),
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
