import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../l10n/admin_strings.dart';
import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/zone.dart';
import '../providers/accessibility_provider.dart';
import '../providers/alert_form_provider.dart';
import '../services/location_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/map_controls.dart';
import '../providers/alert_provider.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/sri_lanka_bounds.dart';
import '../widgets/a11y/a11y_widgets.dart';

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
      final strings = adminStringsOf(context);
      return Scaffold(
        appBar: AppBar(title: Text(strings.t('broadcastTitle'))),
        body: Center(child: Text(strings.t('noPermission'))),
      );
    }

    AlertProvider? alertProvider;
    try {
      alertProvider = context.read<AlertProvider>();
    } catch (_) {}

    return ChangeNotifierProvider(
      create: (context) => AlertFormProvider(
        initialRadiusMeters:
            alertProvider?.defaultBroadcastRadiusMeters ?? 2000,
      ),
      child: _BroadcastForm(zones: widget.zones),
    );
  }
}

class _BroadcastForm extends StatefulWidget {
  final List<Zone> zones;
  const _BroadcastForm({required this.zones});

  @override
  State<_BroadcastForm> createState() => _BroadcastFormState();
}

class _BroadcastFormState extends State<_BroadcastForm> {
  int _step = 0;
  final MapController _mapController = MapController();
  bool _usingGps = false;
  late final TextEditingController _title;
  late final TextEditingController _instructions;
  late final TextEditingController _transcript;

  // Built once: a new MapOptions on every form rebuild makes flutter_map
  // re-apply its options and the camera jumps away from where it was.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: const LatLng(7.4167, 81.8206),
    initialZoom: 11,
    minZoom: kSriLankaMinZoom,
    cameraConstraint: kSriLankaCameraConstraint,
    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
    onTap: (_, latLng) {
      _usingGps = false;
      context.read<AlertFormProvider>().setCustomCenter(
        latLng.latitude,
        latLng.longitude,
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _instructions = TextEditingController();
    _transcript = TextEditingController();
    // Pre-fill the target with the sender's GPS position when nothing has
    // been chosen yet; they can still pick a zone or tap another spot.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _useMyLocation(silent: true),
    );
  }

