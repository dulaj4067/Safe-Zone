// Shared formatting helpers used across multiple screens.

/// Returns a human-readable relative time string for [dt].
///
/// Examples: `"just now"`, `"5m ago"`, `"3h ago"`, `"2d ago"`.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Returns a human-readable distance label for [metres].
///
/// Below 1 km → `"150 m"`.  At or above 1 km → `"1.2 km"`.
String distanceLabel(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}
