import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/map_controls.dart';
import '../widgets/incident_card.dart';
import 'incident_detail_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const ReportIncidentScreen({super.key, this.initialLocation});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  IncidentCategory _selectedCategory = IncidentCategory.waterlogging;
  LatLng _selectedLocation = const LatLng(6.9615, 79.9010);
  bool _isSos = false;
  File? _photoFile;
  File? _videoFile;
  String? _videoFileName;
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

  // ── Inline duplicate warning ───────────────────────────────────────────────
  /// Set whenever the form's category or pin location matches a nearby active
  /// incident. Cleared when the banner is dismissed or the inputs change away.
  Incident? _nearbyDuplicate;
  bool _dismissedInlineBanner = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Inline proximity check ────────────────────────────────────────────────

  /// Re-evaluates the duplicate banner after any form field change.
  /// Does nothing when the banner has been manually dismissed by the citizen.
  void _checkDuplicateInline() {
    if (_dismissedInlineBanner) return;
    final provider = context.read<IncidentProvider>();
    final found = provider.checkForDuplicate(
      category: _selectedCategory,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );
    if (found?.id != _nearbyDuplicate?.id) {
      setState(() {
        _nearbyDuplicate = found;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _photoFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked != null) {
        setState(() {
          _videoFile = File(picked.path);
          _videoFileName = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  void _showMediaSourceSheet({required bool isVideo}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVideo ? 'Attach Video Evidence' : 'Attach Photo Evidence',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(isVideo ? 'Record Video' : 'Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isVideo) {
                    _pickVideo(ImageSource.camera);
                  } else {
                    _pickImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(isVideo ? 'Choose from Gallery' : 'Choose Photo from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isVideo) {
                    _pickVideo(ImageSource.gallery);
                  } else {
                    _pickImage(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Duplicate-aware submit flow ───────────────────────────────────────────

  /// Entry point wired to the Submit button. Checks for a nearby duplicate
  /// first; if one is found, shows [_DuplicateDialog] instead of submitting.
  Future<void> _checkDuplicateThenSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<IncidentProvider>();
    final duplicate = provider.checkForDuplicate(
      category: _selectedCategory,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );

    if (!mounted) return;

    if (duplicate != null) {
      // A nearby same-category active report already exists — let the citizen
      // decide whether to confirm it, still report separately, or cancel.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DuplicateDialog(
          duplicate: duplicate,
          reportLocation: _selectedLocation,
          onConfirmExisting: () => _confirmExistingAndNavigate(duplicate),
          onReportAnyway: _doSubmit,
        ),
      );
    } else {
      await _doSubmit();
    }
  }

  /// Called when the citizen taps "Confirm existing": adds a credibility vote
  /// to the existing incident (via the confirmations table) then navigates to it.
  ///
  /// Guards against double-confirmation: if the user has already confirmed this
  /// incident we skip the insert and navigate directly with an informational
  /// message instead of letting Supabase throw a unique-constraint error.
  Future<void> _confirmExistingAndNavigate(Incident existing) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    final provider = context.read<IncidentProvider>();

    // ── Guard: has this user already confirmed this incident? ────────────────
    final alreadyConfirmed = await provider.hasUserConfirmed(
      incidentId: existing.id,
      userId: uid,
    );
    if (!mounted) return;

    if (alreadyConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You've already confirmed this report — your vote is counted!",
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.riverTeal,
          duration: Duration(seconds: 3),
        ),
      );
      // Still navigate to the existing incident so the citizen can see it.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incident: existing),
        ),
      );
      return;
    }

    // ── Normal path: add confirmation ────────────────────────────────────────
    try {
      await provider.confirmIncident(
        incidentId: existing.id,
        memberId: uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thanks! Your confirmation has been added to the existing report.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.severityGreen,
          duration: const Duration(seconds: 4),
        ),
      );
      // Navigate to the existing incident, replacing the form so Back goes home.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incident: existing),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not confirm: $e'),
          backgroundColor: AppColors.severityRed,
        ),
      );
    }
  }

  /// The actual Supabase submission — called either directly (no duplicate) or
  /// after the citizen chooses "Report Anyway" in the duplicate dialog.
  Future<void> _doSubmit() async {
    final provider = context.read<IncidentProvider>();
    final success = await provider.submitIncident(
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      isSos: _isSos,
      photoFile: _photoFile,
      videoFile: _videoFile,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isSos
                        ? 'Emergency SOS reported! Awaiting priority verification.'
                        : 'Incident reported successfully. Awaiting admin verification.',
                  ),
                ),
              ],
            ),
            backgroundColor: _isSos ? AppColors.severityRed : AppColors.severityGreen,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Failed to submit report. Please try again.',
            ),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<IncidentProvider>().isSubmitting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Emergency SOS Switch Card ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _isSos
                    ? (isDark
                        ? AppColors.severityRed.withValues(alpha: 0.2)
                        : AppColors.sosBackground)
                    : (isDark ? AppColors.harborSurface : AppColors.cloud),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isSos ? AppColors.severityRed : AppColors.deepEstuary.withValues(alpha: 0.15),
                  width: _isSos ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSos ? AppColors.severityRed : Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _isSos ? Colors.white : AppColors.slateMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "I'm Trapped / Emergency SOS",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Flags this report as critical high-priority rescue emergency',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isSos,
                    activeTrackColor: AppColors.severityRed.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.severityRed,
                    onChanged: (val) {
                      setState(() {
                        _isSos = val;
                        if (val) {
                          _selectedCategory = IncidentCategory.trappedPerson;
                        }
                        // Reset inline banner so it re-evaluates for the new
                        // category after SOS toggle.
                        _dismissedInlineBanner = false;
                        _nearbyDuplicate = null;
                      });
                      _checkDuplicateInline();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ─── Incident Category Dropdown ───────────────────────────────
            DropdownButtonFormField<IncidentCategory>(
              decoration: const InputDecoration(
                labelText: 'Incident Category *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              initialValue: _selectedCategory,
              items: IncidentCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(categoryIcon(cat), color: categoryColor(cat), size: 18),
                      const SizedBox(width: 10),
                      Text(cat.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (cat) {
                if (cat != null) {
                  setState(() {
                    _selectedCategory = cat;
                    // Reset dismissed state so the banner can re-appear for
                    // the newly selected category.
                    _dismissedInlineBanner = false;
                    _nearbyDuplicate = null;
                  });
                  _checkDuplicateInline();
                }
              },
            ),
            const SizedBox(height: 16),

            // ─── Description Multiline Field ──────────────────────────────
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Explain what happened, water depth, roadblocks, or trapped individuals...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.description_outlined),
                ),
              ),
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please provide a short description';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ─── Location Picker (Map) ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Incident Location *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Tap map to set pin',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 14,
                        minZoom: 5,
                        maxZoom: 18,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLocation = point;
                            // Let the banner re-evaluate for the new pin.
                            _dismissedInlineBanner = false;
                            _nearbyDuplicate = null;
                          });
                          _checkDuplicateInline();
                        },
                      ),
                      children: [
                        buildBaseTileLayer(_baseMapStyle),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 44,
                              height: 44,
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
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.harborSurface : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text(
                          '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                          style: AppTheme.dataText(context).copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Column(
                        children: [
                          MapLayerToggleButton(
                            style: _baseMapStyle,
                            onTap: () {
                              setState(() {
                                _baseMapStyle = _baseMapStyle == BaseMapStyle.street
                                    ? BaseMapStyle.topo
                                    : BaseMapStyle.street;
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          ZoomButton(
                            icon: Icons.add,
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          ZoomButton(
                            icon: Icons.remove,
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Photo & Video Evidence Upload ───────────────────────────
            const Text(
              'Evidence (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Photo button / preview
                Expanded(
                  child: _photoFile == null
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Add Photo'),
                          onPressed: () => _showMediaSourceSheet(isVideo: false),
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _photoFile!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => setState(() => _photoFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                // Video button / preview
                Expanded(
                  child: _videoFile == null
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Add Video'),
                          onPressed: () => _showMediaSourceSheet(isVideo: true),
                        )
                      : Container(
                          height: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.harborSurface : AppColors.seafoam.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.riverTeal),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.video_file, color: AppColors.deepEstuary, size: 32),
                                    const SizedBox(height: 4),
                                    Text(
                                      _videoFileName ?? 'Video selected',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _videoFile = null;
                                    _videoFileName = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Inline proximity banner ───────────────────────────────────
            if (_nearbyDuplicate != null && !_dismissedInlineBanner)
              _ProximityBanner(
                duplicate: _nearbyDuplicate!,
                reportLocation: _selectedLocation,
                onView: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          IncidentDetailScreen(incident: _nearbyDuplicate!),
                    ),
                  );
                },
                onDismiss: () =>
                    setState(() => _dismissedInlineBanner = true),
              ),

            // ─── Submit Button ─────────────────────────────────────────────
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _isSos ? AppColors.severityRed : AppColors.deepEstuary,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: isSubmitting ? null : _checkDuplicateThenSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isSos ? 'SUBMIT EMERGENCY SOS REPORT' : 'SUBMIT INCIDENT REPORT',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Newly submitted reports will begin as Pending verification by authorities.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duplicate-detection dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Shown when [ReportIncidentScreen] detects that an active incident of the
/// same category already exists near the citizen's chosen location.
///
/// Three outcomes:
///  - **Confirm existing**: add a credibility vote; navigate to that incident.
///  - **Report anyway**: submit the new incident as usual.
///  - **Cancel**: dismiss and return to the form.
class _DuplicateDialog extends StatelessWidget {
  final Incident duplicate;
  final LatLng reportLocation;
  final VoidCallback onConfirmExisting;
  final VoidCallback onReportAnyway;

  const _DuplicateDialog({
    required this.duplicate,
    required this.reportLocation,
    required this.onConfirmExisting,
    required this.onReportAnyway,
  });

  /// Haversine distance in metres between [reportLocation] and [duplicate].
  double _distanceMetres() {
    const r = 6371000.0;
    final lat1 = reportLocation.latitude * math.pi / 180;
    final lat2 = duplicate.latitude * math.pi / 180;
    final dLat =
        (duplicate.latitude - reportLocation.latitude) * math.pi / 180;
    final dLon =
        (duplicate.longitude - reportLocation.longitude) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = categoryColor(duplicate.category);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.severityOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.merge_type_rounded,
                    color: AppColors.severityOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Similar Report Found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Existing incident summary card ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.harborSurface
                    : color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(categoryIcon(duplicate.category),
                          color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          duplicate.category.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Confirmations badge
                      if (duplicate.credibilityScore > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.riverTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.riverTeal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_outlined,
                                  size: 12, color: AppColors.riverTeal),
                              const SizedBox(width: 3),
                              Text(
                                '${duplicate.credibilityScore}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.riverTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (duplicate.description != null &&
                      duplicate.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      duplicate.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo(duplicate.createdAt),
                        style:
                            AppTheme.dataText(context).copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.near_me_outlined,
                          size: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '~${distanceLabel(_distanceMetres())} away',
                        style:
                            AppTheme.dataText(context).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'A nearby ${duplicate.category.label.toLowerCase()} report already exists. '
              'Would you like to confirm it (adds credibility) or still file a new report?',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────────
            // Primary: confirm existing
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepEstuary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
              label: const Text('Confirm Existing Report'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirmExisting();
              },
            ),
            const SizedBox(height: 8),

            // Secondary: report anyway
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side:
                    const BorderSide(color: AppColors.deepEstuary, width: 1.5),
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Still File a New Report'),
              onPressed: () {
                Navigator.of(context).pop();
                onReportAnyway();
              },
            ),
            const SizedBox(height: 8),

            // Tertiary: cancel
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// Inline proximity banner
// ────────────────────────────────────────────────────────────────────────────────

/// Compact amber banner shown inline (above the submit button) while the
/// citizen is filling the form, whenever [checkForDuplicate] finds a match.
///
/// Lets the citizen:
///  - **View** the existing incident (opens its detail screen without losing
///    the draft form — they can press Back to return).
///  - **Dismiss** the banner and continue editing (the banner re-appears if
///    they change category or move the pin to a new match).
class _ProximityBanner extends StatelessWidget {
  final Incident duplicate;
  final LatLng reportLocation;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const _ProximityBanner({
    required this.duplicate,
    required this.reportLocation,
    required this.onView,
    required this.onDismiss,
  });

  double _distanceMetres() {
    const r = 6371000.0;
    final lat1 = reportLocation.latitude * math.pi / 180;
    final lat2 = duplicate.latitude * math.pi / 180;
    final dLat =
        (duplicate.latitude - reportLocation.latitude) * math.pi / 180;
    final dLon =
        (duplicate.longitude - reportLocation.longitude) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.severityOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.severityOrange.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.merge_type_rounded,
              color: AppColors.severityOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Similar report nearby',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.severityOrange,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${duplicate.category.label} • '
                  '~${distanceLabel(_distanceMetres())} away • '
                  '${timeAgo(duplicate.createdAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // View + dismiss buttons stacked
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onView,
                child: Text(
                  'View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.severityOrange,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.severityOrange,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
