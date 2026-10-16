import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/zone.dart';
import '../l10n/app_strings.dart';
import '../providers/accessibility_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../services/coordination_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/validators.dart';
import '../widgets/feedback_sheet.dart';
import 'admin_broadcast_screen.dart';
import 'admin_incident_review_screen.dart';
import 'incidents_screen.dart';
import 'deletion_requests_screen.dart';
import 'manage_shelter_screen.dart';
import 'messages_screen.dart';
import 'shelter_submissions_screen.dart';
import 'privacy_settings_screen.dart';
import 'volunteer_tasks_screen.dart';
import '../widgets/a11y/a11y_widgets.dart';
import '../widgets/about_footer.dart';
import '../l10n/ui_text.dart';
import '../utils/error_messages.dart';

/// Settings screen tailored for both [UserRole.member] (Citizens) and
/// [UserRole.authority] / [UserRole.admin] / [UserRole.volunteerOrg].
class SettingsScreen extends StatefulWidget {
  final AppUser? currentUser;
  final List<Zone> zones;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    this.currentUser,
    this.zones = const [],
    this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  /// Local value while the broadcast-radius slider is being dragged, so it
  /// doesn't round-trip through [AlertProvider]/SharedPreferences on every
  /// pixel of movement — committed via [Slider.onChangeEnd].
  double? _draftBroadcastRadiusKm;

  bool _syncingCache = false;

