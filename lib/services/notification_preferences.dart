import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists notification-related user preferences. Persistence is best-effort —
/// in-memory state always reflects the current value; disk failures are
/// swallowed silently.
///
/// Singleton — read/write via [NotificationPreferences.instance].
class NotificationPreferences extends ChangeNotifier {
  NotificationPreferences._();
  static final NotificationPreferences instance = NotificationPreferences._();

  static const String _inAppAlertsKey = 'aura_in_app_alerts';
  static const String _hapticsKey = 'aura_haptics';

  bool _inAppAlerts = true;
  bool _haptics = true;

  bool get inAppAlerts => _inAppAlerts;
  bool get haptics => _haptics;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _inAppAlerts = prefs.getBool(_inAppAlertsKey) ?? true;
      _haptics = prefs.getBool(_hapticsKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Best effort — defaults stay in place.
    }
  }

  Future<void> setInAppAlerts(bool value) async {
    if (_inAppAlerts == value) return;
    _inAppAlerts = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_inAppAlertsKey, value);
    } catch (_) {}
  }

  Future<void> setHaptics(bool value) async {
    if (_haptics == value) return;
    _haptics = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticsKey, value);
    } catch (_) {}
  }
}
