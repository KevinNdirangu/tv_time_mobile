import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';
import '../services/supabase_service.dart';
import '../main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final autoTimezoneShift = ref.watch(autoTimezoneShiftProvider);

    Widget buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
        ),
      );
    }

    Widget buildCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
    }

    Widget buildButton(String text, Color color, VoidCallback onTap) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: (color == AppTheme.primary || color == Colors.white || color == const Color(0xFF34c759)) ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }

    Future<void> updateColor(Color color) async {
      await AppTheme.savePrimaryColor(color);
      ref.read(themeRebuildProvider.notifier).state++;
    }

    Future<void> exportJson() async {
      try {
        final data = await SupabaseActions.exportDatabase();
        final jsonStr = jsonEncode(data);
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/tv_time_backup.json');
        await file.writeAsString(jsonStr);
        await Share.shareXFiles([XFile(file.path)], text: 'TV Time Backup (JSON)');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }

    Future<void> exportCsv() async {
      try {
        final data = await SupabaseActions.exportDatabase();
        final shows = data.firstWhere((e) => e['table'] == 'shows')['data'] as List<dynamic>;
        if (shows.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
          return;
        }
        
        List<List<dynamic>> rows = [];
        if (shows.isNotEmpty) {
          rows.add((shows.first as Map<String, dynamic>).keys.toList());
          for (var s in shows) {
            rows.add((s as Map<String, dynamic>).values.toList());
          }
        }
        
        final csvStr = const ListToCsvConverter().convert(rows);
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/tv_time_backup.csv');
        await file.writeAsString(csvStr);
        await Share.shareXFiles([XFile(file.path)], text: 'TV Time Backup (CSV)');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }

    Future<void> importCsv() async {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        
        if (result != null) {
          final file = File(result.files.single.path!);
          final csvStr = await file.readAsString();
          final fields = const CsvToListConverter().convert(csvStr);
          // Remove header if it exists
          if (fields.isNotEmpty && fields[0][0].toString().toLowerCase().contains('id')) {
            fields.removeAt(0);
          }
          await SupabaseActions.importCsv(fields);
          ref.invalidate(libraryProvider);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import complete!')));
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Builder(
            builder: (context) => Badge(
              isLabelVisible: notifications.isNotEmpty,
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: AppTheme.primary),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings & Integrations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            
            // Appearance
            buildSectionTitle('Appearance'),
            buildCard(
              child: Row(
                children: [
                  const Text('Accent Color:', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  _ColorDot(color: const Color(0xFFFFD600), isSelected: AppTheme.primary.toARGB32() == 0xFFFFD600, onTap: () => updateColor(const Color(0xFFFFD600))),
                  _ColorDot(color: const Color(0xFFff3b30), isSelected: AppTheme.primary.toARGB32() == 0xFFff3b30, onTap: () => updateColor(const Color(0xFFff3b30))),
                  _ColorDot(color: const Color(0xFF34c759), isSelected: AppTheme.primary.toARGB32() == 0xFF34c759, onTap: () => updateColor(const Color(0xFF34c759))),
                  _ColorDot(color: const Color(0xFF0a84ff), isSelected: AppTheme.primary.toARGB32() == 0xFF0a84ff, onTap: () => updateColor(const Color(0xFF0a84ff))),
                  _ColorDot(color: const Color(0xFFaf52de), isSelected: AppTheme.primary.toARGB32() == 0xFFaf52de, onTap: () => updateColor(const Color(0xFFaf52de))),
                ],
              ),
            ),

            // Timezone
            buildSectionTitle('Global Timezone Shift'),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Automatically adds +1 day to air dates of shows originating in the Americas to match local timezones.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: autoTimezoneShift,
                        onChanged: (val) => ref.read(autoTimezoneShiftProvider.notifier).toggle(val),
                      activeThumbColor: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Enable Auto-Timezone Shift', style: TextStyle(color: AppTheme.textMain)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildButton('Run Timezone Fix on Existing Library', const Color(0xFF333333), () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying timezone fix...')));
                    await SupabaseActions.runTimezoneFix();
                    ref.invalidate(libraryProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timezone fix applied!')));
                  }),
                ],
              ),
            ),

            // Notifications
            buildSectionTitle('Notifications'),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get native push notifications on your phone when an episode from your Watchlist airs today.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  buildButton('Enable Push Notifications', const Color(0xFF333333), () async {
                    PermissionStatus status = await Permission.notification.status;
                    
                    if (status.isDenied) {
                      status = await Permission.notification.request();
                    }

                    if (!context.mounted) return;

                    if (status.isGranted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications enabled!')));
                    } else if (status.isPermanentlyDenied || status.isRestricted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Permission Required'),
                          content: const Text('Notification permission is restricted or permanently denied. Please enable it in system settings to receive alerts.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                openAppSettings();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Notification status: ${status.name}. Please check app settings.'),
                        action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
                      ));
                    }
                  }),
                ],
              ),
            ),

            // Data Management
            buildSectionTitle('Data Management'),
            Row(
              children: [
                Expanded(
                  child: buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Import CSV History', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Supports TV Time exports and Letterboxd logs.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        buildButton('Upload .CSV File', const Color(0xFF333333), importCsv),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Export Database', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Download a backup of your library and history.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: buildButton('JSON', const Color(0xFF0a84ff), exportJson)),
                            const SizedBox(width: 8),
                            Expanded(child: buildButton('CSV', const Color(0xFF34c759), exportCsv)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Cloud Calendar Subscription', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copy this URL into Google Calendar or Apple Calendar using the "Add from URL" option.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text('https://gnwzertrmjerymlzzfuh.supabase.co/functions/v1/calendar?user_id=global&ext=.ics', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: buildButton('Copy URL', const Color(0xFF333333), () {
                        Clipboard.setData(const ClipboardData(text: 'https://gnwzertrmjerymlzzfuh.supabase.co/functions/v1/calendar?user_id=global&ext=.ics'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied to clipboard!')));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: buildButton('Subscribe', const Color(0xFF34c759), () async {
                        const baseUrl = 'gnwzertrmjerymlzzfuh.supabase.co/functions/v1/calendar?user_id=global';
                        // Add .ics extension to help apps recognize the file type
                        const fullUrl = 'https://$baseUrl&ext=.ics';
                        const webcalUrl = 'webcal://$baseUrl&ext=.ics';
                        
                        // Google Calendar specific subscription link
                        final googleUrl = 'https://calendar.google.com/calendar/render?cid=${Uri.encodeComponent(webcalUrl)}';

                        try {
                          // 1. Try to launch as a webcal link (triggers Calendar apps directly)
                          bool launched = await launchUrl(
                            Uri.parse(webcalUrl),
                            mode: LaunchMode.externalApplication,
                          );

                          if (!launched) {
                            // 2. Fallback to Google Calendar website
                            await launchUrl(
                              Uri.parse(googleUrl),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          // 3. Final fallback: open in browser
                          await launchUrl(
                            Uri.parse(fullUrl),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      })),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
      ),
    );
  }
}
