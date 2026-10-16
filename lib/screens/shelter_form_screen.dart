import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';
import '../services/location_service.dart';
import '../services/shelter_service.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/sri_lanka_bounds.dart';
import '../widgets/map_controls.dart';
import '../l10n/ui_text.dart';

/// One form for both filing a new shelter and editing an existing one.
///
/// - New (no [shelter]): saved as `pending`; it reaches the public Shelters
///   page only after an authority approves it.
/// - Pending / rejected: saving fixes the details and re-queues it.
/// - Approved (owner): details, status and occupancy update immediately.
class ShelterFormScreen extends StatefulWidget {
  final Shelter? shelter;

  const ShelterFormScreen({super.key, this.shelter});

  @override
  State<ShelterFormScreen> createState() => _ShelterFormScreenState();
}

class _ShelterFormScreenState extends State<ShelterFormScreen> {
  static const _types = [
    ('shelter', 'Shelter'),
    ('relief_camp', 'Relief camp'),
    ('medical_point', 'Medical point'),
  ];
  static const _statuses = [
    ('open', 'Open'),
    ('full', 'Full'),
    ('closed', 'Closed'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _service = ShelterService();
  final _mapController = MapController();

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _capacity;
  late final TextEditingController _occupancy;

  late String _type;
  late String _status;
  LatLng _location = const LatLng(6.9271, 79.8612);

  /// Set once the user taps the map, so a late GPS fix cannot move their pin.
  bool _pinSetManually = false;
  bool _saving = false;
  bool _locating = false;

  bool get _editing => widget.shelter != null;
  bool get _approved => widget.shelter?.approval == ShelterApproval.approved;

  @override
  void initState() {
    super.initState();
    final s = widget.shelter;
    _name = TextEditingController(text: s?.name);
    _address = TextEditingController(text: s?.address);
    _description = TextEditingController(text: s?.description);
    _phone = TextEditingController(text: s?.contactPhone);
    _capacity = TextEditingController(text: s?.capacity?.toString() ?? '');
    _occupancy = TextEditingController(text: s?.occupancy?.toString() ?? '0');
    _type = _types.any((t) => t.$1 == s?.type) ? s!.type! : 'shelter';
    _status = _statuses.any((t) => t.$1 == s?.status) ? s!.status! : 'open';
    if (s != null) {
      _location = LatLng(s.latitude, s.longitude);
      _pinSetManually = true;
    } else {
      // A new shelter starts at the submitter's real position.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useMyLocation(silent: true),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _description,
      _phone,
      _capacity,
      _occupancy,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useMyLocation({bool silent = false}) async {
    setState(() => _locating = true);
    // Any failed lookup counts as no location so the indicator clears.
    final LatLng? here = await LocationService()
        .getCurrentLocation()
        .catchError((_) => null);
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Couldn\'t get your location. Tap the map to set it.'),
            ),
          ),
        );
      }
      return;
    }
    if (silent && _pinSetManually) return;
    setState(() {
      _location = here;
      _pinSetManually = !silent;
    });
    _mapController.move(here, 15);
  }

  String? _validatePhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null; // optional
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length < 7 || digits.length > 15
        ? 'Enter a valid phone number'
        : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final capacity = int.parse(_capacity.text.trim());
      if (_editing) {
        await _service.updateShelter(
          widget.shelter!.id,
          name: _name.text.trim(),
          type: _type,
          latitude: _location.latitude,
          longitude: _location.longitude,
          capacity: capacity,
          address: orNull(_address),
          description: orNull(_description),
          contactPhone: orNull(_phone),
          status: _approved ? _status : null,
          occupancy: _approved ? int.parse(_occupancy.text.trim()) : null,
        );
      } else {
        await _service.submitShelter(
          name: _name.text.trim(),
          type: _type,
          latitude: _location.latitude,
          longitude: _location.longitude,
          capacity: capacity,
          address: orNull(_address),
          description: orNull(_description),
          contactPhone: orNull(_phone),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Couldn\'t save the shelter: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = !_editing
        ? 'Submit a shelter'
        : _approved
        ? 'Edit shelter'
        : 'Update submission';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!_approved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.tintSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_outlined, color: context.brandInk),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(context.tr('An authority will verify this shelter before it appears on the public Shelters page. You can follow its status under Manage your shelter.'),
                        style: TextStyle(color: context.brandInk),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.tr('Shelter name *')),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Enter the shelter name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: context.tr('Type')),
              items: [
                for (final t in _types)
                  DropdownMenuItem(value: t.$1, child: Text(t.$2)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.tr('Address (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr('About this shelter (optional)'),
                hintText: context.tr('Facilities, access, who it is for'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('Emergency desk phone (optional)'),
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Capacity (people) *'),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) {
                  return 'Enter how many people it can hold';
                }
                if (n > 100000) return 'That looks too high';
                return null;
              },
            ),
            if (_approved) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _occupancy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('People sheltered now'),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return n == null || n < 0 ? 'Enter 0 or more' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: context.tr('Status')),
                      items: [
                        for (final s in _statuses)
                          DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(context.tr('Location *'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(context.tr('Starts at your current position. Tap the map to move the pin.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Semantics(
              label: context.tr('Map for choosing the shelter location. Tap the map to move the pin, or use the My location button to place it at your position.'),
              child: SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _location,
                          initialZoom: 14,
                          minZoom: kSriLankaMinZoom,
                          cameraConstraint: kSriLankaCameraConstraint,
                          maxZoom: 18,
                          onTap: (_, point) => setState(() {
                            _location = point;
                            _pinSetManually = true;
                          }),
                        ),
                        children: [
                          buildBaseTileLayer(BaseMapStyle.street),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _location,
                                width: 44,
                                height: 44,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: AppColors.severityRed,
                                  size: 44,
                                ),
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
            const SizedBox(height: 6),
            Row(
              children: [
                if (_locating) ...[
                  const Icon(Icons.gps_not_fixed, size: 16),
                  const SizedBox(width: 8),
                  Text(context.tr('Finding your location…'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else
                  Text(
                    '${_location.latitude.toStringAsFixed(5)}, ${_location.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      !_editing
                          ? 'Submit for review'
                          : _approved
                          ? 'Save changes'
                          : 'Save and resubmit',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
