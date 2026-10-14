import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/zone.dart';
import '../providers/accessibility_provider.dart';
import '../providers/alert_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

/// First-run guide: what SafeZone does, the user's home area, and why the
/// app wants notifications and location — explained before the system asks.
///
/// Every step except the welcome is skippable; progress is saved so an
/// interrupted onboarding resumes on the same step. Onboarding is only
/// marked complete when the user reaches the end. With [replay] (from
/// Settings → App tour) nothing is saved and it simply closes at the end.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final bool replay;
  final OnboardingService? service;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.replay = false,
    this.service,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 4;

  late final OnboardingService _service = widget.service ?? OnboardingService();
  final PageController _pages = PageController();
  int _step = 0;
  bool _finishing = false;
  bool _isAuthority = false;

  List<Zone> _zones = [];
  bool _zonesLoading = true;
  String? _zonesError;
  String? _selectedZoneId;
  bool _savingZone = false;
  String? _zoneSavedMessage;

  bool? _notificationsGranted;
  bool? _locationGranted;

  String? get _userId => SupabaseService.currentUserId;

  @override
  void initState() {
    super.initState();
    _restore();
    _loadZones();
    ProfileService.currentUserRole().then((role) {
      if (mounted) setState(() => _isAuthority = role?.isAuthority ?? false);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final uid = _userId;
    if (widget.replay || uid == null) return;
    final saved = (await _service.savedStep(uid)).clamp(0, _stepCount - 1);
    if (!mounted || saved == 0) return;
    setState(() => _step = saved);
    _pages.jumpToPage(saved);
  }

  Future<void> _loadZones() async {
    setState(() {
      _zonesLoading = true;
      _zonesError = null;
    });
    try {
      final rows = await SupabaseService.client.from('zones').select().order('name');
      final zones = (rows as List).map((z) => Zone.fromMap(z as Map<String, dynamic>)).toList();
      String? current;
      final uid = _userId;
      if (uid != null) {
        final me = await SupabaseService.client
            .from('profiles')
            .select('zone_id')
            .eq('id', uid)
            .maybeSingle();
        current = me?['zone_id'] as String?;
      }
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _selectedZoneId = zones.any((z) => z.id == current) ? current : null;
        _zonesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _zonesLoading = false;
        _zonesError = 'obAreasError';
      });
    }
  }

  Future<void> _goTo(int step) async {
    final target = step.clamp(0, _stepCount - 1);
    setState(() => _step = target);
    await _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    final uid = _userId;
    if (!widget.replay && uid != null) await _service.saveStep(uid, target);
  }

  Future<void> _saveZone(String zoneId) async {
    final uid = _userId;
    if (uid == null) return;
    setState(() {
      _selectedZoneId = zoneId;
      _savingZone = true;
      _zoneSavedMessage = null;
    });
    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .update({'zone_id': zoneId})
          .eq('id', uid)
          .select('id');
      requireRowsAffected(rows, 'save your area');
      if (mounted) await context.read<AlertProvider>().setUserZoneId(zoneId);
      if (mounted) setState(() => _zoneSavedMessage = 'obSaved');
    } catch (_) {
      if (mounted) {
        setState(() => _zoneSavedMessage = 'obSaveFailed');
      }
    } finally {
      if (mounted) setState(() => _savingZone = false);
    }
  }

  Future<void> _allowNotifications() async {
    final granted = await NotificationService().requestPermissions();
    final uid = _userId;
    if (uid != null) await _service.setNotificationsDeclined(uid, false);
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _skipNotifications() async {
    final uid = _userId;
    if (uid != null) await _service.setNotificationsDeclined(uid, true);
    if (mounted) setState(() => _notificationsGranted = false);
  }

  Future<void> _allowLocation() async {
    final granted = await LocationService().ensurePermission();
    if (mounted) setState(() => _locationGranted = granted);
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final uid = _userId;
    if (!widget.replay && uid != null) await _service.complete(uid);
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _stepCount - 1;
    final strings = appStringsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Semantics(
                    label: adminStringsOf(context).stepOf(_step + 1, _stepCount),
                    child: Row(
                      children: [
                        for (var i = 0; i < _stepCount; i++)
                          Container(
                            width: i == _step ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: i <= _step ? context.brandInk : AppColors.hairlineStrong,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    Flexible(
                      child: TextButton(
                        onPressed: _finishing ? null : () => _goTo(_stepCount - 1),
                        child: Text(strings.t('obSkip')),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcomePage(context),
                  _areaPage(context),
                  _permissionsPage(context),
                  _readyPage(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // Flexible lets long translations wrap instead of overflowing.
                  if (_step > 0)
                    Flexible(
                      child: TextButton(
                        onPressed: _finishing ? null : () => _goTo(_step - 1),
                        child: Text(strings.t('obBack')),
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('onboarding_next'),
                      onPressed: _finishing ? null : (isLast ? _finish : () => _goTo(_step + 1)),
                      child: Text(
                        isLast
                            ? strings.t(widget.replay ? 'obDone' : 'obStart')
                            : strings.t('obNext'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context, {required IconData icon, required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        Icon(icon, size: 44, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _feature(IconData icon, String title, String body) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: context.brandAccent),
        title: Text(title),
        subtitle: Text(body),
      );

  static const _languages = [
    ('en', 'English'),
    ('si', 'සිංහල'),
    ('ta', 'தமிழ்'),
    ('ar', 'العربية'),
  ];

  /// Language choice, first thing on the welcome page, so someone who can't
  /// read the default English can switch before reading anything else.
  /// Hidden when there's no [AccessibilityProvider] (some tests).
  Widget _languagePicker(BuildContext context) {
    AccessibilityProvider? a11y;
    try {
      a11y = Provider.of<AccessibilityProvider>(context);
    } catch (_) {}
    if (a11y == null) return const SizedBox.shrink();
    final provider = a11y;
    final strings = appStringsOf(context);
    return Semantics(
      container: true,
      label: strings.t('obLanguage'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, name) in _languages)
              ChoiceChip(
                label: Text(name),
                selected: provider.localeCode == code,
                onSelected: (_) => provider.setLocaleCode(code),
              ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(BuildContext context) {
    final strings = appStringsOf(context);
    return _page(
      context,
      icon: Icons.shield_outlined,
      title: strings.t('obWelcome'),
      children: [
        _languagePicker(context),
        Text(strings.t('obIntro')),
        const SizedBox(height: 12),
        _feature(Icons.campaign_outlined, strings.t('obWarnings'), strings.t('obWarningsBody')),
        _feature(Icons.report_outlined, strings.t('obReport'), strings.t('obReportBody')),
        _feature(Icons.night_shelter_outlined, strings.t('obShelters'), strings.t('obSheltersBody')),
        _feature(Icons.family_restroom_outlined, strings.t('obFamily'), strings.t('obFamilyBody')),
        if (_isAuthority)
          _feature(Icons.admin_panel_settings_outlined, strings.t('obAuthority'),
              strings.t('obAuthorityBody')),
        const SizedBox(height: 8),
        Text(
          strings.t('obDisclaimer'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _areaPage(BuildContext context) {
    final strings = appStringsOf(context);
    return _page(
      context,
      icon: Icons.location_city_outlined,
      title: strings.t('obArea'),
      children: [
        Text(strings.t('obAreaBody')),
        const SizedBox(height: 16),
        if (_zonesLoading)
          const Center(child: CircularProgressIndicator())
        else if (_zonesError != null) ...[
          Text(strings.t(_zonesError!), style: const TextStyle(color: AppColors.severityRed)),
          TextButton(onPressed: _loadZones, child: Text(strings.t('obTryAgain'))),
        ] else if (_zones.isEmpty)
          Text(strings.t('obNoAreas'))
        else
          DropdownButtonFormField<String>(
            key: const Key('onboarding_zone_dropdown'),
            initialValue: _selectedZoneId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.t('obHomeArea'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final z in _zones)
                DropdownMenuItem(value: z.id, child: Text(z.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _savingZone ? null : (id) => id == null ? null : _saveZone(id),
          ),
        if (_zoneSavedMessage != null) ...[
          const SizedBox(height: 8),
          Text(strings.t(_zoneSavedMessage!)),
        ],
      ],
    );
  }

  Widget _permissionsPage(BuildContext context) {
    final strings = appStringsOf(context);
    return _page(
      context,
      icon: Icons.notifications_active_outlined,
      title: strings.t('obReachable'),
      children: [
        Text(strings.t('obReachableBody')),
        const SizedBox(height: 16),
        _permissionCard(
          icon: Icons.notifications_outlined,
          title: strings.t('obNotifications'),
          body: strings.t('obNotificationsBody'),
          granted: _notificationsGranted,
          onAllow: _allowNotifications,
          onSkip: _skipNotifications,
        ),
        const SizedBox(height: 12),
        _permissionCard(
          icon: Icons.my_location,
          title: strings.t('obLocation'),
          body: strings.t('obLocationBody'),
          granted: _locationGranted,
          onAllow: _allowLocation,
          onSkip: () => setState(() => _locationGranted = false),
        ),
      ],
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String body,
    required bool? granted,
    required Future<void> Function() onAllow,
    required VoidCallback onSkip,
  }) {
    final strings = appStringsOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: context.brandAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 8),
            if (granted == null)
              Wrap(spacing: 8, children: [
                FilledButton.tonal(onPressed: onAllow, child: Text(strings.t('obAllow'))),
                TextButton(onPressed: onSkip, child: Text(strings.t('obNotNow'))),
              ])
            else
              Text(
                strings.t(granted ? 'obAllowed' : 'obNotAllowed'),
                style: TextStyle(
                  color: granted ? AppColors.severityGreen : context.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _readyPage(BuildContext context) {
    final strings = appStringsOf(context);
    return _page(
      context,
      icon: Icons.check_circle_outline,
      title: strings.t('obReady'),
      children: [
        Text(strings.t('obNext3')),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.group_add_outlined),
          title: Text(strings.t('obInvite')),
          subtitle: Text(strings.t('obInvitePath')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_for_offline_outlined),
          title: Text(strings.t('obOffline')),
          subtitle: Text(strings.t('obOfflinePath')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(strings.t('obPrivacy')),
          subtitle: Text(strings.t('obPrivacyPath')),
        ),
      ],
    );
  }
}
