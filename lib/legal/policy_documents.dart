/// Terms of Use and Privacy Policy content, versioned.
///
/// Everything here describes what the app *verifiably does today* (checked
/// against the code and database policies in Oct 2026). Details only the
/// operator can supply — legal entity, contact address, governing law,
/// retention periods — live in [LegalConfig] and render as "not yet
/// confirmed" until filled in, rather than being invented.
///
/// Changing a document materially? Bump its [PolicyDocument.version]: every
/// signed-in user is then asked to review and accept the new version once.
library;

class LegalConfig {
  LegalConfig._();

  /// The organisation legally responsible for SafeZone. Null until the
  /// operator confirms it.
  static const String? operatorName = null;

  /// Privacy contact (email or postal address). Null until confirmed.
  static const String? privacyContact = null;

  /// Governing law / jurisdiction for the Terms. Null until confirmed.
  static const String? governingLaw = null;

  /// True while the documents haven't had legal review. Shown as a notice
  /// at the top of each document.
  static const bool pendingLegalReview = true;

  static String get operatorLabel => operatorName ?? 'the SafeZone operator';
  static String get contactLabel =>
      privacyContact ??
      'Contact details will be published here once confirmed. Until then, '
          'use Settings → Give feedback.';
}

class PolicySection {
  final String heading;
  final List<String> paragraphs;
  const PolicySection(this.heading, this.paragraphs);
}

class PolicyDocument {
  /// Stable id stored with each acceptance ('terms' / 'privacy').
  final String id;
  final String title;

  /// Stored with each acceptance; bump on any material change.
  final String version;
  final DateTime lastUpdated;
  final List<PolicySection> sections;

  const PolicyDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.lastUpdated,
    required this.sections,
  });
}

final PolicyDocument termsOfUse = PolicyDocument(
  id: 'terms',
  title: 'Terms of Use',
  version: '1.0',
  lastUpdated: DateTime(2026, 10, 14),
  sections: [
    const PolicySection('What SafeZone is', [
      'SafeZone shares disaster early warnings, community incident reports, '
          'shelter information and family safety tools for Sri Lanka.',
      'SafeZone supports, but does not replace, official warnings and '
          'emergency services. In an emergency, call 117 (Disaster '
          'Management Centre), 119 (Police) or 1990 (Ambulance) — the same '
          'hotlines listed in Settings — and follow instructions from the '
          'authorities.',
    ]),
    const PolicySection('Your account', [
      'Keep your password private and your phone number accurate — family '
          'members and responders rely on it. You are responsible for '
          'activity on your account.',
      'Self-registered accounts are citizen accounts. Authority and '
          'volunteer-organisation accounts are created by an administrator.',
    ]),
    const PolicySection('Reports and content you submit', [
      'Only report incidents you believe are genuine. Incident reports — '
          'including their description, photos/videos and exact location — '
          'are visible to everyone using SafeZone.',
      'You keep ownership of what you submit, and allow the operator and '
          'authorities to display, review and use it to coordinate the '
          'disaster response.',
    ]),
    const PolicySection('Not allowed', [
      'False or misleading reports, SOS alerts or "I\'m Safe" messages; '
          'harassment; sharing other people\'s personal information without '
          'their consent; trying to access accounts or data that aren\'t '
          'yours; or interfering with the service.',
    ]),
    const PolicySection('Moderation and suspension', [
      'Authorities may verify, reject, resolve or remove reports. Accounts '
          'that misuse the service may be suspended or removed.',
    ]),
    const PolicySection('Availability', [
      'Warnings depend on network coverage, your device settings and '
          'third-party services (maps, routing, email). They can be delayed '
          'or fail, so never rely on SafeZone as your only source of '
          'warnings. Features may change as the service develops.',
    ]),
    const PolicySection('Ending your account', [
      'You can request deletion of your account at any time from '
          'Settings → Privacy & data. See the Privacy Policy for what is '
          'deleted and what may be kept.',
    ]),
    PolicySection('Liability, governing law and contact', [
      'To the extent the law allows, SafeZone is provided "as is". Nothing '
          'in these terms limits rights you have under applicable law.',
      'Governing law: ${LegalConfig.governingLaw ?? 'to be confirmed by the operator.'}',
      'Operator: ${LegalConfig.operatorLabel}. ${LegalConfig.contactLabel}',
    ]),
  ],
);

