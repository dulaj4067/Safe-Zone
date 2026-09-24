/// Delivery channels available for disaster alert dissemination.
enum DeliveryChannel {
  /// Standard operating system push notification.
  push,

  /// Emergency SMS backup dispatch.
  sms,

  /// High-priority in-app banner and audible emergency alarm.
  inApp,
}

/// Represents the result of an alert delivery attempt across channels.
class AlertDeliveryResult {
  final String alertId;
  final bool primarySucceeded;
  final bool fallbackTriggered;
  final List<DeliveryChannel> channelsUsed;
  final String? failureReason;
  final DateTime timestamp;

  AlertDeliveryResult({
    required this.alertId,
    required this.primarySucceeded,
    required this.fallbackTriggered,
    required this.channelsUsed,
    this.failureReason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether the citizen received the alert through at least one channel.
  bool get isDelivered => primarySucceeded || fallbackTriggered;

  @override
  String toString() {
    return 'AlertDeliveryResult(alertId: $alertId, primary: $primarySucceeded, '
        'fallback: $fallbackTriggered, channels: $channelsUsed, failure: $failureReason)';
  }
}
