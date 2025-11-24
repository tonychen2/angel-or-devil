import 'dart:async';
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
  static const int dayCycleStartHour = 13; // 1 PM - cycle starts
  static const int nightCycleStartHour = 1; // 1 AM - cycle starts
  static const int dayNotificationHour = 7; // 7 AM - notification time
  static const int nightNotificationHour = 19; // 7 PM - notification time
  static const int dayNotificationId = 0;
  static const int nightNotificationId = 1;
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
  
  // Get Hive key for day/night entry
  // Night entries (7pm-7am) are stored with the date of the evening (e.g., night of Nov 4 = Nov 4)
  String toHiveKeyForCycle(bool isDay) {
    if (isDay) {
      return dateOnly.toIso8601String() + '_day';
    } else {
      // For night cycle, use the date of the evening (7pm is part of that day)
      return dateOnly.toIso8601String() + '_night';
    }
  }
}

// Helper functions for day/night cycles
// Day cycle: 1PM to 1AM (next day) - logs about the day
// Night cycle: 1AM to 1PM - logs about last night
bool isCurrentlyDayCycle() {
  final now = DateTime.now();
  final hour = now.hour;
  // Day cycle is from 1PM (13) to 1AM (1) next day
  // This means hour >= 13 OR hour < 1
  return hour >= _AppConstants.dayCycleStartHour || hour < _AppConstants.nightCycleStartHour;
}

bool isCurrentlyNightCycle() {
  return !isCurrentlyDayCycle();
}

// Get the date for the entry being logged in the current cycle
// During day cycle (1PM-1AM): logging about today's day, so return today's date
// During night cycle (1AM-1PM): logging about last night, so return yesterday's date
DateTime getCurrentCycleDate() {
  final now = DateTime.now();
  if (isCurrentlyDayCycle()) {
    // Day cycle: logging about today's day, so use today
    return now.dateOnly;
  } else {
    // Night cycle: logging about last night, so use yesterday
    return now.subtract(const Duration(days: 1)).dateOnly;
  }
}

// Get whether we're logging a day or night entry in the current cycle
// During day cycle (1PM-1AM): logging about today's day, so isDay = true
// During night cycle (1AM-1PM): logging about last night, so isDay = false
bool getCurrentCycleIsDay() {
  return isCurrentlyDayCycle(); // Day cycle logs day entries, night cycle logs night entries
}

// Get the date for a night cycle entry
// Night of Nov 4 (1am Nov 5 - 1pm Nov 4) should be stored as Nov 4
// This function is kept for potential future use but may not be needed with new cycle logic
DateTime getNightCycleDate(DateTime dateTime) {
  final hour = dateTime.hour;
  // If it's before 1PM, the night belongs to the previous day (for entries logged in morning)
  if (hour < _AppConstants.dayCycleStartHour) {
    return dateTime.subtract(const Duration(days: 1)).dateOnly;
  }
  // Otherwise, it's the same day
  return dateTime.dateOnly;
}

