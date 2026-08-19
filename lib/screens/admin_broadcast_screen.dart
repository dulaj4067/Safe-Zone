import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/alert_form_provider.dart';

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
            child: FilledButton(
              // Story 3 AC: submission disabled until required fields are set.
              onPressed: (!form.isValid || form.isSubmitting)
                  ? null
                  : () async {
                      final success = await form.submit();
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Alert broadcast sent.')),
                        );
                        Navigator.pop(context);
                      }
                    },
              child: form.isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Broadcast alert'),
            ),
          ),
        ],
      ),
    );
  }
}
