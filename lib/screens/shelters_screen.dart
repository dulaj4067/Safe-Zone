import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/shelter.dart';
import '../services/location_service.dart';
import '../services/shelter_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'shelter_detail_screen.dart';

/// Shelters tab: every shelter, nearest first, filterable by kind and
/// availability. Tapping one opens its Shelter page; directions live
/// there rather than on a map here.
class SheltersScreen extends StatefulWidget {
  final AppUser? currentUser;

  const SheltersScreen({super.key, this.currentUser});

  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  static const Distance _distance = Distance();

  final ShelterService _service = ShelterService();
  final TextEditingController _search = TextEditingController();

  List<Shelter>? _shelters;
  String? _error;
  LatLng? _userLocation;

  /// null = every type.
  String? _type;
  bool _openOnly = false;

  static const _types = [
    ('shelter', 'Shelters', Icons.night_shelter_outlined),
    ('relief_camp', 'Relief camps', Icons.holiday_village_outlined),
    ('medical_point', 'Medical points', Icons.local_hospital_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _locate();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final service = LocationService();
    if (!await service.ensurePermission()) return;
    final here = await service.getCurrentLocation();
    if (mounted && here != null) setState(() => _userLocation = here);
  }

  Future<void> _load() async {
    try {
      final shelters = await _service.fetchShelters();
      if (!mounted) return;
      setState(() {
        _shelters = shelters;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load shelters. Pull to retry.');
      }
    }
  }

  double? _metresTo(Shelter s) {
    final user = _userLocation;
    return user == null
        ? null
        : _distance(user, LatLng(s.latitude, s.longitude));
  }

  List<Shelter> _visible(List<Shelter> all) {
    final query = _search.text.trim().toLowerCase();
    final list = all.where((s) {
      if (_type != null && s.type != _type) return false;
      if (_openOnly && s.status != 'open') return false;
      return query.isEmpty || s.name.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      // Closed shelters sink to the bottom; otherwise nearest first.
      final aClosed = a.status == 'closed', bClosed = b.status == 'closed';
      if (aClosed != bClosed) return aClosed ? 1 : -1;
      final da = _metresTo(a), db = _metresTo(b);
      if (da != null && db != null) return da.compareTo(db);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = _shelters;

    return Scaffold(
      appBar: AppBar(title: const Text('Shelters')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search shelters',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _search.clear,
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Open now'),
                  selected: _openOnly,
                  onSelected: (v) => setState(() => _openOnly = v),
                ),
                for (final (value, label, icon) in _types) ...[
                  const SizedBox(width: 6),
                  FilterChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(label),
                    selected: _type == value,
                    onSelected: (v) => setState(() => _type = v ? value : null),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: all == null
                  ? _error != null
                        ? _Message(icon: Icons.cloud_off, text: _error!)
                        : const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        final visible = _visible(all);
                        if (visible.isEmpty) {
                          return const _Message(
                            icon: Icons.search_off,
                            text: 'No shelters match these filters.',
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final shelter = visible[i];
                            return _ShelterCard(
                              shelter: shelter,
                              metres: _metresTo(shelter),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ShelterDetailScreen(
                                      shelter: shelter,
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                );
                                _load(); // pick up any supply/occupancy edits
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelterCard extends StatelessWidget {
  final Shelter shelter;
  final double? metres;
  final VoidCallback onTap;

  const _ShelterCard({
    required this.shelter,
    required this.metres,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fraction = shelter.occupancyFraction;
    final cap = shelter.capacity, occ = shelter.occupancy;
    final free = (cap != null && occ != null) ? cap - occ : null;
    final barColor = (fraction ?? 0) >= 0.9
        ? AppColors.severityRed
        : (fraction ?? 0) >= 0.7
        ? AppColors.severityOrange
        : AppColors.severityGreen;
    final m = metres;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelter.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            shelter.typeLabel,
                            if (m != null) distanceLabel(m),
                          ].join(' · '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (shelter.status != null)
                    ShelterStatusPill(status: shelter.status!),
                ],
              ),
              if (fraction != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    color: barColor,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  free != null && free > 0
                      ? '$free spaces free · $occ/$cap'
                      : 'At capacity · $occ/$cap',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    // Inside a ListView so pull-to-refresh still works on empty/error states.
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: AppColors.slateMuted),
        const SizedBox(height: 12),
        Center(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
  }
}
