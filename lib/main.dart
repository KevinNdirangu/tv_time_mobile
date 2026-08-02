import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';
import 'screens/show_details_screen.dart';
import 'theme/app_theme.dart';
import 'services/widget_service.dart';
import 'package:home_widget/home_widget.dart';

import 'services/notification_service.dart';
import 'services/background_task_service.dart';
import 'package:permission_handler/permission_handler.dart';

final themeRebuildProvider = StateProvider<int>((ref) => 0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gnwzertrmjerymlzzfuh.supabase.co'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3plcnRybWplcnltbHp6ZnVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODU5MTIsImV4cCI6MjEwMDY2MTkxMn0.4Y8p6Um7qH8OUS6pAVpQDPxJ9d_wguqVKjnDiWESEZs'),
  );

  await AppTheme.loadPrimaryColor();
  await WidgetService.init();

  // Initialize Notifications
  await NotificationService.initialize();
  
  // Set up click handler for notifications
  NotificationService.onNotificationClick = (String? payload) {
    if (payload != null) {
       final uri = Uri.tryParse(payload);
       if (uri != null && navigatorKey.currentState != null) {
          _handleDeepLink(uri);
       } else {
          // If the app was completely killed, we need to defer routing
          _pendingDeepLink = uri;
       }
    }
  };

  // Initialize and register background tasks
  await BackgroundTaskService.initialize();
  await BackgroundTaskService.registerDailyCheck();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Uri? _pendingDeepLink;

void _handleDeepLink(Uri uri) {
  if (uri.scheme == 'tvtime') {
    if (uri.host == 'show') {
      if (uri.pathSegments.length >= 2) {
        final tmdbIdStr = uri.pathSegments[0];
        final type = uri.pathSegments[1];
        final tmdbId = int.tryParse(tmdbIdStr);
        if (tmdbId != null) {
          // Push show details
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(tmdbId: tmdbId, type: type),
            ),
          );
        }
      }
    } else if (uri.host == 'home') {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Request Notification Permissions on Android 13+ after app is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Permission.notification.request();
    });

    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetRoute(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) => _handleWidgetRoute(uri));
    
    // Process pending notification deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingDeepLink != null) {
        _handleDeepLink(_pendingDeepLink!);
        _pendingDeepLink = null;
      }
    });
  }

  void _handleWidgetRoute(Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rebuildKey = ref.watch(themeRebuildProvider);
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      key: ValueKey(rebuildKey),
      title: 'TV Time',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
