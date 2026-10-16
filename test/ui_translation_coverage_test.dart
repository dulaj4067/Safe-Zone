import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/l10n/ui_text.dart';
import 'package:safezone/l10n/ui_text_ar.dart';
import 'package:safezone/l10n/ui_text_si.dart';
import 'package:safezone/l10n/ui_text_ta.dart';
import 'package:safezone/utils/error_messages.dart';

/// Every English string passed to `tr('...')` in the app must have a Sinhala,
/// Tamil and Arabic translation with the same {placeholders}, so no screen
/// quietly falls back to English in another language.
final _call = RegExp(
  r"""\btr\(\s*(?:(')((?:\\.|[^'\\])*)'|(")((?:\\.|[^"\\])*)")""",
);

const _backslash = r'\';

String _unescape(String raw) => raw
    .replaceAll("$_backslash'", "'")
    .replaceAll('$_backslash"', '"')
    .replaceAll('$_backslash\$', r'$')
    .replaceAll('${_backslash}n', '\n')
    .replaceAll('$_backslash$_backslash', _backslash);

Set<String> _placeholders(String s) =>
    RegExp(r'\{[A-Za-z0-9_]+\}').allMatches(s).map((m) => m.group(0)!).toSet();

void main() {
  final catalogs = {'si': uiTextSi, 'ta': uiTextTa, 'ar': uiTextAr};

  final used = <String, Set<String>>{}; // English text -> files using it
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    final src = file.readAsStringSync();
    for (final m in _call.allMatches(src)) {
      final raw = m.group(2) ?? m.group(4)!;
      // Skip interpolated Dart strings (they have no fixed key).
      if (RegExp(r'(?<!\\)\$').hasMatch(raw)) continue;
      used
          .putIfAbsent(_unescape(raw), () => {})
          .add(file.path.replaceAll(_backslash, '/'));
    }
  }
  for (final message in kFriendlyErrorMessages) {
    used.putIfAbsent(message, () => {}).add('lib/utils/error_messages.dart');
  }

  test("the scan found the app's translated strings", () {
    expect(used.length, greaterThan(300));
  });

  for (final entry in catalogs.entries) {
    test('${entry.key}: every tr() string has a translation', () {
      final missing = used.keys.where((k) => !entry.value.containsKey(k)).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason: 'Add these to ui_text_${entry.key}.dart:\n${missing.take(30).join('\n')}',
      );
    });

    test('${entry.key}: translations are not blank and keep the {placeholders}', () {
      for (final e in entry.value.entries) {
        expect(e.value.trim(), isNotEmpty, reason: e.key);
        expect(_placeholders(e.value), _placeholders(e.key), reason: 'placeholders of "${e.key}"');
      }
    });
  }

  test('the three languages define the same strings', () {
    expect(uiTextAr.keys.toSet(), uiTextSi.keys.toSet());
    expect(uiTextTa.keys.toSet(), uiTextSi.keys.toSet());
  });

  test('tr falls back to English, and fills placeholders in every language', () {
    expect(UiText.translate('en', 'Messages'), 'Messages');
    expect(UiText.translate('si', 'Definitely not translated {n}', {'n': 3}), 'Definitely not translated 3');
    expect(UiText.translate('ar', 'Version {p0}', {'p0': '1.2'}), contains('1.2'));
    expect(UiText.translate('ta', 'Version {p0}', {'p0': '1.2'}), isNot(contains('{p0}')));
  });
}
