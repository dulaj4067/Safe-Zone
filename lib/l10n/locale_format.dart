import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale-aware dates, times, currency, and numbers for Sri Lanka.
/// Dates render as `13 Sep 2025`. Money renders as `Rs 2,450.00`.
class LocaleFormat {
  LocaleFormat._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await Future.wait([
      initializeDateFormatting('en'),
      initializeDateFormatting('si'),
      initializeDateFormatting('ta'),
      initializeDateFormatting('ar'),
    ]);
    _initialized = true;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String date(DateTime dt, {String locale = 'en'}) {
    final patternLocale = switch (locale) {
      'si' => 'si',
      'ta' => 'ta',
      'ar' => 'ar',
      _ => 'en',
    };
    try {
      return DateFormat('d MMM yyyy', patternLocale).format(dt.toLocal());
    } catch (_) {
      try {
        return DateFormat('d MMM yyyy', 'en').format(dt.toLocal());
      } catch (_) {
        final local = dt.toLocal();
        final month = _months[(local.month - 1).clamp(0, 11)];
        return '${local.day} $month ${local.year}';
      }
    }
  }

  static String time(DateTime dt, {String locale = 'en'}) {
    final patternLocale = locale == 'ar' ? 'ar' : 'en';
    try {
      return DateFormat.jm(patternLocale).format(dt.toLocal());
    } catch (_) {
      try {
        return DateFormat.jm('en').format(dt.toLocal());
      } catch (_) {
        final local = dt.toLocal();
        final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
        final ampm = local.hour >= 12 ? 'PM' : 'AM';
        final minute = local.minute.toString().padLeft(2, '0');
        return '$hour:$minute $ampm';
      }
    }
  }

  static String dateTime(DateTime dt, {String locale = 'en'}) =>
      '${date(dt, locale: locale)} ${time(dt, locale: locale)}';

  /// Sri Lankan rupees: `Rs 2,450.00`
  static String lkr(num amount) {
    final grouped = NumberFormat('#,##0.00', 'en_LK').format(amount);
    return 'Rs $grouped';
  }

  static String decimal(num value, {int fractionDigits = 1}) {
    return NumberFormat.decimalPattern('en_LK')
        .format(double.parse(value.toStringAsFixed(fractionDigits)));
  }
}
