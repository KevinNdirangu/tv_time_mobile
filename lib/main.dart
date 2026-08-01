import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gnwzertrmjerymlzzfuh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3plcnRybWplcnltbHp6ZnVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODU5MTIsImV4cCI6MjEwMDY2MTkxMn0.4Y8p6Um7qH8OUS6pAVpQDPxJ9d_wguqVKjnDiWESEZs',
  );

  runApp(const ProviderScope(child: TvTimeApp()));
}

class TvTimeApp extends StatelessWidget {
  const TvTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Time',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}


