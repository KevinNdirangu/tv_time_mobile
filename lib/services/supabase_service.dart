import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/show.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final showsProvider = FutureProvider<List<Show>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  
  // Wait for the query to complete
  final response = await client.from('shows').select('*').order('id', ascending: false);
  
  // Map the JSON objects to Show model
  return (response as List<dynamic>).map((e) => Show.fromJson(e)).toList();
});
