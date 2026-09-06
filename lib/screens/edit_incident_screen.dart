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
import '../widgets/incident_card.dart';
import '../widgets/map_controls.dart';
import '../widgets/status_badge.dart';

class EditIncidentScreen extends StatefulWidget {
  final Incident incident;

  const EditIncidentScreen({super.key, required this.incident});

  @override
  State<EditIncidentScreen> createState() => _EditIncidentScreenState();
}

class _EditIncidentScreenState extends State<EditIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  late IncidentCategory _selectedCategory;
  late LatLng _selectedLocation;
  late bool _isSos;
  late IncidentStatus _selectedStatus;

  String? _existingPhotoUrl;
  String? _existingVideoUrl;
  File? _newPhotoFile;
  File? _newVideoFile;
  String? _newVideoFileName;
  bool _removeExistingPhoto = false;
  bool _removeExistingVideo = false;

  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.incident.description ?? '');
    _selectedCategory = widget.incident.category;
    _selectedLocation = LatLng(widget.incident.latitude, widget.incident.longitude);
    _isSos = widget.incident.isSos;
    _selectedStatus = widget.incident.status;
    _existingPhotoUrl = widget.incident.photoUrl;
    _existingVideoUrl = widget.incident.videoUrl;
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
          _newPhotoFile = File(picked.path);
          _removeExistingPhoto = false;
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
          _newVideoFile = File(picked.path);
          _newVideoFileName = picked.name;
          _removeExistingVideo = false;
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<IncidentProvider>();
    final photoUrlToKeep = _removeExistingPhoto ? null : _existingPhotoUrl;
    final videoUrlToKeep = _removeExistingVideo ? null : _existingVideoUrl;

    final success = await provider.editIncident(
      incidentId: widget.incident.id,
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      isSos: _isSos,
      existingPhotoUrl: photoUrlToKeep,
      existingVideoUrl: videoUrlToKeep,
      newPhotoFile: _newPhotoFile,
      newVideoFile: _newVideoFile,
      status: _selectedStatus,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Incident report updated successfully.')),
              ],
            ),
            backgroundColor: AppColors.severityGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update report. Please try again.'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  Future<void> _markResolvedDirectly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Incident as Resolved?'),
        content: const Text(
          'Have conditions on the ground cleared (e.g. water receded, road cleared)? This will update community alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF546E7A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Resolved'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<IncidentProvider>();
    final success = await provider.resolveMyIncident(widget.incident.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident marked as Resolved.'),
            backgroundColor: Color(0xFF546E7A),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to resolve incident.'),
            backgroundColor: AppColors.severityRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteIncidentDirectly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.severityRed),
            SizedBox(width: 8),
            Text('Delete Incident Report?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this incident report? It will be immediately removed from the live map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.severityRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<IncidentProvider>();
    final success = await provider.deleteIncident(widget.incident.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report deleted successfully.'),
            backgroundColor: AppColors.severityGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to delete incident.'),
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
        title: const Text('Edit Incident Report'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.severityRed),
            tooltip: 'Delete Incident',
            onPressed: isSubmitting ? null : _deleteIncidentDirectly,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatusBadge(status: _selectedStatus),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Status & Quick Resolve Card ───────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.harborSurface : AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.deepEstuary.withValues(alpha: 0.15)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.deepEstuary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Incident Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      StatusBadge(status: _selectedStatus),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedStatus == IncidentStatus.resolved
                        ? 'This incident is marked as resolved. You can update its details or change the status below.'
                        : 'If the incident has been cleared, you can mark it as resolved so community members are updated.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _selectedStatus == IncidentStatus.resolved
                                ? AppColors.severityGreen
                                : const Color(0xFF546E7A),
                            side: BorderSide(
                              color: _selectedStatus == IncidentStatus.resolved
                                  ? AppColors.severityGreen
                                  : const Color(0xFF546E7A),
                            ),
                          ),
                          icon: Icon(
                            _selectedStatus == IncidentStatus.resolved
                                ? Icons.replay
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            _selectedStatus == IncidentStatus.resolved
                                ? 'Reopen as Active'
                                : 'Mark as Resolved',
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    if (_selectedStatus == IncidentStatus.resolved) {
                                      _selectedStatus = IncidentStatus.pending;
                                    } else {
                                      _selectedStatus = IncidentStatus.resolved;
                                    }
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

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
                hintText: 'Update conditions, water depth, roadblocks, or assistance required...',
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
                  'Tap map to adjust pin',
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
              'Evidence & Media',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Photo button / preview
                Expanded(
                  child: (_newPhotoFile == null && (_existingPhotoUrl == null || _removeExistingPhoto))
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
                              child: _newPhotoFile != null
                                  ? Image.file(
                                      _newPhotoFile!,
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      _existingPhotoUrl!,
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _newPhotoFile = null;
                                  _removeExistingPhoto = true;
                                }),
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
                  child: (_newVideoFile == null && (_existingVideoUrl == null || _removeExistingVideo))
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
                                      _newVideoFileName ?? 'Video Attached',
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
                                    _newVideoFile = null;
                                    _newVideoFileName = null;
                                    _removeExistingVideo = true;
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

            // ─── Save Changes Button ───────────────────────────────────────
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _isSos ? AppColors.severityRed : AppColors.deepEstuary,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: isSubmitting ? null : _saveChanges,
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'SAVE INCIDENT CHANGES',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
            const SizedBox(height: 12),
            if (widget.incident.status != IncidentStatus.resolved)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF546E7A),
                  side: const BorderSide(color: Color(0xFF546E7A)),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.task_alt, size: 18),
                label: const Text('Mark Incident as Resolved Now'),
                onPressed: isSubmitting ? null : _markResolvedDirectly,
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.severityRed,
                side: BorderSide(color: AppColors.severityRed.withValues(alpha: 0.6)),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Incident Report'),
              onPressed: isSubmitting ? null : _deleteIncidentDirectly,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
