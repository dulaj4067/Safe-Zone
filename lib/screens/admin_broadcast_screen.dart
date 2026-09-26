import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/alert_form_provider.dart';
import '../theme/app_colors.dart';

/// Story 3: authority-only screen for creating a geo-targeted broadcast.
/// Guard access to this route at the navigation layer too (e.g. only show
/// the entry point/FAB when currentUser.role.isAuthority is true) — this
/// widget assumes it's only reachable by an authority user, and relies on
/// the "Authority can insert alerts" RLS policy as the real enforcement.
class AdminBroadcastScreen extends StatefulWidget {
  final AppUser currentUser;
  final List<Zone> zones;

  const AdminBroadcastScreen({
    super.key,
    required this.currentUser,
    required this.zones,
  });

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.role.isAuthority) {
      // Client-side gate per Story 3 AC. RLS blocks the insert regardless.
      return Scaffold(
        appBar: AppBar(title: const Text('New Alert')),
        body: const Center(
          child: Text('You do not have permission to create alerts.'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AlertFormProvider(),
      child: _BroadcastForm(zones: widget.zones),
    );
  }
}

class _BroadcastForm extends StatelessWidget {
  final List<Zone> zones;
  const _BroadcastForm({required this.zones});

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AlertFormProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('New Broadcast Alert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(),
            ),
            onChanged: context.read<AlertFormProvider>().updateTitle,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Alert type',
              border: OutlineInputBorder(),
            ),
            initialValue: form.alertType,
            items: const [
              DropdownMenuItem(value: 'flood', child: Text('Flood')),
              DropdownMenuItem(value: 'landslide', child: Text('Landslide')),
              DropdownMenuItem(value: 'cyclone', child: Text('Cyclone')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) context.read<AlertFormProvider>().updateAlertType(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AlertSeverity>(
            decoration: const InputDecoration(
              labelText: 'Severity *',
              border: OutlineInputBorder(),
            ),
            initialValue: form.severity,
            items: AlertSeverity.values.map((s) {
              return DropdownMenuItem(value: s, child: Text(s.label));
            }).toList(),
            onChanged: (v) {
              if (v != null) context.read<AlertFormProvider>().updateSeverity(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Zone>(
            decoration: const InputDecoration(
              labelText: 'Affected zone *',
              helperText: 'Or drop a custom point on the map below',
              border: OutlineInputBorder(),
            ),
            initialValue: form.selectedZone,
            items: zones.map((z) {
              return DropdownMenuItem(value: z, child: Text(z.name));
            }).toList(),
            onChanged: (z) => context.read<AlertFormProvider>().selectZone(z),
          ),
          const SizedBox(height: 12),
          const Text(
            'Or tap the map to set a custom center point:',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(7.4167, 81.8206), // defaults near Zone A
                  zoom: 11,
                ),
                onTap: (latLng) {
                  context.read<AlertFormProvider>().setCustomCenter(
                        latLng.latitude,
                        latLng.longitude,
                      );
                },
                markers: form.customLat != null
                    ? {
                        Marker(
                          markerId: const MarkerId('custom_center'),
                          position: LatLng(form.customLat!, form.customLng!),
                        ),
                      }
                    : {},
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Radius: ${form.radiusMeters} m'),
          Slider(
            min: 500,
            max: 10000,
            divisions: 19,
            value: form.radiusMeters.toDouble(),
            label: '${form.radiusMeters} m',
            onChanged: (v) =>
                context.read<AlertFormProvider>().updateRadius(v.round()),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Instructions',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            onChanged: context.read<AlertFormProvider>().updateInstructions,
          ),
          const SizedBox(height: 20),

          // ─── Broadcast Delivery Channels Section ─────────────────────────────
          _buildDeliveryChannelsCard(context, form),
          const SizedBox(height: 20),

          if (form.submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                form.submitError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('broadcast_submit_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepEstuary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: form.isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.campaign),
              // Story 3 AC: submission disabled until required fields are set.
              onPressed: (!form.isValid || form.isSubmitting)
                  ? null
                  : () async {
                      final success = await form.submit();
                      if (success && context.mounted) {
                        final result = form.lastDispatchResult;
                        final message = result != null
                            ? 'Broadcast sent: ${result.summary}.'
                            : 'Alert broadcast sent across selected channels.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: AppColors.deepEstuary,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
              label: Text(
                form.isSubmitting
                    ? 'Dispatching broadcast...'
                    : (form.selectedChannelsCount == 3
                        ? 'Dispatch Broadcast (All 3 Channels)'
                        : 'Dispatch Broadcast (${form.selectedChannelsCount} Channel${form.selectedChannelsCount == 1 ? '' : 's'})'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryChannelsCard(BuildContext context, AlertFormProvider form) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cell_tower, size: 20, color: AppColors.deepEstuary),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Channels',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.slateInk,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: form.selectedChannelsCount == 3
                          ? AppColors.severityGreen.withValues(alpha: 0.15)
                          : AppColors.riverTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      form.selectedChannelsCount == 3
                          ? 'All Channels Active'
                          : '${form.selectedChannelsCount}/3 Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: form.selectedChannelsCount == 3
                            ? AppColors.severityGreen
                            : AppColors.riverTeal,
                      ),
                    ),
                  ),
                  if (form.selectedChannelsCount < 3) ...[
                    const SizedBox(width: 6),
                    TextButton(
                      key: const Key('select_all_channels_btn'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => context.read<AlertFormProvider>().selectAllChannels(),
                      child: const Text('Select All', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Simultaneously dispatch across online, cellular, and acoustic channels to guarantee reach regardless of citizen connectivity:',
            style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),

          // Channel 1: Push Notification
          _buildChannelTile(
            context,
            key: const Key('channel_push_tile'),
            title: 'Push Notification',
            subtitle: 'Instant in-app alerts and OS-level lock screen notifications',
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.riverTeal,
            value: form.dispatchPush,
            onChanged: (v) => context.read<AlertFormProvider>().togglePush(v ?? false),
          ),
          const SizedBox(height: 8),

          // Channel 2: SMS Cellular Broadcast
          _buildChannelTile(
            context,
            key: const Key('channel_sms_tile'),
            title: 'SMS Cellular Broadcast',
            subtitle: 'Offline fallback message sent to residents without mobile data',
            icon: Icons.sms_outlined,
            iconColor: AppColors.severityOrange,
            value: form.dispatchSms,
            onChanged: (v) => context.read<AlertFormProvider>().toggleSms(v ?? false),
          ),
          const SizedBox(height: 8),

          // Channel 3: Siren-Trigger Channel
          _buildChannelTile(
            context,
            key: const Key('channel_siren_tile'),
            title: 'Siren-Trigger Channel',
            subtitle: 'Acoustic sirens and high-priority DND override audio alarm',
            icon: Icons.volume_up_outlined,
            iconColor: AppColors.severityRed,
            value: form.dispatchSiren,
            onChanged: (v) => context.read<AlertFormProvider>().toggleSiren(v ?? false),
          ),

          if (!form.hasSelectedChannel)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ Please select at least one delivery channel to dispatch the broadcast.',
                style: TextStyle(
                  color: AppColors.severityRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      key: key,
      color: value ? Colors.white : Colors.grey.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: value
              ? AppColors.riverTeal.withValues(alpha: 0.35)
              : Colors.grey.shade300,
          width: value ? 1.5 : 1.0,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.deepEstuary,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        secondary: CircleAvatar(
          radius: 18,
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: value ? AppColors.slateInk : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: value ? AppColors.slateMuted : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