final logger = Logger();
const platform = MethodChannel('angel_or_devil/debug'); // Keep as is if used by native side
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeNotifications() async {
  try {
    // Check iOS notification settings using the plugin's method
    final bool? iosPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    
    if (iosPermissionGranted != null) {
      logger.i('iOS notification permission granted: $iosPermissionGranted');
    }
    
    // Also check Android permissions
    final bool? androidPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    if (androidPermissionGranted != null) {
      logger.i('Android notification permission granted: $androidPermissionGranted');
    }
    
    // Fallback to permission_handler for additional checks
    final status = await Permission.notification.status;
    logger.i('Notification permission status (permission_handler): $status');
  } catch (e) {
    logger.e('Failed to request notification permission: $e');
  }

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

Future<void> scheduleDailyAngelDevilNotifications() async {
  // Check permission using the plugin's method (more reliable)
  bool hasPermission = false;
  
  try {
    // Check iOS
    final iosImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final bool? iosPermission = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      hasPermission = iosPermission ?? false;
      logger.i('iOS notification permission check: $hasPermission');
    }
    
    // Check Android
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final bool? androidPermission = await androidImplementation
          .requestNotificationsPermission();
      hasPermission = androidPermission ?? false;
      logger.i('Android notification permission check: $hasPermission');
    }
    
    // Fallback check
    if (!hasPermission) {
      final permissionStatus = await Permission.notification.status;
      logger.i('Fallback permission check: $permissionStatus');
      hasPermission = permissionStatus.isGranted;
    }
  } catch (e) {
    logger.e('Error checking notification permission: $e');
  }
  
  if (!hasPermission) {
    logger.w('Notification permission not granted. Notifications will not be scheduled.');
    return;
  }
  
  logger.i('Notification permission confirmed. Proceeding to schedule notifications.');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kNotificationChannelId,
    kNotificationChannelName,
    channelDescription: 'Daily prompt to log your day',
    importance: Importance.max,
    priority: Priority.high,
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    categoryIdentifier: kIosNotificationCategory,
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const NotificationDetails details =
      NotificationDetails(android: androidDetails, iOS: iosDetails);

  // Use timezone-aware current time
  final now = tz.TZDateTime.now(tz.local);
  
  // Cancel all existing notifications (cancel a range of IDs to cover 10 days)
  // Day notifications: IDs 0-9, Night notifications: IDs 10-19
  for (int i = 0; i < 20; i++) {
    await flutterLocalNotificationsPlugin.cancel(i);
  }

  // Schedule notifications for the next 10 days
  const int daysToSchedule = 10;
  int dayNotificationsScheduled = 0;
  int nightNotificationsScheduled = 0;

  for (int dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
    // Calculate target date by adding days to current date
    final targetDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: dayOffset));
    
    // Schedule day notification (7 AM) - prompts about last night
    final dayTime = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      _AppConstants.dayNotificationHour,
    );
    
    // Only schedule if the time is in the future
    if (dayTime.isAfter(now)) {
      final dayNotificationId = dayOffset; // Use 0-9 for day notifications
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          dayNotificationId,
          _AppConstants.dailyPromptScreenTitle,
          'Morning! Was your baby a little angel or a little devil last night?',
          dayTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'day',
        );
        dayNotificationsScheduled++;
      } catch (e) {
        logger.e('Failed to schedule day notification for $dayTime: $e');
      }
    }

    // Schedule night notification (7 PM) - prompts about today
    final nightTime = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      _AppConstants.nightNotificationHour,
    );
    
    // Only schedule if the time is in the future
    if (nightTime.isAfter(now)) {
      final nightNotificationId = 10 + dayOffset; // Use 10-19 for night notifications
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          nightNotificationId,
          _AppConstants.dailyPromptScreenTitle,
          'Was your baby a little angel or a little devil today?',
          nightTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'night',
        );
        nightNotificationsScheduled++;
      } catch (e) {
        logger.e('Failed to schedule night notification for $nightTime: $e');
      }
    }
  }

  logger.i('Scheduled $dayNotificationsScheduled day notifications and $nightNotificationsScheduled night notifications for the next $daysToSchedule days.');
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
  // Set up error handlers before anything else
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e('FlutterError: ${details.exception}');
    logger.e('Stack: ${details.stack}');
  };
  
  // Use runZonedGuarded to catch any unhandled async errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize timezones with error handling
    try {
      tzdata.initializeTimeZones();
      String localTimeZone = 'UTC'; // Default timezone
      try {
        localTimeZone = await FlutterTimezone.getLocalTimezone();
      } catch (e) {
        logger.w('Failed to get local timezone: $e. Defaulting to UTC.');
      }
      try {
        tz.setLocalLocation(tz.getLocation(localTimeZone));
      } catch (e) {
        logger.w('Failed to set timezone location: $e. Using UTC.');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      logger.e('Error initializing timezones: $e');
      // Continue even if timezone initialization fails
    }
    
    // Initialize Hive with better error handling
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(DiaryEntryAdapter());
      await Hive.openBox<DiaryEntry>(kHiveBoxName);
    } catch (e, stackTrace) {
      logger.e('Error initializing Hive: $e');
      logger.e('Stack trace: $stackTrace');
      // Don't rethrow - try to continue anyway
      // The app will handle missing Hive box gracefully in _decideInitialScreen
    }
    
    // Start the app immediately - don't wait for anything
    runApp(const AngelDevilApp());
    
    // Initialize notifications asynchronously AFTER app starts
    // This is critical on iOS where permission dialogs can block startup
    // Using a small delay to ensure app is fully started
    Future.delayed(const Duration(milliseconds: 500), () {
      initializeNotifications().then((_) {
        // Schedule notifications after initialization completes
        scheduleDailyAngelDevilNotifications().catchError((e) {
          logger.e('Error scheduling notifications: $e');
        });
      }).catchError((e) {
        logger.e('Error initializing notifications: $e');
        // Notifications are not critical for app startup
      });
    });
  }, (error, stackTrace) {
    // Catch any unhandled errors
    logger.e('Unhandled error in main: $error');
    logger.e('Stack trace: $stackTrace');
    // Try to run the app anyway
    try {
      runApp(const AngelDevilApp());
    } catch (e) {
      // If even runApp fails, at least log it
      logger.e('Failed to run app: $e');
    }
  });
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
    // Use a small delay to ensure Hive is fully initialized
    Future.microtask(() => _decideInitialScreen());
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
      await scheduleDailyAngelDevilNotifications();
    }
  }

  Future<void> _decideInitialScreen() async {
    try {
      // Wait for Hive box to be ready with a timeout
      int retries = 0;
      const maxRetries = 10;
      while (!Hive.isBoxOpen(kHiveBoxName) && retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
      
      // Ensure Hive box is open before accessing it
      if (!Hive.isBoxOpen(kHiveBoxName)) {
        try {
          await Hive.openBox<DiaryEntry>(kHiveBoxName);
        } catch (e) {
          logger.e('Failed to open Hive box: $e');
          // If we can't open the box, show main view anyway
          if(mounted) {
            setState(() {
              _showPrompt = false;
              _loading = false;
              _restoredPage = const MainTabView();
            });
          }
          return;
        }
      }
      
      final box = Hive.box<DiaryEntry>(kHiveBoxName);
      final isDay = getCurrentCycleIsDay(); // Entry type we're logging
      final cycleDate = getCurrentCycleDate(); // Date for the entry
      final cycleKey = cycleDate.toHiveKeyForCycle(isDay);
      final entry = box.get(cycleKey);

      Widget restoredPage = const MainTabView();

      // Show prompt if no entry exists for current cycle
      if (entry == null) {
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
    } catch (e) {
      logger.e('Error in _decideInitialScreen: $e');
      // Always set loading to false, even on error, to prevent stuck loading screen
      if(mounted) {
        setState(() {
          _showPrompt = false;
          _loading = false;
          _restoredPage = const MainTabView();
        });
      }
    }
  }

  Future<void> _checkPromptOnResume() async {
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    // Always check the CURRENT cycle when app resumes
    // Cycle boundaries:
    // - Day cycle (1PM-1AM): checks for day entry
    // - Night cycle (1AM-1PM): checks for night entry (last night)
    // Don't show prompts for past cycles that were missed
    final isDay = getCurrentCycleIsDay(); // Entry type we're logging for current cycle
    final cycleDate = getCurrentCycleDate(); // Date for the current cycle entry
    final cycleKey = cycleDate.toHiveKeyForCycle(isDay);
    final entry = box.get(cycleKey);
    
    // Show prompt if no entry exists for CURRENT cycle
    // This ensures we always prompt for the current cycle, not past ones
    // Example: If it's after 1PM and last night wasn't logged, we check for today's day entry instead
    // Use setState to update the UI, which keeps LaunchDecider in the widget tree
    // and preserves the lifecycle observer
    if (entry == null) {
      if(mounted) {
        setState(() {
          _showPrompt = true;
          _restoredPage = null;
        });
        logger.i(
            "App resumed with no entry for current cycle. Showing DailyPromptScreen.");
      }
    } else {
      // If entry exists for current cycle, hide prompt
      if (_showPrompt == true && mounted) {
        setState(() {
          _showPrompt = false;
          _restoredPage = const MainTabView();
        });
        logger.i(
            "App resumed with entry for current cycle. Showing MainTabView.");
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
    final isDay = getCurrentCycleIsDay(); // This is the entry type we're logging
    final cycleDate = getCurrentCycleDate(); // This is the date for the entry
    final cycleKey = cycleDate.toHiveKeyForCycle(isDay);
    final entry = box.get(cycleKey);
    
    // Show different text based on current cycle
    // Day cycle (1PM-1AM): logging about today's day
    // Night cycle (1AM-1PM): logging about last night
    final isCurrentlyDay = isCurrentlyDayCycle();
    final promptText = isCurrentlyDay 
        ? 'Was your baby a little angel or a little devil today?'
        : 'Morning! Was your baby a little angel or a little devil last night?';

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
              Text(
                promptText,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _AppConstants.spacingXLarge),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: _AppConstants.spacingLarge,
                runSpacing: _AppConstants.spacingLarge,
                children: [
                  _buildChoiceButton(context, box, cycleDate, isDay, entry, true),
                  _buildChoiceButton(context, box, cycleDate, isDay, entry, false),
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
    DateTime cycleDate,
    bool isDay,
    DiaryEntry? currentEntry,
    bool isAngelChoice,
  ) {
    final String assetPath = isAngelChoice ? 'assets/angel.svg' : 'assets/devil.svg';
    // Check if the current entry's choice matches this button's choice
    final bool isButtonSelected = currentEntry?.isAngel == isAngelChoice;

    return GestureDetector(
      onTap: () async {
        final newEntry = DiaryEntry(
          date: cycleDate,
          isAngel: isAngelChoice,
          note: currentEntry?.note ?? '',
          isDay: isDay,
        );
        final cycleKey = cycleDate.toHiveKeyForCycle(isDay);
        await box.put(cycleKey, newEntry);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiaryEntryScreen(
              isAngel: isAngelChoice,
              note: newEntry.note,
              isDay: isDay,
              entryDate: cycleDate,
            ),
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
          borderRadius: BorderRadius.circular(12),
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
  final bool isDay;   // Whether this is a day or night entry
  final DateTime entryDate; // Date for this entry
  const DiaryEntryScreen({
    super.key,
    required this.isAngel,
    this.note = '',
    required this.isDay,
    required this.entryDate,
  });

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
    final box = Hive.box<DiaryEntry>(kHiveBoxName);
    final cycleKey = widget.entryDate.toHiveKeyForCycle(widget.isDay);
    final persistedEntry = box.get(cycleKey);

    if (persistedEntry != null) {
      _isAngelSelected = persistedEntry.isAngel;
      // Preserve text if user already started typing on this screen, otherwise use persisted note.
      if (_controller.text.isEmpty && persistedEntry.note.isNotEmpty) {
        _controller.text = persistedEntry.note;
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
                      final cycleKey = widget.entryDate.toHiveKeyForCycle(widget.isDay);
                      final entry = DiaryEntry(
                        date: widget.entryDate,
                        isAngel: _isAngelSelected,
                        note: _controller.text.trim(),
                        isDay: widget.isDay,
                      );
                      await box.put(cycleKey, entry);
                      logger.i('Entry saved successfully from DiaryEntryScreen');
                      if (mounted) {
                        // Pop back to DailyPromptScreen, which will then call onComplete
                        // to navigate back to LaunchDecider showing MainTabView
                        Navigator.of(context).pop();
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
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
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
          final now = DateTime.now();
          _displayMonth = DateTime(now.year, now.month, 1);
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

    // Use UTC to avoid DST issues when calculating dates
    final firstDayOfDisplayMonth = DateTime.utc(_displayMonth.year, _displayMonth.month, 1);
    final daysInDisplayMonth = DateTime.utc(firstDayOfDisplayMonth.year, firstDayOfDisplayMonth.month + 1, 0).day;
    // DateTime.weekday: Monday=1, Tuesday=2, ..., Sunday=7
    // Convert to: Sunday=0, Monday=1, ..., Saturday=6
    final firstWeekdayOfDisplayMonth = firstDayOfDisplayMonth.weekday % 7;
    final lastDayOfDisplayMonth = DateTime.utc(firstDayOfDisplayMonth.year, firstDayOfDisplayMonth.month, daysInDisplayMonth);
    final lastWeekdayOfDisplayMonth = lastDayOfDisplayMonth.weekday % 7;

    // Calculate grid start/end using date arithmetic to avoid DST issues
    // Subtract days by going back in the month
    final daysToSubtract = firstWeekdayOfDisplayMonth;
    final gridStartDay = DateTime.utc(
      firstDayOfDisplayMonth.year,
      firstDayOfDisplayMonth.month,
      1 - daysToSubtract,
    );
    // Add days by going forward in the month
    final daysToAdd = 6 - lastWeekdayOfDisplayMonth;
    final gridEndDay = DateTime.utc(
      lastDayOfDisplayMonth.year,
      lastDayOfDisplayMonth.month,
      lastDayOfDisplayMonth.day + daysToAdd,
    );
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
        // Calculate date using year/month/day arithmetic to avoid DST issues
        final date = DateTime.utc(
          gridStartDay.year,
          gridStartDay.month,
          gridStartDay.day + index,
        ).dateOnly;
        final isCurrentDisplayMonth = date.month == _displayMonth.month;
        
        // Get both day and night entries for this date
        final dayEntry = box.get(date.toHiveKeyForCycle(true));
        final nightEntry = box.get(date.toHiveKeyForCycle(false));
        final hasDayEntry = dayEntry != null;
        final hasNightEntry = nightEntry != null;
        
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
                      dayEntry: dayEntry,
                      nightEntry: nightEntry,
                      onSave: (updatedEntry) {
                        final cycleKey = updatedEntry.date.toHiveKeyForCycle(updatedEntry.isDay);
                        box.put(cycleKey, updatedEntry);
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
                      if (!isFutureDate && (hasDayEntry || hasNightEntry))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasDayEntry)
                              SizedBox(
                                width: iconSize * 0.8,
                                height: iconSize * 0.8,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SvgPicture.asset(
                                    dayEntry!.isAngel ? 'assets/angel.svg' : 'assets/devil.svg',
                                    width: iconSize * 0.8,
                                    height: iconSize * 0.8,
                                  ),
                                ),
                              ),
                            if (hasDayEntry && hasNightEntry)
                              SizedBox(width: iconSize * 0.2),
                            if (hasNightEntry)
                              SizedBox(
                                width: iconSize * 0.8,
                                height: iconSize * 0.8,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SvgPicture.asset(
                                    nightEntry!.isAngel ? 'assets/angel.svg' : 'assets/devil.svg',
                                    width: iconSize * 0.8,
                                    height: iconSize * 0.8,
                                  ),
                                ),
                              ),
                          ],
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
  final DiaryEntry? dayEntry;
  final DiaryEntry? nightEntry;
  final void Function(DiaryEntry) onSave;

  const _DayDetailDialog({
    super.key,
    required this.entryDate,
    this.dayEntry,
    this.nightEntry,
    required this.onSave,
  });

  @override
  State<_DayDetailDialog> createState() => _DayDetailDialogState();
}

class _DayDetailDialogState extends State<_DayDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool? _dayIsAngel;
  bool? _nightIsAngel;
  late TextEditingController _dayController;
  late TextEditingController _nightController;
  
  // Initial states for comparison
  bool? _initialDayIsAngel;
  bool? _initialNightIsAngel;
  String _initialDayNote = '';
  String _initialNightNote = '';
  
  bool _dayIsEdited = false;
  bool _nightIsEdited = false;

  @override
  void initState() {
    super.initState();
    // Default to Day tab for today, Night tab for yesterday, Day tab for other dates
    final today = DateTime.now().dateOnly;
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = widget.entryDate == today;
    final isYesterday = widget.entryDate == yesterday;
    final initialIndex = isToday ? 0 : (isYesterday ? 1 : 0); // 0 = Day, 1 = Night
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    
    // Initialize day entry state
    if (widget.dayEntry != null) {
      _initialDayIsAngel = widget.dayEntry!.isAngel;
      _initialDayNote = widget.dayEntry!.note;
      _dayIsAngel = _initialDayIsAngel;
    } else {
      _initialDayIsAngel = null;
      _initialDayNote = '';
      _dayIsAngel = null;
    }
    _dayController = TextEditingController(text: _initialDayNote);
    _dayController.addListener(() => _handleEditState(true));
    
    // Initialize night entry state
    if (widget.nightEntry != null) {
      _initialNightIsAngel = widget.nightEntry!.isAngel;
      _initialNightNote = widget.nightEntry!.note;
      _nightIsAngel = _initialNightIsAngel;
    } else {
      _initialNightIsAngel = null;
      _initialNightNote = '';
      _nightIsAngel = null;
    }
    _nightController = TextEditingController(text: _initialNightNote);
    _nightController.addListener(() => _handleEditState(false));
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _dayController.dispose();
    _nightController.dispose();
    super.dispose();
  }

  void _handleEditState(bool isDay) {
    if (isDay) {
      bool hasSelectionChanged = _dayIsAngel != _initialDayIsAngel;
      bool hasNoteChanged = _dayController.text != _initialDayNote;
      bool newEditedState = (hasSelectionChanged || hasNoteChanged) && (_dayIsAngel != null);
      
      if (_initialDayIsAngel == null && _dayIsAngel != null && !hasNoteChanged) {
        newEditedState = true;
      }

      if (_dayIsEdited != newEditedState) {
        setState(() {
          _dayIsEdited = newEditedState;
        });
      }
    } else {
      bool hasSelectionChanged = _nightIsAngel != _initialNightIsAngel;
      bool hasNoteChanged = _nightController.text != _initialNightNote;
      bool newEditedState = (hasSelectionChanged || hasNoteChanged) && (_nightIsAngel != null);
      
      if (_initialNightIsAngel == null && _nightIsAngel != null && !hasNoteChanged) {
        newEditedState = true;
      }

      if (_nightIsEdited != newEditedState) {
        setState(() {
          _nightIsEdited = newEditedState;
        });
      }
    }
  }

  void _handleIconTap(bool isDay, bool newSelection) {
    if (isDay) {
      if (_dayIsAngel != newSelection) {
        setState(() {
          _dayIsAngel = newSelection;
          _handleEditState(true);
        });
      } else {
        if (_initialDayIsAngel == null) {
          setState(() {
            _dayIsAngel = null;
            _handleEditState(true);
          });
        }
      }
    } else {
      if (_nightIsAngel != newSelection) {
        setState(() {
          _nightIsAngel = newSelection;
          _handleEditState(false);
        });
      } else {
        if (_initialNightIsAngel == null) {
          setState(() {
            _nightIsAngel = null;
            _handleEditState(false);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.entryDate == DateTime.now().dateOnly;

    return AlertDialog(
      title: Column(
        children: [
          Text(
            '${widget.entryDate.month.toString().padLeft(2, '0')}/${widget.entryDate.day.toString().padLeft(2, '0')}/${widget.entryDate.year}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TabBar(
            controller: _tabController,
            labelColor: _AppConstants.primaryColor,
            unselectedLabelColor: _AppConstants.unselectedNavItemColor,
            tabs: const [
              Tab(text: 'Day'),
              Tab(text: 'Night'),
            ],
          ),
        ],
      ),
      backgroundColor: _AppConstants.scaffoldBackground,
      content: SizedBox(
        width: double.maxFinite,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(true, isToday),
            _buildTabContent(false, isToday),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _AppConstants.primaryColor)),
        ),
        TextButton(
          onPressed: (_dayIsEdited && _dayIsAngel != null) || (_nightIsEdited && _nightIsAngel != null)
              ? () {
                  // Save day entry if edited
                  if (_dayIsEdited && _dayIsAngel != null) {
                    final dayEntry = DiaryEntry(
                      date: widget.entryDate,
                      isAngel: _dayIsAngel!,
                      note: _dayController.text.trim(),
                      isDay: true,
                    );
                    widget.onSave(dayEntry);
                  }
                  // Save night entry if edited
                  if (_nightIsEdited && _nightIsAngel != null) {
                    final nightEntry = DiaryEntry(
                      date: widget.entryDate,
                      isAngel: _nightIsAngel!,
                      note: _nightController.text.trim(),
                      isDay: false,
                    );
                    widget.onSave(nightEntry);
                  }
                  // Close dialog after all saves are complete
                  Navigator.pop(context);
                }
              : null,
          child: Text(
            'Save',
            style: TextStyle(
              color: ((_dayIsEdited && _dayIsAngel != null) || (_nightIsEdited && _nightIsAngel != null))
                  ? _AppConstants.primaryColor
                  : _AppConstants.defaultIconBorder,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(bool isDay, bool isToday) {
    final isAngel = isDay ? _dayIsAngel : _nightIsAngel;
    final controller = isDay ? _dayController : _nightController;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDialogIcon(isDay, true), // Angel
              const SizedBox(width: _AppConstants.spacingMedium),
              _buildDialogIcon(isDay, false), // Devil
            ],
          ),
          const SizedBox(height: _AppConstants.spacingSmall),
          isAngel != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _AppConstants.spacingSmall),
                  child: Text(
                    getAngelDevilText(isAngel, isToday),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox(height: 18),
          const SizedBox(height: _AppConstants.spacingSmall),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: isToday ? "What's on your mind?" : "What was on your mind?",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogIcon(bool isDay, bool isAngelChoice) {
    final currentIsAngel = isDay ? _dayIsAngel : _nightIsAngel;
    final initialIsAngel = isDay ? _initialDayIsAngel : _initialNightIsAngel;
    
    bool isSelected = currentIsAngel == isAngelChoice;
    Color borderColor = _AppConstants.defaultIconBorder;
    if (isSelected) {
      borderColor = isAngelChoice ? _AppConstants.angelIconSelectedBorder : _AppConstants.devilIconSelectedBorder;
    } else if (currentIsAngel == null && initialIsAngel == null) {
      borderColor = _AppConstants.unselectedNewEntryIconBorder;
    }

    return GestureDetector(
      onTap: () => _handleIconTap(isDay, isAngelChoice),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isAngelChoice ? _AppConstants.angelIconSelectedBg : _AppConstants.devilIconSelectedBg)
              : Colors.transparent,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
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