  Future<void> _useMyLocation({bool silent = false}) async {
    final form = context.read<AlertFormProvider>();
    if (silent && (form.selectedZone != null || form.customLat != null)) return;
    final here = await LocationService().getCurrentLocation();
    if (!mounted) return;
    if (here == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appStringsOf(context).t('locationUnavailable')),
          ),
        );
      }
      return;
    }
    // A zone or pin chosen while the fix was pending wins over the GPS guess.
    if (silent && (form.selectedZone != null || form.customLat != null)) return;
    form.setCustomCenter(here.latitude, here.longitude);
    _mapController.move(here, 13);
    setState(() => _usingGps = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _submit(AlertFormProvider form) async {
    final success = await form.submit();
    if (!success || !mounted) return;
    try {
      await context.read<AccessibilityProvider>().pulseHaptic();
    } catch (_) {}
    if (!mounted) return;
    final result = form.lastDispatchResult;
    final message = result != null
        ? 'Broadcast sent: ${result.summary}.'
        : 'Alert broadcast sent across selected channels.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.brandFill,
        duration: const Duration(seconds: 4),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AlertFormProvider>();
    final strings = adminStringsOf(context);

    return Shortcuts(
      shortcuts: const {submitBroadcastShortcut: SubmitBroadcastIntent()},
      child: Actions(
        actions: {
          SubmitBroadcastIntent: CallbackAction<SubmitBroadcastIntent>(
            onInvoke: (_) {
              if (_step == 1 && form.isValid && !form.isSubmitting) {
                _submit(form);
              } else if (_step == 0) {
                setState(() => _step = 1);
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(strings.t('broadcastTitle')),
            actions: const [A11yInclusionButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              A11yStepHeader(
                current: _step + 1,
                total: 2,
                label: strings.stepOf(_step + 1, 2),
                stepTitle: _step == 0
                    ? strings.t('stepDetails')
                    : strings.t('stepDelivery'),
              ),
              if (_step == 0) ..._buildStepDetails(context, form, strings),
              if (_step == 1) ..._buildStepDelivery(context, form, strings),
              const SizedBox(height: 16),
              if (form.submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: A11yErrorBanner(
                    message: form.submitError!,
                    hint: strings.t('howToFix'),
                  ),
                ),
              if (_step == 0)
                FilledButton(
                  onPressed: () => setState(() => _step = 1),
                  child: Text(strings.t('next')),
                )
              else ...[
                OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: Text(strings.t('back')),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('broadcast_submit_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.brandFill,
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
                        : const Icon(
                            Icons.campaign,
                            semanticLabel: 'Broadcast',
                          ),
                    onPressed: (!form.isValid || form.isSubmitting)
                        ? null
                        : () => _submit(form),
                    label: Text(
                      form.isSubmitting
                          ? 'Dispatching broadcast...'
                          : (form.selectedChannelsCount == 3
                                ? 'Dispatch Broadcast (All 3 Channels)'
                                : 'Dispatch Broadcast (${form.selectedChannelsCount} Channel${form.selectedChannelsCount == 1 ? '' : 's'})'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.t('shortcutSubmit'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStepDetails(
    BuildContext context,
    AlertFormProvider form,
    AdminStrings strings,
  ) {
    return [
      TextField(
        controller: _title,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: '${strings.t('titleLabel')} *',
          hintText: strings.t('titleHint'),
          helperText: strings.t('titleRequired'),
          border: const OutlineInputBorder(),
        ),
        onChanged: context.read<AlertFormProvider>().updateTitle,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: strings.t('alertType'),
          border: const OutlineInputBorder(),
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
        decoration: InputDecoration(
          labelText: '${strings.t('severity')} *',
          border: const OutlineInputBorder(),
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
        decoration: InputDecoration(
          labelText: '${strings.t('zone')} *',
          border: const OutlineInputBorder(),
        ),
        initialValue: form.selectedZone,
        items: widget.zones.map((z) {
          return DropdownMenuItem(value: z, child: Text(z.name));
        }).toList(),
        onChanged: (z) => context.read<AlertFormProvider>().selectZone(z),
      ),
      const SizedBox(height: 12),
      Text(strings.t('zoneHint'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Semantics(
        label: strings.t('mapAlt'),
        child: SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // flutter_map + the app's Carto tiles, like every other map in
            // the app — GoogleMap here needed its own Android API key.
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: _mapOptions,
                  children: [
                    buildBaseTileLayer(BaseMapStyle.street),
                    if (form.customLat != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(form.customLat!, form.customLng!),
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.severityRed,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(
                          attributionFor(BaseMapStyle.street),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: MyLocationButton(onTap: () => _useMyLocation()),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_usingGps && form.customLat != null) ...[
        const SizedBox(height: 6),
        Text(
          appStringsOf(context).t('usingMyLocation'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _buildStepDelivery(
    BuildContext context,
    AlertFormProvider form,
    AdminStrings strings,
  ) {
    var captions = true;
    try {
      captions = context.watch<AccessibilityProvider>().captionsEnabled;
    } catch (_) {}

    return [
      Text('${strings.t('radius')}: ${form.radiusMeters} m'),
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
        controller: _instructions,
        decoration: InputDecoration(
          labelText: strings.t('instructions'),
          hintText: strings.t('instructionsHint'),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: 4,
        onChanged: context.read<AlertFormProvider>().updateInstructions,
      ),
      if (captions) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _transcript,
          decoration: InputDecoration(
            labelText: strings.t('transcript'),
            hintText: strings.t('transcriptHint'),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          onChanged: context.read<AlertFormProvider>().updateAudioTranscript,
        ),
      ],
      const SizedBox(height: 16),
      _buildDeliveryChannelsCard(context, form),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildDeliveryChannelsCard(
    BuildContext context,
    AlertFormProvider form,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceSoft,
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
                  Icon(
                    Icons.cell_tower,
                    size: 20,
                    color: context.brandInk,
                    semanticLabel: 'Delivery channels',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Channels',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.inkStrong,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                      onPressed: () =>
                          context.read<AlertFormProvider>().selectAllChannels(),
                      child: const Text(
                        'Select All',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simultaneously dispatch across online, cellular, and acoustic channels to guarantee reach regardless of citizen connectivity:',
            style: TextStyle(fontSize: 12, color: context.inkMuted),
          ),
          const SizedBox(height: 12),

          // Channel 1: Push Notification
          _buildChannelTile(
            context,
            key: const Key('channel_push_tile'),
            title: 'Push Notification',
            subtitle:
                'Instant in-app alerts and OS-level lock screen notifications',
            icon: Icons.notifications_active_outlined,
            iconColor: context.brandAccent,
            value: form.dispatchPush,
            onChanged: (v) =>
                context.read<AlertFormProvider>().togglePush(v ?? false),
          ),
          const SizedBox(height: 8),

          // Channel 2: SMS Cellular Broadcast
          _buildChannelTile(
            context,
            key: const Key('channel_sms_tile'),
            title: 'SMS Cellular Broadcast',
            subtitle:
                'Offline fallback message sent to residents without mobile data',
            icon: Icons.sms_outlined,
            iconColor: AppColors.severityOrange,
            value: form.dispatchSms,
            onChanged: (v) =>
                context.read<AlertFormProvider>().toggleSms(v ?? false),
          ),
          const SizedBox(height: 8),

          // Channel 3: Siren-Trigger Channel
          _buildChannelTile(
            context,
            key: const Key('channel_siren_tile'),
            title: 'Siren-Trigger Channel',
            subtitle:
                'Acoustic sirens and high-priority DND override audio alarm',
            icon: Icons.volume_up_outlined,
            iconColor: AppColors.severityRed,
            value: form.dispatchSiren,
            onChanged: (v) =>
                context.read<AlertFormProvider>().toggleSiren(v ?? false),
          ),

          if (!form.hasSelectedChannel)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: A11yErrorBanner(
                message: adminStringsOf(context).t('needChannel'),
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
        activeColor: context.brandInk,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        secondary: CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 20, semanticLabel: title),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: value ? context.inkStrong : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: value ? context.inkMuted : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
