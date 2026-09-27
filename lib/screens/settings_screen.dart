import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import 'admin_broadcast_screen.dart';
import 'admin_incident_review_screen.dart';
import 'incidents_screen.dart';

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
  final SettingsService _settingsService = SettingsService();

  // These three have no functional consumer yet (see SettingsService's
  // doc comment) — persisted so the toggle survives a restart, but they
  // don't turn any real feature on or off.
  bool _liveLocationBeacon = true;
  bool _autoEscalateSos = true;
  bool _autoRelayDispatch = false;

  /// Local value while the broadcast-radius slider is being dragged, so it
  /// doesn't round-trip through [AlertProvider]/SharedPreferences on every
  /// pixel of movement — committed via [Slider.onChangeEnd].
  double? _draftBroadcastRadiusKm;

  bool _syncingCache = false;

  @override
  void initState() {
    super.initState();
    _loadUnwiredPreferences();
  }

  Future<void> _loadUnwiredPreferences() async {
    final beacon = await _settingsService.getLiveLocationBeacon();
    final escalate = await _settingsService.getAutoEscalateSos();
    final relay = await _settingsService.getAutoRelayDispatch();
    if (!mounted) return;
    setState(() {
      _liveLocationBeacon = beacon;
      _autoEscalateSos = escalate;
      _autoRelayDispatch = relay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final isAuthority = user?.role.isAuthority ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
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

            // ─── Emergency Contacts / Hotlines ─────────────────────────────
            _buildSectionHeader('Emergency Hotlines (Sri Lanka)', Icons.phone_in_talk_outlined),
            const SizedBox(height: 8),
            _buildHotlinesCard(context),
            const SizedBox(height: 20),

            // ─── System & About ────────────────────────────────────────────
            _buildSectionHeader('Network & System Status', Icons.info_outline),
            const SizedBox(height: 8),
            _buildSystemStatusCard(context),
            const SizedBox(height: 28),

            // ─── Logout Button ─────────────────────────────────────────────
            _buildLogoutButton(context),
            const SizedBox(height: 32),
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

    final roleBadgeColor = isAuthority
        ? AppColors.riverTeal
        : AppColors.deepEstuary;

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
                    if (user?.phone.isNotEmpty == true && !_looksLikeUuid(user!.phone))
                      Text(
                        user.phone,
                        style: AppTheme.dataText(context).copyWith(
                          fontSize: 12,
                          color: isDark ? AppColors.foamText : AppColors.slateMuted,
                        ),
                      )
                    else if (user != null)
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(context, user),
                        child: Text(
                          'Add a phone number',
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
                tooltip: 'Edit Profile',
                onPressed: () => _showEditProfileDialog(context, user),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
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
              const Spacer(),
              if (isAuthority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.severityOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign, size: 13, color: AppColors.severityOrange),
                      SizedBox(width: 4),
                      Text(
                        'Broadcast Ready',
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
                const Icon(Icons.broadcast_on_personal,
                    color: AppColors.riverTeal, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Emergency Broadcast Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Escalate High-Risk SOS'),
              subtitle: const Text(
                'Automatically flag incidents with 3+ citizen confirmations for instant review',
              ),
              value: _autoEscalateSos,
              onChanged: (v) {
                setState(() => _autoEscalateSos = v);
                _settingsService.saveAutoEscalateSos(v);
              },
            ),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Direct Disaster Relay'),
              subtitle: const Text(
                'Forward verified critical alerts to regional disaster responder units',
              ),
              value: _autoRelayDispatch,
              onChanged: (v) {
                setState(() => _autoRelayDispatch = v);
                _settingsService.saveAutoRelayDispatch(v);
              },
            ),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Default Broadcast Radius',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${draftRadiusKm.toStringAsFixed(1)} km',
                  style: AppTheme.dataText(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.riverTeal,
                  ),
                ),
              ],
            ),
            Slider(
              min: 1.0,
              max: 25.0,
              divisions: 24,
              value: draftRadiusKm,
              activeColor: AppColors.riverTeal,
              onChanged: (v) => setState(() => _draftBroadcastRadiusKm = v),
              onChangeEnd: (v) {
                setState(() => _draftBroadcastRadiusKm = null);
                alertProvider.setDefaultBroadcastRadiusMeters((v * 1000).round());
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.riverTeal,
                side: const BorderSide(color: AppColors.riverTeal),
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.campaign, size: 18),
              label: const Text('Create New Broadcast Alert'),
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
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Review Citizen Incident Reports'),
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
            title: const Text('My Zone Alerts Only'),
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
                  labelText: 'Designated Safety Zone',
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.riverTeal),
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
            title: const Text('Critical Flood Siren Override'),
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
            title: const Text('Early-Warning Push Alerts'),
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
            title: const Text('Multi-Channel Alert Fallback'),
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
                        child: Text(
                          'Red critical alerts are configured to bypass Do Not Disturb via dedicated high-priority alarm channels.',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text(
                          'DND Access Settings',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          await NotificationService()
                              .requestNotificationPolicyAccess();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Checking system notification and Do Not Disturb settings...',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.severityRed,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text(
                          'Test Critical Siren',
                          style: TextStyle(fontSize: 12),
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

                          await NotificationService()
                              .showCriticalAlert(testAlert);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Triggered Test Critical Siren notification (bypass DND)',
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
            leading: const Icon(Icons.person_pin_circle_outlined, color: AppColors.deepEstuary),
            title: const Text('My Reported Incidents'),
            subtitle: const Text('View, edit details, or resolve your incident reports'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.deepEstuary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$myIncidentsCount',
                    style: AppTheme.dataText(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepEstuary,
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
              context.read<IncidentProvider>().setViewMode(IncidentViewMode.list);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IncidentsScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Live GPS Safety Beacon'),
            subtitle: const Text(
              'Attach high-accuracy coordinates when submitting SOS flood reports',
            ),
            value: _liveLocationBeacon,
            onChanged: (v) {
              setState(() => _liveLocationBeacon = v);
              _settingsService.saveLiveLocationBeacon(v);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cached_outlined, color: AppColors.deepEstuary),
            title: const Text('Offline Safe-Zone Maps Cache'),
            subtitle: const Text('Stores district flood zones and evacuation shelters offline'),
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
                  : const Text('Sync Cache'),
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
            content: Text('Failed to sync offline cache: $e'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCache = false);
    }
  }

  // ─── Emergency Hotlines ────────────────────────────────────────────────────

  Widget _buildHotlinesCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildHotlineRow(
            context,
            title: 'Disaster Management Centre (DMC)',
            number: '117',
            description: '24/7 Flood & Emergency Hotline',
          ),
          const Divider(height: 1),
          _buildHotlineRow(
            context,
            title: 'Police Emergency Hotline',
            number: '119',
            description: 'Immediate Rescue Assistance',
          ),
          const Divider(height: 1),
          _buildHotlineRow(
            context,
            title: 'Ambulance & Medical Emergency',
            number: '1990',
            description: 'Suwa Seriya Pre-Hospital Care',
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
          color: AppColors.deepEstuary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          number,
          style: AppTheme.dataText(context).copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.deepEstuary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── System Status ─────────────────────────────────────────────────────────

  Widget _buildSystemStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.severityGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Early-Warning Network Active',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  'v1.0.0',
                  style: AppTheme.dataText(context).copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connected Node',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Supabase Realtime Gateway',
                  style: AppTheme.dataText(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
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
      label: const Text(
        'Sign Out',
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
        title: const Text('Sign out?'),
        content: const Text(
          'Are you sure you want to sign out of your SafeZone account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.severityRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
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
      text: _looksLikeUuid(storedPhone) ? '' : storedPhone,
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
                Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _validateFullName,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validatePhoneNumber,
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
                          final newPhone = phoneCtrl.text.trim();

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
                                const SnackBar(
                                  content: Text('Profile updated successfully.'),
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
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value.trim());

  String? _validateFullName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Full name is required';
    if (trimmed.length < 2) return 'Name is too short';
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Phone number is required';
    if (_looksLikeUuid(trimmed)) {
      return 'That looks like an account ID, not a phone number';
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(digitsOnly)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.deepEstuary),
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
