import 'dart:async';

/// Carries "the person opened an alert's notification" from the Android
/// notification callbacks (which have no access to the widget tree) to
/// [AlertProvider].
///
/// Two cases: the app is running and the notification is tapped, or the
/// full-screen intent brings the app up over the lock screen or another app
/// (a cold start the callback can't deliver to anyone yet, so the payload is
/// parked in [pending] until the provider has loaded its alerts).
class AlertLaunchBus {
  AlertLaunchBus._();

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();
  static String? _pending;

  static Stream<String> get stream => _controller.stream;

  /// Called by the notification plugin when a notification is opened.
  static void emit(String alertId) {
    _pending = alertId;
    _controller.add(alertId);
  }

  /// Park the payload of the notification that launched the app.
  static void setLaunchPayload(String? alertId) {
    if (alertId != null && alertId.isNotEmpty) _pending = alertId;
  }

  /// The alert to open once alerts are loaded, cleared when read.
  static String? takePending() {
    final id = _pending;
    _pending = null;
    return id;
  }
}
