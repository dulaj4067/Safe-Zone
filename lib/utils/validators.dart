/// Input validation shared by registration and profile editing, so the two
/// forms (and the server's expectations) agree. Each returns null when the
/// value is valid, or a message to show under the field.
library;

const int kMaxNameLength = 80;
const int kMaxEmailLength = 254;

/// Supabase Auth's minimum password length for this project. Raising it in
/// the Supabase dashboard? Raise this to match, or sign-up errors will only
/// appear after the request.
const int kMinPasswordLength = 6;
const int kMaxPasswordLength = 72; // bcrypt ignores anything longer

String? validateFullName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your name';
  if (v.length < 2) return 'Name is too short';
  if (v.length > kMaxNameLength) return 'Keep it under $kMaxNameLength characters';
  return null;
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (v.length > kMaxEmailLength || !_emailPattern.hasMatch(v)) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Mobile numbers: Sri Lankan (07XXXXXXXX, 7XXXXXXXX, +947XXXXXXXX) or any
/// international number written with a leading + (8–15 digits). Spaces,
/// dashes and brackets are allowed. Stored in one canonical form — see
/// [normalizePhone] — because people are matched by phone number.
String? validatePhone(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your mobile number';
  if (_uuidPattern.hasMatch(v)) {
    // Accounts created without a phone were given their account id here.
    return 'That looks like an account ID, not a phone number';
  }
  if (normalizePhone(v) == null) {
    return 'Enter a mobile number, e.g. 0771234567 or +44 7700 900123';
  }
  return null;
}

/// True for values like a user id — accounts created without a phone
/// number were given their id in the phone field.
bool looksLikeAccountId(String value) => _uuidPattern.hasMatch(value.trim());

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Returns the number as `+digits` (Sri Lankan mobiles as +947XXXXXXXX), or
/// null if it isn't a valid mobile number.
String? normalizePhone(String value) {
  final compact = _asciiDigits(value).replaceAll(RegExp(r'[\s\-()]'), '');
  final sriLankan = RegExp(r'^(?:\+94|0094|94|0)?(7\d{8})$').firstMatch(compact);
  if (sriLankan != null) return '+94${sriLankan.group(1)}';
  final international = RegExp(r'^\+([1-9]\d{7,14})$').firstMatch(compact);
  if (international != null) return '+${international.group(1)}';
  return null;
}

/// Rewrites Arabic-Indic, Extended Arabic-Indic, Tamil and Sinhala digits as
/// 0-9, so a number typed on an Arabic, Tamil or Sinhala keyboard validates
/// and is stored the same way as one typed with Latin digits.
String _asciiDigits(String input) {
  const starts = [0x0660, 0x06F0, 0x0BE6, 0x0DE6];
  final out = StringBuffer();
  for (final rune in input.runes) {
    var mapped = rune;
    for (final start in starts) {
      if (rune >= start && rune <= start + 9) {
        mapped = 0x30 + (rune - start);
        break;
      }
    }
    out.writeCharCode(mapped);
  }
  return out.toString();
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Choose a password';
  if (v.length < kMinPasswordLength) {
    return 'Use at least $kMinPasswordLength characters';
  }
  if (v.length > kMaxPasswordLength) {
    return 'Keep it under $kMaxPasswordLength characters';
  }
  if (v.trim().isEmpty) return 'Password can\'t be only spaces';
  return null;
}
