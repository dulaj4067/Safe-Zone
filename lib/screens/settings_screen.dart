import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
  // Member preferences
  bool _sirenOverride = true;
  bool _pushAlerts = true;
  bool _smsBackup = false;
  bool _liveLocationBeacon = true;

  // Authority preferences
  bool _autoEscalateSos = true;
  bool _autoRelayDispatch = false;
  double _defaultBroadcastRadius = 5.0;

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
    final email = SupabaseService.client.auth.currentUser?.email ?? 'Unknown account';
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
                    if (user?.phone.isNotEmpty == true)
                      Text(
                        user!.phone,
                        style: AppTheme.dataText(context).copyWith(
                          fontSize: 12,
                          color: isDark ? AppColors.foamText : AppColors.slateMuted,
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
              onChanged: (v) => setState(() => _autoEscalateSos = v),
            ),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Direct Disaster Relay'),
              subtitle: const Text(
                'Forward verified critical alerts to regional disaster responder units',
              ),
              value: _autoRelayDispatch,
              onChanged: (v) => setState(() => _autoRelayDispatch = v),
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
                  '${_defaultBroadcastRadius.toStringAsFixed(1)} km',
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
              value: _defaultBroadcastRadius,
              activeColor: AppColors.riverTeal,
              onChanged: (v) => setState(() => _defaultBroadcastRadius = v),
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
    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Critical Flood Siren Override'),
            subtitle: const Text(
              'Play audible sirens for Emergency level flood alerts even if device is on silent',
            ),
            value: _sirenOverride,
            onChanged: (v) => setState(() => _sirenOverride = v),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Early-Warning Push Alerts'),
            subtitle: const Text(
              'Receive real-time notifications for rising water levels in your district',
            ),
            value: _pushAlerts,
            onChanged: (v) => setState(() => _pushAlerts = v),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('SMS Backup Warnings'),
            subtitle: const Text(
              'Send SMS text alerts if data connectivity is lost during an active storm',
            ),
            value: _smsBackup,
            onChanged: (v) => setState(() => _smsBackup = v),
          ),
        ],
      ),
    );
  }

  // ─── Safety & Data Resilience ──────────────────────────────────────────────

  Widget _buildSafetyAndDataCard(BuildContext context) {
    final myIncidentsCount = context
        .watch<IncidentProvider>()
        .incidents
        .where((i) => i.reporterId == SupabaseService.currentUserId)
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
            onChanged: (v) => setState(() => _liveLocationBeacon = v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cached_outlined, color: AppColors.deepEstuary),
            title: const Text('Offline Safe-Zone Maps Cache'),
            subtitle: const Text('Stores district flood zones and evacuation shelters offline'),
            trailing: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Offline map cache refreshed successfully.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Sync Cache'),
            ),
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
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    bool saving = false;

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
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        final newPhone = phoneCtrl.text.trim();
                        if (newName.isEmpty) return;

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
                          setModalState(() => saving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update profile: $e'),
                                backgroundColor: AppColors.severityRed,
                              ),
                            );
                          }
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
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

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
