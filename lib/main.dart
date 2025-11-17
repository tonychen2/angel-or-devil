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

// Constants
const String kNotificationChannelId = 'angel_devil_channel';
const String kNotificationChannelName = 'Angel or Devil';
const String kIosNotificationCategory = 'angelDevilCategory';
const String kHiveBoxName = 'entries';

class _AppConstants {
  // Colors
  static const Color primaryColor = Color(0xFF8B6F4E);
  static const Color scaffoldBackground = Color(0xFFF8F3E3);
  static const Color appBarForeground = Color(0xFFF8F3E3);
  static const Color unselectedNavItemColor = Color(0xFFBCA18A);

  static const Color defaultIconBorder = Colors.grey;
  static const Color unselectedNewEntryIconBorder = Color(0xFFBDBDBD);

  static const Color angelIconSelectedBg = Color(0xFFFFF9C4);
  static const Color angelIconSelectedBorder = Color(0xFFFBC02D);
  static const Color devilIconSelectedBg = Color(0xFFFFCDD2);
  static const Color devilIconSelectedBorder = Colors.redAccent;

  static const Color calendarAdjacentMonthDayBg = Color(0xFFF3E9D7);
  static const Color calendarTodayCellBg = Color(0xFFEAD7B7);
  static const Color calendarDefaultCellBg = scaffoldBackground; 
  static const Color calendarTodayText = Color(0xFF6E2C00);
  static const Color calendarAdjacentMonthBorder = Color(0xFFBCA18A);
  static const Color calendarDefaultText = primaryColor;

  // Spacing & Sizing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  static const double dialogIconSize = 32.0;
  static const double promptIconSize = 64.0;
  static const double diaryEntryScreenIconSize = 48.0;
  static const double calendarGridIconMinSize = 16.0;
  static const double calendarGridIconMaxSize = 24.0;
  static const double calendarGridIconScaleFactor = 0.4;

  // Numerical Constants
  static const int promptEligibilityHour = 17; // 5 PM
  static const int dailyNotificationHour = 19; // 7 PM
  static const int dailyNotificationId = 0;
  static const int testNotificationId = 1;
  static const int navigatorPushDelayMillis = 500;

  // Text
  static const String appTitle = 'Angel or Devil';
  static const String insightScreenTitle = 'Insights';
  static const String dailyPromptScreenTitle = 'Angel Baby';
  static const String diaryEntryScreenTitle = 'Diary Entry';
  static const String monthlyCalendarScreenTitle = 'Monthly Calendar';

  static const List<String> weekDayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
}

// Helper for DateTime to get date part only, and for consistent Hive keys
extension DateTimeExtension on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
  String get toHiveKey => dateOnly.toIso8601String();
}

final logger = Logger();
const platform = MethodChannel('angel_or_devil/debug'); // Keep as is if used by native side
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeNotifications() async {
  await Permission.notification.request();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Keep as is, specific to Android
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    notificationCategories: [
      DarwinNotificationCategory(
        kIosNotificationCategory,
        actions: [
          DarwinNotificationAction.plain('angel', 'Angel'), // These could be consts too
          DarwinNotificationAction.plain('devil', 'Devil'),
        ],
      ),
    ],
  );
  final InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      logger.i("Notification tapped! Payload: ${response.payload}");

      await Future.delayed(
          const Duration(milliseconds: _AppConstants.navigatorPushDelayMillis));

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DailyPromptScreen(
              onComplete: () {
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState!.pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const MainTabView()),
                    (Route<dynamic> route) => false,
                  );
                  logger.i(
                      "DailyPromptScreen (from notification) completed. Navigated to MainTabView.");
                } else {
                  logger.e(
                      "Navigator state was null when trying to navigate from DailyPromptScreen's onComplete (notification context).");
                }
              },
            ),
          ),
          (Route<dynamic> route) => false,
        );
        logger.i(
            "Successfully pushed DailyPromptScreen (from notification) and removed previous routes.");
      } else {
        logger.e(
            "Navigator state was null when trying to push from notification. Navigation failed.");
      }
    },
  );
}

Future<void> scheduleDailyAngelDevilNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kNotificationChannelId,
    kNotificationChannelName,
    channelDescription: 'Daily prompt to log your day',
    importance: Importance.max,
    priority: Priority.high,
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    categoryIdentifier: kIosNotificationCategory,
  );
  const NotificationDetails details =
      NotificationDetails(android: androidDetails, iOS: iosDetails);

  final now = DateTime.now();
  final time = DateTime(now.year, now.month, now.day, _AppConstants.dailyNotificationHour);
  var scheduledTime = time.isAfter(now) ? time : time.add(const Duration(days: 1));
  final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

  await flutterLocalNotificationsPlugin.cancel(_AppConstants.dailyNotificationId);
  logger.i(
      'Cancelled any existing daily notification with ID ${_AppConstants.dailyNotificationId}.');

  await flutterLocalNotificationsPlugin.zonedSchedule(
    _AppConstants.dailyNotificationId,
    _AppConstants.dailyPromptScreenTitle,
    'Was your baby a little angel or a little devil today?', // This string can be a const too
    tzScheduledTime,
    details,
    androidScheduleMode: AndroidScheduleMode.inexact,
    matchDateTimeComponents: DateTimeComponents.time,
    payload: '',
  );
  logger.i(
      'Daily notification scheduled for $tzScheduledTime with ID ${_AppConstants.dailyNotificationId}.');
}

String getAngelDevilText(bool isAngel, bool isToday) {
  // These strings are good candidates for constants if they are used elsewhere or for localization
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
  String localTimeZone = 'UTC'; // Default timezone
  try {
    localTimeZone = await FlutterTimezone.getLocalTimezone();
  } catch (e) {
    logger.w('Failed to get local timezone: $e. Defaulting to UTC.');
  }
  tz.setLocalLocation(tz.getLocation(localTimeZone));
  await Hive.initFlutter();
  Hive.registerAdapter(DiaryEntryAdapter());
  await Hive.openBox<DiaryEntry>(kHiveBoxName);
  await initializeNotifications();
  await scheduleDailyAngelDevilNotification();
  runApp(const AngelDevilApp());
}

