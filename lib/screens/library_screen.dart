import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsyncValue = ref.watch(showsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: showsAsyncValue.when(
        data: (shows) {
          if (shows.isEmpty) {
            return const Center(child: Text('Your library is empty.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: shows.length,
            itemBuilder: (context, index) {
              final show = shows[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: show.posterUrl != null && show.posterUrl!.isNotEmpty
                    ? Image.network(
                        show.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceLight,
      child: const Center(
        child: Icon(Icons.movie, color: AppTheme.textMuted, size: 40),
      ),
    );
  }
}
