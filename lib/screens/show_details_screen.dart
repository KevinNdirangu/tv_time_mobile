import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShowDetailsScreen extends StatelessWidget {
  final int tmdbId;
  final String type;

  const ShowDetailsScreen({super.key, required this.tmdbId, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Text('Loading details for TMDB ID $tmdbId ($type)...', style: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }
}
