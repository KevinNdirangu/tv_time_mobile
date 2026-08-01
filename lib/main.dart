import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';
import 'screens/show_details_screen.dart';
import 'theme/app_theme.dart';
import 'services/widget_service.dart';
import 'package:home_widget/home_widget.dart';

final themeRebuildProvider = StateProvider<int>((ref) => 0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gnwzertrmjerymlzzfuh.supabase.co'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3plcnRybWplcnltbHp6ZnVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODU5MTIsImV4cCI6MjEwMDY2MTkxMn0.4Y8p6Um7qH8OUS6pAVpQDPxJ9d_wguqVKjnDiWESEZs'),
  );

  await AppTheme.loadPrimaryColor();
  await WidgetService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetRoute(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) => _handleWidgetRoute(uri));
  }

  void _handleWidgetRoute(Uri? uri) {
    if (uri != null && uri.scheme == 'tvtime') {
      if (uri.host == 'show') {
        final showIdStr = uri.pathSegments.first;
        final showId = int.tryParse(showIdStr);
        if (showId != null) {
          // Push show details
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(showId: showId),
            ),
          );
        }
      } else if (uri.host == 'home') {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
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
