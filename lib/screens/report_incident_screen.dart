import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/map_controls.dart';
import '../widgets/incident_card.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
            content: Text(provider.errorMessage ?? 'Failed to submit report. Please try again.'),
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
                      });
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
                  setState(() => _selectedCategory = cat);
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
                          });
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

            // ─── Submit Button ─────────────────────────────────────────────
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _isSos ? AppColors.severityRed : AppColors.deepEstuary,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: isSubmitting ? null : _submit,
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
