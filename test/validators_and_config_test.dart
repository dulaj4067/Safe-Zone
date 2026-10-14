import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/utils/app_config.dart';
import 'package:safezone/utils/validators.dart';

void main() {
  group('validateFullName', () {
    test('rejects empty, whitespace-only and too-short names', () {
      expect(validateFullName(null), isNotNull);
      expect(validateFullName(''), isNotNull);
      expect(validateFullName('    '), isNotNull);
      expect(validateFullName('A'), isNotNull);
    });
    test('rejects overly long names', () {
      expect(validateFullName('a' * (kMaxNameLength + 1)), isNotNull);
    });
    test('accepts a normal name, ignoring surrounding spaces', () {
      expect(validateFullName('  Nimal Silva '), isNull);
    });
  });

  group('validateEmail', () {
    test('rejects malformed addresses', () {
      for (final bad in ['', '   ', 'nimal', 'nimal@', '@x.com', 'a b@x.com', 'a@b']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
    });
    test('accepts valid addresses', () {
      expect(validateEmail(' nimal.silva@example.lk '), isNull);
    });
  });

  group('phone validation and normalisation', () {
    test('Sri Lankan mobile formats normalise to +947XXXXXXXX', () {
      expect(normalizePhone('0771234567'), '+94771234567');
      expect(normalizePhone('771234567'), '+94771234567');
      expect(normalizePhone('+94 77 123 4567'), '+94771234567');
      expect(normalizePhone('0094-77-123-4567'), '+94771234567');
    });
    test('international numbers with a leading + are kept', () {
      expect(normalizePhone('+44 7700 900123'), '+447700900123');
    });
    test('digits typed on Arabic, Tamil and Sinhala keyboards are accepted', () {
      // Re-script the ASCII digits 0-9 into each zero-based digit block.
      String inScript(int zero, String ascii) =>
          String.fromCharCodes(ascii.codeUnits.map((c) => zero + (c - 0x30)));
      for (final zero in [0x0660, 0x06F0, 0x0BE6, 0x0DE6]) {
        final typed = inScript(zero, '0771234567');
        expect(typed, isNot('0771234567'), reason: 'sanity: really non-ASCII');
        expect(normalizePhone(typed), '+94771234567', reason: 'U+${zero.toRadixString(16)}');
        expect(validatePhone(typed), isNull);
      }
    });

    test('rejects landlines without +, short numbers and letters', () {
      for (final bad in ['0112345678', '12345', 'phone', '+0123456789']) {
        expect(normalizePhone(bad), isNull, reason: bad);
        expect(validatePhone(bad), isNotNull, reason: bad);
      }
    });
    test('flags an account id stored in the phone field', () {
      const id = 'a5e63282-30d9-4ce9-a829-87e631d96aa0';
      expect(looksLikeAccountId(id), isTrue);
      expect(validatePhone(id), contains('account ID'));
    });
  });

  group('validatePassword', () {
    test('enforces the length bounds', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('a' * (kMinPasswordLength - 1)), isNotNull);
      expect(validatePassword('a' * (kMaxPasswordLength + 1)), isNotNull);
      expect(validatePassword(' ' * kMinPasswordLength), isNotNull);
      expect(validatePassword('correct horse'), isNull);
    });
  });

  group('AppConfig', () {
    test('falls back to the shared project when nothing is configured', () {
      final config = AppConfig.resolve(url: '', publishableKey: '');
      expect(config.supabaseUrl, startsWith('https://'));
      expect(config.supabasePublishableKey, startsWith('sb_publishable_'));
    });
    test('uses configured values, trimmed', () {
      final config = AppConfig.resolve(
        url: ' https://example.supabase.co ',
        publishableKey: ' sb_publishable_abc ',
      );
      expect(config.supabaseUrl, 'https://example.supabase.co');
      expect(config.supabasePublishableKey, 'sb_publishable_abc');
    });
    test('rejects a non-https URL', () {
      expect(
        () => AppConfig.resolve(url: 'http://example.com', publishableKey: 'sb_publishable_x'),
        throwsStateError,
      );
    });
    test('refuses to bundle a secret key', () {
      expect(
        () => AppConfig.resolve(url: 'https://x.supabase.co', publishableKey: 'sb_secret_123'),
        throwsStateError,
      );
    });
  });
}