class AngelDevilApp extends StatelessWidget {
  const AngelDevilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _AppConstants.appTitle,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: _AppConstants.scaffoldBackground,
        primaryColor: _AppConstants.primaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _AppConstants.primaryColor,
          foregroundColor: _AppConstants.appBarForeground,
          elevation: 0,
        ),
        textTheme: GoogleFonts.patrickHandTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: _AppConstants.primaryColor, displayColor: _AppConstants.primaryColor)
        ),
        fontFamily: GoogleFonts.patrickHand().fontFamily,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: _AppConstants.primaryColor,
          secondary: _AppConstants.primaryColor, 
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
      logger.i(
          'App resumed. Re-evaluating prompt and re-scheduling daily notification.');
      await _checkPromptOnResume();
      await scheduleDailyAngelDevilNotification();
    }
  }

  Future<void> _decideInitialScreen() async {
    final now = DateTime.now();
    final promptTime = DateTime(now.year, now.month, now.day, _AppConstants.promptEligibilityHour);
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final todayKey = now.toHiveKey;
    final entry = box.get(todayKey);

    Widget restoredPage = const MainTabView();

    if (now.isAfter(promptTime) && entry == null) {
      if(mounted) {
        setState(() {
          _showPrompt = true;
          _loading = false;
          _restoredPage = null;
        });
      }
    } else {
      if(mounted) {
        setState(() {
          _showPrompt = false;
          _loading = false;
          _restoredPage = restoredPage;
        });
      }
    }
  }

  Future<void> _checkPromptOnResume() async {
    final now = DateTime.now();
    final promptTime = DateTime(now.year, now.month, now.day, _AppConstants.promptEligibilityHour);
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final todayKey = now.toHiveKey;
    final entry = box.get(todayKey);
    if (now.isAfter(promptTime) && entry == null) {
      if (_showPrompt != true) {
        if(mounted) {
          setState(() {
            _showPrompt = true;
            _restoredPage = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _AppConstants.primaryColor)));
    }
    if (_showPrompt == true) {
      return DailyPromptScreen(
        onComplete: () {
          if(mounted) {
            setState(() {
              _showPrompt = false;
              _restoredPage = const MainTabView();
            });
          }
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

  // It's good practice to make this static const if the children don't depend on initState or build context.
  static const List<Widget> _widgetOptions = <Widget>[
    CalendarViewScreen(),
    InsightPlaceholderScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
        ],
        selectedItemColor: _AppConstants.primaryColor,
        unselectedItemColor: _AppConstants.unselectedNavItemColor,
        backgroundColor: _AppConstants.scaffoldBackground,
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
        title: const Text(_AppConstants.insightScreenTitle),
        // backgroundColor will be inherited from ThemeData.appBarTheme
      ),
      body: const Center(
        child: Text(
          'Coming soon...', // This could also be a constant
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class DailyPromptScreen extends StatelessWidget {
  final VoidCallback? onComplete;
  const DailyPromptScreen({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final today = DateTime.now().dateOnly;
    final entry = box.get(today.toHiveKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text(_AppConstants.dailyPromptScreenTitle),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_AppConstants.spacingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Was your baby a little angel or a little devil today?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _AppConstants.spacingXLarge),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: _AppConstants.spacingLarge,
                runSpacing: _AppConstants.spacingLarge, // Added for better wrap on small screens
                children: [
                  _buildChoiceButton(context, box, today, entry, true),
                  _buildChoiceButton(context, box, today, entry, false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton(
    BuildContext context,
    Box<DiaryEntry> box,
    DateTime today,
    DiaryEntry? currentEntry,
    bool isAngelChoice,
  ) {
    final String assetPath = isAngelChoice ? 'assets/angel.svg' : 'assets/devil.svg';
    // Check if the current entry's choice matches this button's choice
    final bool isButtonSelected = currentEntry?.isAngel == isAngelChoice;

    return GestureDetector(
      onTap: () async {
        final newEntry = DiaryEntry(
          date: today,
          isAngel: isAngelChoice,
          note: currentEntry?.note ?? '',
        );
        await box.put(today.toHiveKey, newEntry);
        // It's generally better to pass the full date to DiaryEntryScreen if it might be needed
        // but current implementation of DiaryEntryScreen fetches today's entry again.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryEntryScreen(isAngel: isAngelChoice, note: newEntry.note),
          ),
        ).then((_) {
          if (onComplete != null) onComplete!();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isButtonSelected
              ? (isAngelChoice ? _AppConstants.angelIconSelectedBg : _AppConstants.devilIconSelectedBg)
              : Colors.transparent,
          border: Border.all(
            color: isButtonSelected
                ? (isAngelChoice ? _AppConstants.angelIconSelectedBorder : _AppConstants.devilIconSelectedBorder)
                : _AppConstants.defaultIconBorder,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12), // This could be a const (_AppConstants.borderRadiusMedium)
        ),
        padding: const EdgeInsets.all(_AppConstants.spacingSmall),
        child: SvgPicture.asset(
          assetPath,
          width: _AppConstants.promptIconSize,
          height: _AppConstants.promptIconSize,
        ),
      ),
    );
  }
}

class DiaryEntryScreen extends StatefulWidget {
  final bool isAngel; // Initial angel/devil choice from prompt screen
  final String note;  // Initial note from prompt screen
  const DiaryEntryScreen({super.key, required this.isAngel, this.note = ''});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late TextEditingController _controller;
  late bool _isAngelSelected; // Current selection state on this screen

  @override
  void initState() {
    super.initState();
    // Initialize with values passed from DailyPromptScreen
    _isAngelSelected = widget.isAngel;
    _controller = TextEditingController(text: widget.note);

    // Potentially override with persisted data if user navigates back and then to this screen again
    // for the *same day* if the DiaryEntryScreen is somehow kept in stack or re-created for today.
    // However, the current navigation flow from DailyPromptScreen to here, and then to MainTabView,
    // typically means this screen is fresh. But this check adds robustness.
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final todayKey = DateTime.now().toHiveKey;
    final persistedEntryForToday = box.get(todayKey);

    if (persistedEntryForToday != null) {
      _isAngelSelected = persistedEntryForToday.isAngel;
      // Preserve text if user already started typing on this screen, otherwise use persisted note.
      if (_controller.text.isEmpty && persistedEntryForToday.note.isNotEmpty) {
        _controller.text = persistedEntryForToday.note;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_AppConstants.diaryEntryScreenTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(_AppConstants.spacingMedium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // Good for responsiveness
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: _AppConstants.spacingMedium,
                    runSpacing: _AppConstants.spacingSmall,
                    children: [
                      _buildSelectionIcon(true),
                      _buildSelectionIcon(false),
                      SizedBox(
                        width: 180, // Specific width from original design
                        child: Text(
                          getAngelDevilText(_isAngelSelected, true), // This screen is always for 'today'
                          style: const TextStyle(fontSize: 18), // Consider making this const if not themed
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _AppConstants.spacingLarge),
                  const Text('What’s on your mind?'), // Could be a const
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write a few words/sentences... (optional)', // Could be a const
                    ),
                  ),
                  const SizedBox(height: _AppConstants.spacingLarge),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _AppConstants.primaryColor,
                        foregroundColor: _AppConstants.appBarForeground),
                    onPressed: () async {
                      final box = Hive.box<DiaryEntry>(kHiveBoxName);
                      final today = DateTime.now().dateOnly;
                      final entry = DiaryEntry(
                        date: today,
                        isAngel: _isAngelSelected,
                        note: _controller.text.trim(),
                      );
                      await box.put(today.toHiveKey, entry);
                      logger.i('Entry saved successfully from DiaryEntryScreen');
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const MainTabView()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                    child: const Text('Save'), // Could be a const
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionIcon(bool isAngelChoice) {
    final bool isSelected = _isAngelSelected == isAngelChoice;
    return GestureDetector(
      onTap: () {
        if (_isAngelSelected != isAngelChoice) {
            setState(() {
                _isAngelSelected = isAngelChoice;
            });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isAngelChoice ? _AppConstants.angelIconSelectedBg : _AppConstants.devilIconSelectedBg)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? (isAngelChoice ? _AppConstants.angelIconSelectedBorder : _AppConstants.devilIconSelectedBorder)
                : _AppConstants.defaultIconBorder,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12), // Could be _AppConstants.borderRadiusMedium
        ),
        padding: const EdgeInsets.all(_AppConstants.spacingSmall),
        child: SvgPicture.asset(
          isAngelChoice ? 'assets/angel.svg' : 'assets/devil.svg',
          width: _AppConstants.diaryEntryScreenIconSize,
          height: _AppConstants.diaryEntryScreenIconSize,
        ),
      ),
    );
  }
}

class CalendarViewScreen extends StatelessWidget {
  const CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CalendarViewBody(); // Made _CalendarViewBody const
  }
}

class _CalendarViewBody extends StatefulWidget {
  const _CalendarViewBody({super.key}); // Added const constructor

  @override
  State<_CalendarViewBody> createState() => _CalendarViewBodyState();
}

class _CalendarViewBodyState extends State<_CalendarViewBody> with WidgetsBindingObserver {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime.now().dateOnly.copyWith(day: 1);
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
      if (mounted) {
        setState(() {
          // Refresh to current month if app is resumed, useful if it was backgrounded for a long time
          _displayMonth = DateTime.now().dateOnly.copyWith(day: 1);
        });
      }
    }
  }

  void _changeMonth(int offset) {
    if (mounted) {
      setState(() {
        _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + offset, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final today = DateTime.now().dateOnly;

    final firstDayOfDisplayMonth = _displayMonth;
    final daysInDisplayMonth = DateTime(firstDayOfDisplayMonth.year, firstDayOfDisplayMonth.month + 1, 0).day;
    final firstWeekdayOfDisplayMonth = firstDayOfDisplayMonth.weekday % 7; // Sunday is 0 if DateTime.sunday is 7
    final lastDayOfDisplayMonth = DateTime(firstDayOfDisplayMonth.year, firstDayOfDisplayMonth.month, daysInDisplayMonth);
    final lastWeekdayOfDisplayMonth = lastDayOfDisplayMonth.weekday % 7;

    final gridStartDay = firstDayOfDisplayMonth.subtract(Duration(days: firstWeekdayOfDisplayMonth));
    final gridEndDay = lastDayOfDisplayMonth.add(Duration(days: 6 - lastWeekdayOfDisplayMonth));
    final totalDaysInGrid = gridEndDay.difference(gridStartDay).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(_AppConstants.monthlyCalendarScreenTitle),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(_AppConstants.spacingMedium),
        child: Column(
          children: [
            _buildMonthNavigator(),
            const SizedBox(height: _AppConstants.spacingMedium),
            _buildWeekdayLabels(),
            const SizedBox(height: _AppConstants.spacingSmall),
            Expanded(
              child: _buildCalendarGrid(box, today, gridStartDay, totalDaysInGrid),
            ),
            const SizedBox(height: _AppConstants.spacingSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
        Text(
          // Using a more robust way to format month (e.g. via intl package for localization)
          // For now, padLeft is fine.
          '${_displayMonth.year} - ${_displayMonth.month.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _AppConstants.weekDayLabels
          .map((dayLabel) => Expanded(
                child: Center(
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _AppConstants.primaryColor, fontSize: 16),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(Box<DiaryEntry> box, DateTime today, DateTime gridStartDay, int totalDaysInGrid) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1, // Makes cells square
        crossAxisSpacing: _AppConstants.spacingSmall / 2,
        mainAxisSpacing: _AppConstants.spacingSmall / 2,
      ),
      itemCount: totalDaysInGrid,
      itemBuilder: (context, index) {
        final date = gridStartDay.add(Duration(days: index));
        final isCurrentDisplayMonth = date.month == _displayMonth.month;
        final entry = box.get(date.toHiveKey);
        final isToday = date == today;
        final isFutureDate = date.isAfter(today);

        return GestureDetector(
          onTap: isFutureDate
              ? null // Don't allow interaction with future dates
              : () {
                  showDialog(
                    context: context,
                    builder: (context) => _DayDetailDialog(
                      entryDate: date,
                      existingEntry: entry,
                      onSave: (updatedEntry) {
                        box.put(updatedEntry.date.toHiveKey, updatedEntry);
                        Navigator.pop(context); // Close dialog
                        if (mounted) setState(() {}); // Rebuild calendar to show changes
                      },
                    ),
                  );
                },
          child: LayoutBuilder(
            builder: (context, constraints) {
              double iconSize = constraints.maxWidth * _AppConstants.calendarGridIconScaleFactor;
              iconSize = iconSize.clamp(_AppConstants.calendarGridIconMinSize, _AppConstants.calendarGridIconMaxSize);
              return Container(
                decoration: BoxDecoration(
                  color: !isCurrentDisplayMonth
                      ? _AppConstants.calendarAdjacentMonthDayBg
                      : isToday
                          ? _AppConstants.calendarTodayCellBg
                          : _AppConstants.calendarDefaultCellBg,
                  borderRadius: BorderRadius.circular(_AppConstants.spacingSmall),
                  border: Border.all(
                    color: !isCurrentDisplayMonth
                        ? _AppConstants.calendarAdjacentMonthBorder
                        : _AppConstants.primaryColor,
                    width: 2,
                  ),
                ),
                child: Opacity(
                  opacity: isFutureDate ? 0.5 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? _AppConstants.calendarTodayText
                              : !isCurrentDisplayMonth
                                  ? _AppConstants.calendarAdjacentMonthBorder
                                  : _AppConstants.calendarDefaultText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (entry != null && !isFutureDate)
                        SizedBox(
                          width: iconSize,
                          height: iconSize,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SvgPicture.asset(
                              entry.isAngel ? 'assets/angel.svg' : 'assets/devil.svg',
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
    );
  }
}

class _DayDetailDialog extends StatefulWidget {
  final DateTime entryDate;
  final DiaryEntry? existingEntry;
  final void Function(DiaryEntry) onSave;

  const _DayDetailDialog({
    super.key,
    required this.entryDate,
    this.existingEntry,
    required this.onSave,
  });

  @override
  State<_DayDetailDialog> createState() => _DayDetailDialogState();
}

class _DayDetailDialogState extends State<_DayDetailDialog> {
  bool? _currentIsAngel;      // Current selection in the dialog
  late TextEditingController _controller;
  
  // Initial state when dialog opens, to compare for edits
  bool? _initialIsAngel;
  String _initialNote = '';
  
  bool _isEdited = false; // Tracks if any change has been made

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _initialIsAngel = widget.existingEntry!.isAngel;
      _initialNote = widget.existingEntry!.note;
    } else {
      // This is a new entry for a previously unlogged day
      _initialIsAngel = null;
      _initialNote = '';
    }
    // Initialize current working state from initial state
    _currentIsAngel = _initialIsAngel;
    _controller = TextEditingController(text: _initialNote);
    _controller.addListener(_handleEditState);
  }

  void _handleEditState() {
    bool hasSelectionChanged = _currentIsAngel != _initialIsAngel;
    bool hasNoteChanged = _controller.text != _initialNote;
    // An edit occurs if selection or note changes. 
    // For a new entry, just making a selection is an edit.
    bool newEditedState = (hasSelectionChanged || hasNoteChanged) && (_currentIsAngel != null);
    
    if (_initialIsAngel == null && _currentIsAngel != null && !hasNoteChanged) {
      // Special case: New entry, first icon click, no note change yet
      newEditedState = true;
    }

    if (_isEdited != newEditedState) {
      setState(() {
        _isEdited = newEditedState;
      });
    }
  }

  void _handleIconTap(bool newSelection) {
    if (_currentIsAngel != newSelection) {
      setState(() {
        _currentIsAngel = newSelection;
        _handleEditState();
      });
    } else {
      // If it's a new entry (initial was null), tapping the same icon again de-selects it.
      if (_initialIsAngel == null) {
         setState(() {
            _currentIsAngel = null;
            _handleEditState();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleEditState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.entryDate == DateTime.now().dateOnly;

    return AlertDialog(
      title: Text(
        // Consider using DateFormat for more robust/localized date formatting
        '${widget.entryDate.month.toString().padLeft(2, '0')}/${widget.entryDate.day.toString().padLeft(2, '0')}/${widget.entryDate.year}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: _AppConstants.scaffoldBackground,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDialogIcon(true), // Angel
                const SizedBox(width: _AppConstants.spacingMedium),
                _buildDialogIcon(false), // Devil
              ],
            ),
            const SizedBox(height: _AppConstants.spacingSmall),
            // Show text only if a selection is made, provide a placeholder for height otherwise
            _currentIsAngel != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _AppConstants.spacingSmall),
                    child: Text(
                      getAngelDevilText(_currentIsAngel!, isToday),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox(height: 18), // Approx height of one line of text
            const SizedBox(height: _AppConstants.spacingSmall),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: isToday ? 'What’s on your mind?' : 'What was on your mind?', // Could be consts
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _AppConstants.primaryColor)),
        ),
        TextButton(
          onPressed: _isEdited && _currentIsAngel != null // Save only if edited and a choice is made
              ? () {
                  final updatedEntry = DiaryEntry(
                    date: widget.entryDate,
                    isAngel: _currentIsAngel!, // Safe because _currentIsAngel != null is checked
                    note: _controller.text.trim(),
                  );
                  widget.onSave(updatedEntry);
                }
              : null,
          child: Text('Save', style: TextStyle(color: (_isEdited && _currentIsAngel != null) ? _AppConstants.primaryColor : _AppConstants.defaultIconBorder)),
        ),
      ],
    );
  }

  Widget _buildDialogIcon(bool isAngelChoice) {
    bool isSelected = _currentIsAngel == isAngelChoice;
    Color borderColor = _AppConstants.defaultIconBorder;
    if (isSelected) {
      borderColor = isAngelChoice ? _AppConstants.angelIconSelectedBorder : _AppConstants.devilIconSelectedBorder;
    } else if (_currentIsAngel == null && _initialIsAngel == null) {
      // For a new entry, unselected icons have a lighter border
      borderColor = _AppConstants.unselectedNewEntryIconBorder;
    }

    return GestureDetector(
      onTap: () => _handleIconTap(isAngelChoice),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isAngelChoice ? _AppConstants.angelIconSelectedBg : _AppConstants.devilIconSelectedBg)
              : Colors.transparent, // No background if not selected
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12), // Could be an _AppConstants value
        ),
        padding: const EdgeInsets.all(_AppConstants.spacingSmall),
        child: SvgPicture.asset(
          isAngelChoice ? 'assets/angel.svg' : 'assets/devil.svg',
          width: _AppConstants.dialogIconSize,
          height: _AppConstants.dialogIconSize,
        ),
      ),
    );
  }
}
