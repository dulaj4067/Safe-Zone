import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/incident.dart';
import '../models/shelter.dart';
import '../theme/app_colors.dart';
import '../utils/map_tile_config.dart';
import 'incident_card.dart';

/// What the home map shows. Filters only ever hide routine data — the
/// life-safety layer (critical alerts, active SOS / trapped-person reports)
/// bypasses them, so no filter combination can hide someone needing rescue.
class MapFilters {
  /// Non-critical (green/yellow/orange) alert zones.
  final bool alerts;
  final bool incidents;
  final Set<IncidentCategory> hiddenCategories;

  /// Hide resolved and rejected reports.
  final bool activeIncidentsOnly;
  final bool shelters;
  final bool openSheltersOnly;

  /// Safety-circle members' last-known locations.
  final bool family;

  const MapFilters({
    this.alerts = true,
    this.incidents = true,
    this.hiddenCategories = const {},
    this.activeIncidentsOnly = true,
    this.shelters = true,
    this.openSheltersOnly = false,
    this.family = true,
  });

  MapFilters copyWith({
    bool? alerts,
    bool? incidents,
    Set<IncidentCategory>? hiddenCategories,
    bool? activeIncidentsOnly,
    bool? shelters,
    bool? openSheltersOnly,
    bool? family,
  }) => MapFilters(
    alerts: alerts ?? this.alerts,
    incidents: incidents ?? this.incidents,
    hiddenCategories: hiddenCategories ?? this.hiddenCategories,
    activeIncidentsOnly: activeIncidentsOnly ?? this.activeIncidentsOnly,
    shelters: shelters ?? this.shelters,
    openSheltersOnly: openSheltersOnly ?? this.openSheltersOnly,
    family: family ?? this.family,
  );

  /// How many settings differ from the defaults — drives the badge on the
  /// filter button so it's obvious when something is being hidden.
  int get changedCount {
    const d = MapFilters();
    return [
      alerts != d.alerts,
      incidents != d.incidents,
      hiddenCategories.isNotEmpty,
      activeIncidentsOnly != d.activeIncidentsOnly,
      shelters != d.shelters,
      openSheltersOnly != d.openSheltersOnly,
      family != d.family,
    ].where((changed) => changed).length;
  }

  static bool _isActive(Incident i) =>
      i.status == IncidentStatus.pending || i.status == IncidentStatus.verified;

  /// Always on the map regardless of filters.
  static bool isCriticalIncident(Incident i) =>
      _isActive(i) && (i.isSos || i.category == IncidentCategory.trappedPerson);

  List<DisasterAlert> visibleAlerts(List<DisasterAlert> all) =>
      all.where((a) => a.severity.isCritical || alerts).toList();

  List<Incident> visibleIncidents(List<Incident> all) => all.where((i) {
    if (isCriticalIncident(i)) return true;
    if (!incidents || hiddenCategories.contains(i.category)) return false;
    return !activeIncidentsOnly || _isActive(i);
  }).toList();

  List<Shelter> visibleShelters(List<Shelter> all) {
    if (!shelters) return const [];
    return openSheltersOnly
        ? all.where((s) => s.status == 'open').toList()
        : all;
  }
}

/// Round filter control matching the other map buttons; tinted, with a
/// count badge, whenever any filter is changed from its default.
class MapFilterButton extends StatelessWidget {
  final int changedCount;
  final VoidCallback onTap;

  const MapFilterButton({
    super.key,
    required this.changedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = changedCount > 0;
    return Tooltip(
      message: 'Map layers & filters',
      child: Badge(
        isLabelVisible: active,
        label: Text('$changedCount'),
        child: Material(
          color: active ? AppColors.riverTeal : Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.layers_outlined,
                size: 20,
                color: active ? Colors.white : const Color(0xFF2A2A2A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One sheet for everything about how the home map looks: base map style,
/// the incident heatmap, and what's filtered. Edits apply live — the map
/// behind it updates as each control changes.
Future<void> showMapFilterSheet(
  BuildContext context, {
  required MapFilters current,
  required ValueChanged<MapFilters> onChanged,
  required BaseMapStyle style,
  required ValueChanged<BaseMapStyle> onStyleChanged,
  required bool heatmap,
  required ValueChanged<bool> onHeatmapChanged,
}) {
  var filters = current;
  var currentStyle = style;
  var heatmapOn = heatmap;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Keep part of the map visible behind it; the contents scroll.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.65,
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        void update(MapFilters next) {
          setSheetState(() => filters = next);
          onChanged(next);
        }

        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Map layers',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<BaseMapStyle>(
                  segments: const [
                    ButtonSegment(
                      value: BaseMapStyle.street,
                      icon: Icon(Icons.map_outlined),
                      label: Text('Street'),
                    ),
                    ButtonSegment(
                      value: BaseMapStyle.topo,
                      icon: Icon(Icons.terrain),
                      label: Text('Terrain'),
                    ),
                  ],
                  selected: {currentStyle},
                  onSelectionChanged: (s) {
                    setSheetState(() => currentStyle = s.first);
                    onStyleChanged(s.first);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.blur_on_rounded),
                  title: const Text('Incident heatmap'),
                  subtitle: const Text('Where reports are concentrated'),
                  value: heatmapOn,
                  onChanged: (v) {
                    setSheetState(() => heatmapOn = v);
                    onHeatmapChanged(v);
                  },
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: filters.changedCount == 0
                          ? null
                          : () => update(const MapFilters()),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.severityRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.priority_high_rounded,
                        color: AppColors.severityRed,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Always shown: critical (red) alerts, active SOS and '
                          'trapped-person reports, and your own location.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Other alert zones'),
                  subtitle: const Text('Advisory, watch and warning levels'),
                  value: filters.alerts,
                  onChanged: (v) => update(filters.copyWith(alerts: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.report_outlined),
                  title: const Text('Incident reports'),
                  value: filters.incidents,
                  onChanged: (v) => update(filters.copyWith(incidents: v)),
                ),
                if (filters.incidents) ...[
                  SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 40),
                    title: const Text('Active reports only'),
                    subtitle: const Text('Hide resolved and rejected'),
                    value: filters.activeIncidentsOnly,
                    onChanged: (v) =>
                        update(filters.copyWith(activeIncidentsOnly: v)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in IncidentCategory.values)
                          FilterChip(
                            avatar: Icon(
                              categoryIcon(c),
                              size: 16,
                              color: categoryColor(c),
                            ),
                            label: Text(c.label),
                            selected: !filters.hiddenCategories.contains(c),
                            onSelected: (show) {
                              final hidden = {...filters.hiddenCategories};
                              show ? hidden.remove(c) : hidden.add(c);
                              update(
                                filters.copyWith(hiddenCategories: hidden),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.night_shelter_outlined),
                  title: const Text('Shelters'),
                  value: filters.shelters,
                  onChanged: (v) => update(filters.copyWith(shelters: v)),
                ),
                if (filters.shelters)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 40),
                    title: const Text('Open shelters only'),
                    subtitle: const Text('Hide full and closed shelters'),
                    value: filters.openSheltersOnly,
                    onChanged: (v) =>
                        update(filters.copyWith(openSheltersOnly: v)),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.family_restroom),
                  title: const Text('Safety circle'),
                  subtitle: const Text('Family and friends sharing with you'),
                  value: filters.family,
                  onChanged: (v) => update(filters.copyWith(family: v)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
