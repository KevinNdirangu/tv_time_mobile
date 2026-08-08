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
import '../services/notification_service.dart';
import '../main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _calendarUrl =
      'https://gnwzertrmjerymlzzfuh.supabase.co/rest/v1/rpc/get_calendar_ics?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3plcnRybWplcnltbHp6ZnVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODU5MTIsImV4cCI6MjEwMDY2MTkxMn0.4Y8p6Um7qH8OUS6pAVpQDPxJ9d_wguqVKjnDiWESEZs';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final autoTimezoneShift = ref.watch(autoTimezoneShiftProvider);

    // ── helpers ───────────────────────────────────────────────────────────────
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
        _snack(context, 'Export failed: $e');
      }
    }

    Future<void> exportCsv() async {
      try {
        final data = await SupabaseActions.exportDatabase();
        final shows = data.firstWhere((e) => e['table'] == 'shows')['data'] as List<dynamic>;
        final episodes = data.firstWhere((e) => e['table'] == 'episodes')['data'] as List<dynamic>;
        final history = data.firstWhere((e) => e['table'] == 'watch_history')['data'] as List<dynamic>;
        
        if (history.isEmpty) {
          if (!context.mounted) return;
          _snack(context, 'No watch history to export');
          return;
        }

        final showMap = {for (var s in shows) s['id']: s['title']};
        final epMap = {for (var e in episodes) e['id']: e};

        List<List<dynamic>> rows = [
          ['show_name', 'season', 'episode', 'episode_name', 'date_watched']
        ];
        
        for (var h in history) {
          final ep = epMap[h['episode_id']];
          if (ep != null) {
            final showTitle = showMap[ep['show_id']] ?? 'Unknown Show';
            rows.add([
              showTitle,
              ep['season_number'],
              ep['episode_number'],
              ep['title'] ?? '',
              h['watched_at'] ?? h['created_at'] ?? ''
            ]);
          }
        }

        final csvStr = const ListToCsvConverter().convert(rows);
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/tv_time_backup.csv');
        await file.writeAsString(csvStr);
        await Share.shareXFiles([XFile(file.path)], text: 'TV Time Backup (CSV)');
      } catch (e) {
        if (!context.mounted) return;
        _snack(context, 'Export failed: $e');
      }
    }

    Future<void> importCsv() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (result != null) {
          final file = File(result.files.single.path!);
          final csvStr = await file.readAsString();
          final fields = const CsvToListConverter().convert(csvStr);
          
          if (!context.mounted) return;
          
          final progressNotifier = ValueNotifier<String>('Starting import...');
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceLight,
              title: Text('Importing CSV', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.bold)),
              content: ValueListenableBuilder<String>(
                valueListenable: progressNotifier,
                builder: (context, value, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 20),
                      Text(value, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14), textAlign: TextAlign.center),
                    ],
                  );
                },
              ),
            ),
          );

          await SupabaseActions.importCsv(
            fields,
            onProgress: (current, total, showName) {
              progressNotifier.value = 'Processing $current of $total\n$showName';
            }
          );
          
          if (context.mounted) {
            Navigator.pop(context); // close modal
          }
          
          ref.invalidate(libraryProvider);
          if (!context.mounted) return;
          _snack(context, '✓ Import complete!');
        }
      } catch (e) {
        if (!context.mounted) return;
        _snack(context, 'Import failed: $e');
      }
    }

    Future<void> downloadIcs() async {
      _snack(context, 'Generating calendar…');
      try {
        final icsContent = await SupabaseActions.generateIcs();
        if (icsContent.isEmpty) {
          if (!context.mounted) return;
          _snack(context, 'Calendar is empty or failed to load.');
          return;
        }
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/tvtracker.ics');
        await file.writeAsString(icsContent);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/calendar')],
          text: 'TV Time Calendar (.ics)',
        );
      } catch (e) {
        if (!context.mounted) return;
        _snack(context, 'Export failed: $e');
      }
    }

    Future<void> subscribeGoogleCal() async {
      final webcalUrl = _calendarUrl
          .replaceFirst('https://', 'webcal://')
          .replaceFirst('http://', 'webcal://');
      final googleCalUrl =
          'https://calendar.google.com/calendar/u/0/r?cid=${Uri.encodeComponent(webcalUrl)}';
      try {
        await launchUrl(Uri.parse(googleCalUrl), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!context.mounted) return;
        _snack(context, 'Could not open Google Calendar: $e');
      }
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain),
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── APPEARANCE ──────────────────────────────────────────────────
            _SectionLabel(label: 'Appearance'),
            _SettingsGroup(children: [
              // Accent color row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _SettingIcon(icon: Icons.palette_rounded, color: const Color(0xFFaf52de)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Accent Color',
                          style: TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        _ColorDot(color: const Color(0xFFFFD600), isSelected: AppTheme.primary.toARGB32() == 0xFFFFD600, onTap: () => updateColor(const Color(0xFFFFD600))),
                        _ColorDot(color: const Color(0xFFff3b30), isSelected: AppTheme.primary.toARGB32() == 0xFFff3b30, onTap: () => updateColor(const Color(0xFFff3b30))),
                        _ColorDot(color: const Color(0xFF34c759), isSelected: AppTheme.primary.toARGB32() == 0xFF34c759, onTap: () => updateColor(const Color(0xFF34c759))),
                        _ColorDot(color: const Color(0xFF0a84ff), isSelected: AppTheme.primary.toARGB32() == 0xFF0a84ff, onTap: () => updateColor(const Color(0xFF0a84ff))),
                        _ColorDot(color: const Color(0xFFaf52de), isSelected: AppTheme.primary.toARGB32() == 0xFFaf52de, onTap: () => updateColor(const Color(0xFFaf52de))),
                      ],
                    ),
                  ],
                ),
              ),
            ]),

            // ── TIMEZONE ─────────────────────────────────────────────────────
            _SectionLabel(label: 'Timezone'),
            _SettingsGroup(children: [
              // Toggle row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _SettingIcon(icon: Icons.schedule_rounded, color: const Color(0xFF0a84ff)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto-Timezone Shift',
                              style: TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w500)),
                          Text('Shift US show air dates +1 day for non-US timezones.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: autoTimezoneShift,
                      onChanged: (val) => ref.read(autoTimezoneShiftProvider.notifier).toggle(val),
                      activeThumbColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
              _Divider(),
              // Run fix row
              _ActionRow(
                icon: Icons.auto_fix_high_rounded,
                iconColor: const Color(0xFFff9f0a),
                title: 'Apply Timezone Fix to Library',
                subtitle: 'Updates existing entries to corrected air dates.',
                onTap: () async {
                  _snack(context, 'Applying timezone fix…');
                  await SupabaseActions.runTimezoneFix();
                  ref.invalidate(libraryProvider);
                  if (!context.mounted) return;
                  _snack(context, '✓ Timezone fix applied!');
                },
              ),
            ]),

            // ── NOTIFICATIONS ─────────────────────────────────────────────────
            _SectionLabel(label: 'Notifications'),
            _SettingsGroup(children: [
              _NotificationRow(),
              _Divider(),
              _ActionRow(
                icon: Icons.bug_report_rounded,
                iconColor: const Color(0xFFff9f0a),
                title: 'Test Notification',
                subtitle: 'Send a test push notification to verify setup.',
                onTap: () async {
                  await NotificationService.showNotification(
                    id: 999,
                    title: 'Test Successful!',
                    body: 'Your notification system is working perfectly.',
                  );
                  if (context.mounted) _snack(context, 'Test notification sent!');
                },
              ),
            ]),

            // ── DATA MANAGEMENT ───────────────────────────────────────────────
            _SectionLabel(label: 'Data Management'),
            _SettingsGroup(children: [
              _ActionRow(
                icon: Icons.upload_file_rounded,
                iconColor: const Color(0xFF34c759),
                title: 'Import CSV',
                subtitle: 'Import from TV Time exports or Letterboxd logs.',
                onTap: importCsv,
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.download_rounded,
                iconColor: const Color(0xFF0a84ff),
                title: 'Export as JSON',
                subtitle: 'Full backup of your library and watch history.',
                onTap: exportJson,
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.table_chart_rounded,
                iconColor: const Color(0xFF34c759),
                title: 'Export as CSV',
                subtitle: 'Spreadsheet-compatible export of your shows list.',
                onTap: exportCsv,
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.build_rounded,
                iconColor: const Color(0xFFFF9F0A),
                title: 'Repair Legacy Movies',
                subtitle: 'Automatically fix broken movies in your library.',
                onTap: () async {
                  if (!context.mounted) return;
                  _snack(context, 'Scanning for broken movies...');
                  try {
                    final repaired = await SupabaseActions.repairAllLegacyMovies();
                    if (!context.mounted) return;
                    
                    if (repaired > 0) {
                      _snack(context, 'Success! Repaired $repaired legacy movie(s).');
                      ref.invalidate(showsProvider);
                      ref.invalidate(libraryProvider);
                    } else {
                      _snack(context, 'All your movies are already in perfect condition!');
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    _snack(context, 'Repair failed: $e');
                  }
                },
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFFaf52de),
                title: 'Sync Seen Dates',
                subtitle: 'Refresh all cached dates from watch history.',
                onTap: () async {
                  _snack(context, 'Refreshing dates...');
                  ref.invalidate(libraryProvider);
                  if (context.mounted) _snack(context, '✓ Seen dates refreshed!');
                },
              ),
            ]),

            // ── CLOUD CALENDAR ────────────────────────────────────────────────
            _SectionLabel(label: 'Cloud Calendar'),
            _SettingsGroup(children: [
              _ActionRow(
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF636366),
                title: 'Copy Calendar URL',
                subtitle: 'Paste into Google/Apple Calendar → "Add from URL".',
                trailing: _PillBadge(label: 'ICS', color: const Color(0xFF636366)),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _calendarUrl));
                  _snack(context, '✓ URL Copied! Add this to your calendar app.');
                },
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF34c759),
                title: 'Subscribe in Google Calendar',
                subtitle: 'Opens Google Calendar subscription flow.',
                trailing: _PillBadge(label: 'Google', color: const Color(0xFF34c759)),
                onTap: subscribeGoogleCal,
              ),
              _Divider(),
              _ActionRow(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF0a84ff),
                title: 'Download .ics File',
                subtitle: 'Save & import into any calendar app.',
                trailing: _PillBadge(label: '.ics', color: const Color(0xFF0a84ff)),
                onTap: downloadIcs,
              ),
            ]),

            // ── ABOUT ─────────────────────────────────────────────────────────
            _SectionLabel(label: 'About'),
            _SettingsGroup(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.tv_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TV Time', style: TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('Version 1.0.0 • Built with ♥', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── SHARED WIDGETS ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 28, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 58),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SettingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              _SettingIcon(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null) trailing!
              else
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 6),
        width: isSelected ? 30 : 26,
        height: isSelected ? 30 : 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
            : null,
      ),
    );
  }
}

class _NotificationRow extends StatefulWidget {
  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> with WidgetsBindingObserver {
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _isGranted = status.isGranted);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGranted) {
      return _ActionRow(
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFF34c759),
        title: 'Push Notifications Enabled',
        subtitle: 'You will receive alerts when episodes air.',
        trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF34c759), size: 20),
        onTap: () {},
      );
    }
    return _ActionRow(
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFFff3b30),
      title: 'Enable Push Notifications',
      subtitle: 'Get alerts when episodes from your list air today.',
      onTap: () async {
        PermissionStatus status = await Permission.notification.status;
        if (status.isDenied) {
          status = await Permission.notification.request();
        }
        if (!context.mounted) return;
        if (status.isGranted) {
          setState(() => _isGranted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Notifications enabled!')),
          );
        } else if (status.isPermanentlyDenied || status.isRestricted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceLight,
              title: const Text('Permission Required', style: TextStyle(color: AppTheme.textMain)),
              content: const Text(
                'Notification permission is restricted or permanently denied. Please enable it in system settings.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () { openAppSettings(); Navigator.pop(ctx); },
                  child: Text('Open Settings', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

