import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final autoTimezoneShiftProvider = StateNotifierProvider<AutoTimezoneShiftNotifier, bool>((ref) {
  return AutoTimezoneShiftNotifier();
});

class AutoTimezoneShiftNotifier extends StateNotifier<bool> {
  AutoTimezoneShiftNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('autoTimezoneShift') ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoTimezoneShift', value);
  }
}