  /// Unread shelter messages, shown as a badge on the Messages row.
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadMessages();
  }

  Future<void> _loadUnreadMessages() async {
    final count = await CoordinationService().fetchUnreadCount();
    if (mounted && count != _unreadMessages) setState(() => _unreadMessages = count);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final isAuthority = user?.role.isAuthority ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Settings & Profile')),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ─── Profile Header Card ───────────────────────────────────────
            _buildProfileCard(context, user, isAuthority, isDark),
            const SizedBox(height: 20),

            // ─── Authority Management Section ─────────────────────────────
            if (isAuthority) ...[
              _buildSectionHeader('Authority Command Center', Icons.security),
              const SizedBox(height: 8),
              _buildAuthorityPanel(context, user!),
              const SizedBox(height: 20),
            ],

            // ─── Appearance ────────────────────────────────────────────────
            _buildSectionHeader('Appearance', Icons.palette_outlined),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    key: const Key('theme_mode_selector'),
                    // The tick icon on the selected segment pushed "System"
                    // out of its box; the filled segment already shows the
                    // selection, so drop it and tighten the padding.
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      // 48dp tall, like every other tap target; the default
                      // density is kept (compact dropped it below 48).
                      minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
                    ),
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(context.tr('Light'))),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(context.tr('System'))),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(context.tr('Dark'))),
                      ),
                    ],
                    selected: {context.watch<AccessibilityProvider>().themeMode},
                    onSelectionChanged: (s) =>
                        context.read<AccessibilityProvider>().setThemeMode(s.first),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Language, data saver, captions, glare contrast and haptics were
            // only reachable from admin screens; everyone gets them here.
            Card(
              child: ListTile(
                key: const Key('inclusion_settings_tile'),
                leading: Icon(Icons.visibility_outlined, color: context.brandInk),
                title: Text(appStringsOf(context).t('inclusionTitle')),
                subtitle: Text(appStringsOf(context).t('inclusionSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showA11yInclusionSheet(context),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Emergency & Alert Preferences ────────────────────────────
            _buildSectionHeader('Emergency & Warning Notifications', Icons.notifications_active_outlined),
            const SizedBox(height: 8),
            _buildNotificationSettingsCard(context, isAuthority),
            const SizedBox(height: 20),

            // ─── Safety & Offline Data ─────────────────────────────────────
            _buildSectionHeader('Safety & Offline Resilience', Icons.health_and_safety_outlined),
            const SizedBox(height: 8),
            _buildSafetyAndDataCard(context),
            const SizedBox(height: 20),

            // ─── Community & Support ───────────────────────────────────────
            _buildSectionHeader('Community & Support', Icons.forum_outlined),
            const SizedBox(height: 8),
            _buildCommunityCard(context),
            const SizedBox(height: 20),

            // ─── Emergency Contacts / Hotlines ─────────────────────────────
            _buildSectionHeader('Emergency Hotlines (Sri Lanka)', Icons.phone_in_talk_outlined),
            const SizedBox(height: 8),
            _buildHotlinesCard(context),
            const SizedBox(height: 20),

            // ─── Privacy & Data ────────────────────────────────────────────
            _buildSectionHeader('Privacy & Data', Icons.privacy_tip_outlined),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                key: const Key('privacy_settings_tile'),
                leading: Icon(Icons.privacy_tip_outlined, color: context.brandInk),
                title: Text(context.tr('Privacy & data')),
                subtitle: Text(context.tr('Policies, what you share, app tour, delete account')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ─── Logout Button ─────────────────────────────────────────────
            _buildLogoutButton(context),
            const SizedBox(height: 24),
            const AboutFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Profile Header ────────────────────────────────────────────────────────

  Widget _buildProfileCard(
    BuildContext context,
    AppUser? user,
    bool isAuthority,
    bool isDark,
  ) {
    String email = 'Unknown account';
    try {
      email = SupabaseService.client.auth.currentUser?.email ?? 'Unknown account';
    } catch (_) {}
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : 'U';

    final roleLabel = switch (user?.role) {
      UserRole.authority => 'Disaster Management Authority',
      UserRole.admin => 'System Administrator',
      UserRole.volunteerOrg => 'Volunteer Organization',
      UserRole.member => 'Verified Citizen Member',
      null => 'Civilian',
    };

    final roleBadgeColor = isAuthority ? context.brandAccent : context.brandInk;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.harborSurface : AppColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAuthority
              ? AppColors.riverTeal.withValues(alpha: 0.35)
              : AppColors.deepEstuary.withValues(alpha: 0.15),
          width: isAuthority ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.deepEstuary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: roleBadgeColor.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: roleBadgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName
                          : 'Early-Warning Citizen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.foamText.withValues(alpha: 0.7)
                                : AppColors.slateMuted,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (user?.phone.isNotEmpty == true && !looksLikeAccountId(user!.phone))
                      Text(
                        user.phone,
                        style: AppTheme.dataText(context).copyWith(
                          fontSize: 12,
                          color: isDark ? AppColors.foamText : context.inkMuted,
                        ),
                      )
                    else if (user != null)
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(context, user),
                        child: Text(context.tr('Add a phone number'),
                          style: AppTheme.dataText(context).copyWith(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.severityOrange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: context.tr('Edit Profile'),
                onPressed: () => _showEditProfileDialog(context, user),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Wrap rather than Row: a long role label ("Disaster Management
          // Authority") plus the Broadcast Ready badge don't fit on one line.
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAuthority ? Icons.verified_user : Icons.person_outline,
                      size: 16,
                      color: roleBadgeColor,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: roleBadgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isAuthority)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.severityOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign, size: 13, color: AppColors.severityOrange),
                        SizedBox(width: 4),
                        Text(context.tr('Broadcast Ready'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.severityOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Authority Panel ───────────────────────────────────────────────────────

  Widget _buildAuthorityPanel(BuildContext context, AppUser user) {
    final alertProvider = context.watch<AlertProvider>();
    final draftRadiusKm =
        _draftBroadcastRadiusKm ?? alertProvider.defaultBroadcastRadiusMeters / 1000;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.broadcast_on_personal,
                    color: context.brandAccent, size: 20),
                const SizedBox(width: 8),
                Text(context.tr('Emergency Broadcast Controls'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            // Auto-escalate SOS and direct relay toggles were removed: they
            // saved a preference that no code acted on, so authorities could
            // believe escalation was happening when it wasn't.
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('Default Broadcast Radius'),
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(context.tr('{p0} km', {'p0': draftRadiusKm.toStringAsFixed(1)}),
                  style: AppTheme.dataText(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.brandAccent,
                  ),
                ),
              ],
            ),
            Slider(
              min: 1.0,
              max: 25.0,
              divisions: 24,
              value: draftRadiusKm,
              activeColor: context.brandAccent,
              onChanged: (v) => setState(() => _draftBroadcastRadiusKm = v),
              onChangeEnd: (v) {
                setState(() => _draftBroadcastRadiusKm = null);
                alertProvider.setDefaultBroadcastRadiusMeters((v * 1000).round());
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brandAccent,
                side: BorderSide(color: context.brandAccent),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.campaign, size: 18),
              label: Text(context.tr('Create New Broadcast Alert')),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminBroadcastScreen(
                       currentUser: user,
                      zones: widget.zones,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.riverTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(context.tr('Review Citizen Incident Reports')),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminIncidentReviewScreen(
                      currentUser: user,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('deletion_requests_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brandInk,
                side: BorderSide(color: context.brandInk),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: Text(context.tr('Account Deletion Requests')),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeletionRequestsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('shelter_submissions_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brandInk,
                side: BorderSide(color: context.brandInk),
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.night_shelter_outlined, size: 18),
              label: const Text('Shelter Submissions'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShelterSubmissionsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Notification Settings ─────────────────────────────────────────────────

  Widget _buildNotificationSettingsCard(BuildContext context, bool isAuthority) {
    final alertProvider = context.watch<AlertProvider>();
    final myZoneOnly = alertProvider.myZoneOnly;
    final effectiveZoneId = alertProvider.userZoneId ?? widget.currentUser?.zoneId;
    final currentZone = widget.zones.where((z) => z.id == effectiveZoneId).firstOrNull;
    final zoneName = currentZone?.name;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final multiChannelFallback = alertProvider.multiChannelFallback;

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            key: const Key('my_zone_alerts_only_switch'),
            title: Text(context.tr('My Zone Alerts Only')),
            subtitle: Text(
              myZoneOnly
                  ? (zoneName != null
                      ? 'Only showing and notifying alerts for $zoneName'
                      : 'Only showing and notifying alerts for your designated zone')
                  : 'Receive disaster alerts for all monitored zones',
            ),
            value: myZoneOnly,
            onChanged: (enabled) async {
              String? targetZoneId = effectiveZoneId;
              if (enabled && targetZoneId == null && widget.zones.isNotEmpty) {
                targetZoneId = widget.zones.first.id;
              }
              await alertProvider.setMyZoneOnly(enabled, zoneId: targetZoneId);
              if (enabled && targetZoneId != null && SupabaseService.currentUserId != null) {
                try {
                  await SupabaseService.client
                      .from('profiles')
                      .update({'zone_id': targetZoneId})
                      .eq('id', SupabaseService.currentUserId!);
                  widget.onProfileUpdated?.call();
                } catch (_) {}
              }
            },
          ),
          if (myZoneOnly && widget.zones.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: DropdownButtonFormField<String>(
                key: const Key('designated_zone_dropdown'),
                initialValue: widget.zones.any((z) => z.id == effectiveZoneId)
                    ? effectiveZoneId
                    : widget.zones.first.id,
                decoration: InputDecoration(
                  labelText: context.tr('Designated Safety Zone'),
                  prefixIcon: Icon(Icons.location_on, color: context.brandAccent),
                  filled: true,
                  fillColor: isDark ? AppColors.harborSurface : AppColors.cloud,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: widget.zones.map((z) => DropdownMenuItem(
                  value: z.id,
                  child: Text(z.name),
                )).toList(),
                onChanged: (newZoneId) async {
                  if (newZoneId != null) {
                    await alertProvider.setUserZoneId(newZoneId);
                    final userId = SupabaseService.currentUserId;
                    if (userId != null) {
                      try {
                        await SupabaseService.client
                            .from('profiles')
                            .update({'zone_id': newZoneId})
                            .eq('id', userId);
                        widget.onProfileUpdated?.call();
                      } catch (_) {}
                    }
                  }
                },
              ),
            ),
          ],
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: Text(context.tr('Critical Flood Siren Override')),
            subtitle: Text(
              alertProvider.sirenOverride
                  ? 'Emergency-level alerts play an alarm siren and bypass Do Not Disturb'
                  : 'Emergency-level alerts arrive as a normal notification, silent mode and Do Not Disturb apply',
            ),
            value: alertProvider.sirenOverride,
            onChanged: (v) => alertProvider.setSirenOverride(v),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: Text(context.tr('Early-Warning Push Alerts')),
            subtitle: Text(
              alertProvider.pushAlertsEnabled
                  ? 'Receiving real-time push notifications for alerts in your district'
                  : 'Push notifications are off — you\'ll only see alerts inside the app',
            ),
            value: alertProvider.pushAlertsEnabled,
            onChanged: (v) => alertProvider.setPushAlertsEnabled(v),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            key: const Key('multi_channel_fallback_switch'),
            title: Text(context.tr('Multi-Channel Alert Fallback')),
            subtitle: Text(
              multiChannelFallback
                  ? 'Active: Alerts will automatically fall back to SMS backup and in-app alerts if push notifications fail'
                  : 'Delivers alerts through multiple channels with automatic fallback if primary notification fails',
            ),
            value: multiChannelFallback,
            onChanged: (enabled) => alertProvider.setMultiChannelFallback(enabled),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.severityRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.severityRed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.do_not_disturb_on_total_silence,
                          size: 20, color: AppColors.severityRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(context.tr('Red critical alerts are configured to bypass Do Not Disturb via dedicated high-priority alarm channels.'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Stacked, not side by side: two labelled buttons in one row
                // wrapped unevenly on narrow phones and looked misaligned.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.security, size: 18),
                        label: Text(
                          context.tr('DND Access Settings'),
                          style: TextStyle(fontSize: 13),
                        ),
                        onPressed: () async {
                          await NotificationService()
                              .requestNotificationPolicyAccess();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Checking system notification and Do Not Disturb settings...'),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.severityRed,
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.volume_up, size: 18),
                        label: Text(
                          context.tr('Test Critical Siren'),
                          style: TextStyle(fontSize: 13),
                        ),
                        onPressed: () async {
                          final testAlert = DisasterAlert(
                            id: 'test_critical_${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Flash Flood Emergency Simulation',
                            alertType: 'flood',
                            severity: AlertSeverity.red,
                            status: AlertStatus.active,
                            centerLat: 6.9271,
                            centerLng: 79.8612,
                            radiusMeters: 3000,
                            instructions:
                                'TEST ALERT: Critical flood alert bypasses Do Not Disturb. Evacuate low-lying riverbanks immediately.',
                            source: 'Disaster Management Centre',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          // Open the full-screen critical alert (siren,
                          // vibration, shelter and 119 buttons) so the whole
                          // experience can be tried without publishing, then
                          // post the notification; a notification failure
                          // must not hide the screen.
                          context
                              .read<AlertProvider>()
                              .previewCriticalTakeover(testAlert);
                          // Needed on Android 14+ for the lock-screen version.
                          await NotificationService.requestFullScreenIntentPermission();
                          try {
                            await NotificationService()
                                .showCriticalAlert(testAlert);
                          } catch (_) {}

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Triggered Test Critical Siren notification (bypass DND)'),
                                ),
                                backgroundColor: AppColors.severityRed,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Safety & Data Resilience ──────────────────────────────────────────────

  Widget _buildSafetyAndDataCard(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    String? currentUserId;
    try {
      currentUserId = SupabaseService.currentUserId;
    } catch (_) {}

    final myIncidentsCount = context
        .watch<IncidentProvider>()
        .incidents
        .where((i) => currentUserId != null && i.reporterId == currentUserId)
        .length;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person_pin_circle_outlined, color: context.brandInk),
            title: Text(context.tr('My Reported Incidents')),
            subtitle: Text(context.tr('View, edit details, or resolve your incident reports')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.brandInk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$myIncidentsCount',
                    style: AppTheme.dataText(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.brandInk,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () {
              context.read<IncidentProvider>().clearFilters();
              context.read<IncidentProvider>().setMyReportsFilter(true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IncidentsScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.cached_outlined, color: context.brandInk),
            title: Text(context.tr('Offline Safe-Zone Maps Cache')),
            subtitle: Text(context.tr('Stores district flood zones and evacuation shelters offline')),
            trailing: TextButton(
              onPressed: _syncingCache
                  ? null
                  : () => _syncOfflineCache(context, alertProvider),
              child: _syncingCache
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Sync Cache')),
            ),
          ),
        ],
      ),
    );
  }

  /// Downloads street + topo map tiles around the citizen's designated
  /// zone (falling back to the app's default district centre) so the map
  /// keeps working offline, using the same [TileCacheService] the map
  /// screens already read from.
  Future<void> _syncOfflineCache(
    BuildContext context,
    AlertProvider alertProvider,
  ) async {
    final effectiveZoneId = alertProvider.userZoneId ?? widget.currentUser?.zoneId;
    final zone = widget.zones.where((z) => z.id == effectiveZoneId).firstOrNull;
    final center = (zone?.centroidLat != null && zone?.centroidLng != null)
        ? LatLng(zone!.centroidLat!, zone.centroidLng!)
        : const LatLng(6.9615, 79.9010); // default district centre

    setState(() => _syncingCache = true);
    try {
      final bounds = LatLngBounds(center, center);
      await safeZoneTileCache.prefetchRoute(
        bounds,
        style: BaseMapStyle.street,
        bufferKilometres: 5,
      );
      await safeZoneTileCache.prefetchRoute(
        bounds,
        style: BaseMapStyle.topo,
        bufferKilometres: 5,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              zone != null
                  ? 'Offline map cache refreshed for ${zone.name}.'
                  : 'Offline map cache refreshed for your default district.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Failed to sync offline cache: {e}', {'e': context.tr(friendlyError(e))})),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCache = false);
    }
  }

  // ─── Community & Support ───────────────────────────────────────────────────

  Widget _buildCommunityCard(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    final zoneId = alertProvider.userZoneId ?? widget.currentUser?.zoneId;
    return Card(
      child: Column(
        children: [
          ListTile(
            key: const Key('manage_shelter_tile'),
            leading: Icon(Icons.night_shelter_outlined, color: context.brandInk),
            title: Text(context.tr('Manage your shelter')),
            subtitle: Text(context.tr('Submit a shelter for approval or manage one you run')),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageShelterScreen(currentUser: widget.currentUser),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.chat_bubble_outline, color: context.brandInk),
            title: const Text('Messages'),
            subtitle: const Text('Conversations with shelter managers'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unreadMessages > 0)
                  Semantics(
                    label: '$_unreadMessages unread',
                    child: Badge(label: Text('$_unreadMessages')),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              );
              _loadUnreadMessages();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.volunteer_activism_outlined, color: context.brandInk),
            title: Text(context.tr('Volunteer')),
            subtitle: Text(context.tr('Sign up to help at shelters near you')),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VolunteerTasksScreen(zones: widget.zones),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.rate_review_outlined, color: context.brandInk),
            title: Text(context.tr('Give feedback')),
            subtitle: Text(context.tr('Rate the support you\'re getting and tell us what you need')),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => showFeedbackSheet(context, zoneId: zoneId),
          ),
        ],
      ),
    );
  }

  // ─── Emergency Hotlines ────────────────────────────────────────────────────

  Widget _buildHotlinesCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildHotlineRow(
            context,
            title: context.tr('Disaster Management Centre (DMC)'),
            number: '117',
            description: context.tr('24/7 Flood & Emergency Hotline'),
          ),
          const Divider(height: 1),
          _buildHotlineRow(
            context,
            title: context.tr('Police Emergency Hotline'),
            number: '119',
            description: context.tr('Immediate Rescue Assistance'),
          ),
          const Divider(height: 1),
          _buildHotlineRow(
            context,
            title: context.tr('Ambulance & Medical Emergency'),
            number: '1990',
            description: context.tr('Suwa Seriya Pre-Hospital Care'),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineRow(
    BuildContext context, {
    required String title,
    required String number,
    required String description,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.severityRed.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.phone, color: AppColors.severityRed, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.brandInk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          number,
          style: AppTheme.dataText(context).copyWith(
            fontWeight: FontWeight.bold,
            color: context.brandInk,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── Logout Button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.severityRed,
        side: BorderSide(color: AppColors.severityRed.withValues(alpha: 0.5), width: 1.5),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(Icons.logout, size: 20),
      label: Text(context.tr('Sign Out'),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _confirmLogout(context),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Sign out?')),
        content: Text(context.tr('Are you sure you want to sign out of your SafeZone account?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.severityRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Sign out')),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  // ─── Edit Profile Dialog ───────────────────────────────────────────────────

  Future<void> _showEditProfileDialog(BuildContext context, AppUser? user) async {
    final formKey = GlobalKey<FormState>();
    // A profile created before sign-up finished (e.g. email confirmation
    // still pending when the account was made) can be left with a
    // placeholder phone — the new user's own id, so `phone` still
    // satisfies the database's NOT NULL UNIQUE constraint. Never
    // pre-fill that back into the form as if it were real.
    final storedPhone = user?.phone ?? '';
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(
      text: looksLikeAccountId(storedPhone) ? '' : storedPhone,
    );
    bool saving = false;
    String? submitError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('Edit Profile'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr('Full Name'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => validateFullName(v, tr: context.tr),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone Number'),
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => validatePhone(v, tr: context.tr),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                if (submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    submitError!,
                    style: const TextStyle(color: AppColors.severityRed, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setModalState(() => submitError = null);
                          if (!(formKey.currentState?.validate() ?? false)) return;

                          final newName = nameCtrl.text.trim();
                          final newPhone = normalizePhone(phoneCtrl.text)!;

                          setModalState(() => saving = true);
                          try {
                            final userId = SupabaseService.currentUserId;
                            if (userId != null) {
                              await SupabaseService.client
                                  .from('profiles')
                                  .update({
                                'full_name': newName,
                                'phone': newPhone,
                              }).eq('id', userId);
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              widget.onProfileUpdated?.call();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('Profile updated successfully.')),
                                ),
                              );
                            }
                          } catch (e) {
                            // Postgres unique-violation on profiles.phone —
                            // give a plain-English reason instead of the
                            // raw Postgrest error text.
                            final isDuplicatePhone =
                                e.toString().contains('23505');
                            setModalState(() {
                              saving = false;
                              submitError = isDuplicatePhone
                                  ? 'That phone number is already registered to another account.'
                                  : 'Failed to update profile: $e';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('Save Changes')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.brandInk),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
