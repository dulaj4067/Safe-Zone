import 'package:flutter/widgets.dart';

import 'app_strings.dart';
import 'ui_text_ar.dart';
import 'ui_text_si.dart';
import 'ui_text_ta.dart';

/// Translations looked up by their English wording, for the screens that
/// were written with plain English strings. `context.tr('Messages')` returns
/// the Sinhala, Tamil or Arabic text when the person has picked that language,
/// and the English text itself otherwise or when no translation exists yet.
///
/// Values with variable parts use `{name}` placeholders in both the key and
/// every translation, filled from the `args` map:
/// `context.tr('Capacity {n}', {'n': shelter.capacity})`.
///
/// The Sinhala, Tamil and Arabic text is a first draft and should be reviewed
/// by native speakers before release.
class UiText {
  UiText._();

  static const Map<String, Map<String, String>> catalogs = {
    'si': uiTextSi,
    'ta': uiTextTa,
    'ar': uiTextAr,
  };

  /// Translate [english] into [languageCode] and fill in [args]. English (or a
  /// missing translation) falls back to [english] itself.
  static String translate(
    String languageCode,
    String english, [
    Map<String, Object?>? args,
  ]) {
    var out = catalogs[languageCode]?[english] ?? english;
    if (args != null) {
      args.forEach((name, value) {
        out = out.replaceAll('{$name}', '$value');
      });
    }
    return out;
  }
}

extension UiTranslate on BuildContext {
  /// The text for the person's chosen language (see [UiText]).
  String tr(String english, [Map<String, Object?>? args]) =>
      UiText.translate(appStringsOf(this).localeCode, english, args);

  /// For form validators: translates the message, passes null through.
  String? trv(String? message) => message == null ? null : tr(message);
}