final PolicyDocument privacyPolicy = PolicyDocument(
  id: 'privacy',
  title: 'Privacy Policy',
  // 1.1: "I'm Safe" emails to family; what account deletion removes.
  // 1.2: OpenStreetMap Nominatim names the area shown on the home map.
  version: '1.2',
  lastUpdated: DateTime(2026, 10, 14),
  sections: [
    PolicySection('Who is responsible', [
      'SafeZone is operated by ${LegalConfig.operatorLabel}. '
          '${LegalConfig.contactLabel}',
    ]),
    const PolicySection('What we collect', [
      'Account: name, mobile number, email address and password (stored '
          'hashed by our authentication provider, never readable by us), '
          'your account role and, if you choose one, your home zone.',
      'Incident reports: category, description, optional photos/videos, the '
          'exact location you report from, whether it was an SOS, and '
          'confirmations you give to other reports.',
      'Family safety: family links and invites, live location while you use '
          '"Share my ETA", and "I\'m Safe" marks.',
      'Other things you choose to send: messages to shelter managers, '
          'feedback, volunteer sign-ups, preparedness checklist answers '
          '(for example household size, or whether elderly or disabled '
          'people live with you), quiz results, and whether you have seen or '
          'acknowledged an alert.',
      'Records of which version of these documents you accepted and when, '
          'and any account-deletion request.',
      'On your device only: cached alerts and maps for offline use, recent '
          'activity, and accessibility/language preferences.',
    ]),
    const PolicySection('Why we use it', [
      'To run your account and the features you use: alerts for your area, '
          'incident reporting and verification, shelter information and '
          'routes, and sharing your safety status with your family.',
      'Authorities use reports, SOS alerts, alert acknowledgements and '
          'resident contact details to coordinate the disaster response and '
          'follow up with people an alert has not reached.',
      'We don\'t sell your information, show advertising, or use analytics '
          'or tracking SDKs.',
    ]),
    const PolicySection('Who can see it', [
      'Everyone using SafeZone: incident reports, including their exact '
          'location, photos and videos.',
      'Your confirmed family members: your name, your location while you '
          'share it (and the last location you shared), and your "I\'m Safe" '
          'marks — which are also emailed to them (at most once every 10 '
          'minutes). Links only become active after both people confirm, and '
          'either person can remove a link at any time.',
      'Authorities and volunteer-organisation accounts: your profile '
          '(including phone number and zone), SOS reports, feedback, messages '
          'sent to shelter managers, and whether you acknowledged alerts.',
      'Other users can see your display name in message threads.',
    ]),
    const PolicySection('Services that process data for us', [
      'Supabase — hosting, database, authentication, file storage.',
      'CARTO and OpenTopoMap — map images. Your device requests map tiles '
          'for the area on screen, which reveals that area and your IP '
          'address to the tile provider.',
      'OSRM public routing server — receives the start and end points when '
          'you ask for directions to a shelter.',
      'OpenStreetMap Nominatim — names the town or area shown on the home '
          'map. It receives your location rounded to about 1 km, and your IP '
          'address.',
      'Brevo — sends family-circle emails: the request to join your circle, '
          'and "I\'m Safe" notices to your confirmed family. These include '
          'your name and their email address.',
      'Google Fonts — the app downloads fonts from Google, which receives '
          'your IP address.',
    ]),
    const PolicySection('Device permissions', [
      'Location: used for nearby shelters, routes, incident reports and '
          'sharing your ETA. The app asks when a feature needs it; you can '
          'turn it off in your phone\'s settings.',
      'Notifications: used to deliver disaster warnings. You can turn them '
          'off in your phone\'s settings, but you may then miss warnings.',
      'Camera/photos: only when you attach evidence to a report.',
    ]),
    const PolicySection('How long we keep it', [
      'Account and profile data: until you delete your account.',
      'Incident reports, location-share history, "I\'m Safe" marks and '
          'messages: currently kept until removed by you, an authority, or '
          'account deletion — there is no automatic expiry yet. Specific '
          'retention periods are to be confirmed by the operator.',
      'Policy acceptance records are kept as proof of consent for as long '
          'as your account exists.',
    ]),
    PolicySection('Your choices and rights', [
      'View and correct your name and phone number in Settings → Edit Profile.',
      'Stop sharing your location at any time, and remove family members '
          'from Family circle.',
      'Request deletion of your account and personal data from Settings → '
          'Privacy & data. You can cancel until an authority processes it. '
          'Deletion removes your account, profile, incident reports and their '
          'photos/videos, messages you sent, feedback, family links, location '
          'history, "I\'m Safe" marks, alert receipts and consent records. '
          'Records others rely on — alerts you issued, incidents you verified, '
          'shelters you managed — are kept without your name. A record that a '
          'deletion request was completed is kept, without your identity.',
      'To request a copy of your data or raise a privacy concern: '
          '${LegalConfig.contactLabel}',
    ]),
    const PolicySection('Security', [
      'Data is sent over encrypted connections, and database rules limit '
          'each person to the data described above. No system is perfectly '
          'secure, so please keep your password private.',
    ]),
    const PolicySection('Children', [
      'SafeZone is not designed for children to register on their own. '
          'Age requirements and any parental-consent rules are to be '
          'confirmed by the operator.',
    ]),
    const PolicySection('Changes', [
      'If we change this policy materially, we\'ll show you the new version '
          'and ask you to review it before you continue using the app.',
    ]),
  ],
);

/// Documents every signed-in user must have accepted (current version).
final List<PolicyDocument> requiredPolicies = [termsOfUse, privacyPolicy];
