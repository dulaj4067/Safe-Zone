import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../models/zone.dart';
import '../../../utils/map_tile_config.dart';
import '../../../utils/map_tile_sources.dart';
import '../models/evacuation_route.dart';
import '../providers/preparedness_provider.dart';

class ManageRoutesScreen extends StatelessWidget {
  const ManageRoutesScreen({super.key, required this.zones});
  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage evacuation routes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('New route'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: provider.routes.map((route) => Card(
          child: ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(zones.where((zone) => zone.id == route.zoneId).firstOrNull?.name ?? route.zoneId),
            subtitle: Text('Updated ${MaterialLocalizations.of(context).formatShortDate(route.lastUpdated)}'),
            onTap: () => _edit(context, route),
            trailing: const Icon(Icons.edit_outlined),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [EvacuationRoute? route]) async {
    final saved = await Navigator.push<EvacuationRoute>(
      context,
      MaterialPageRoute(builder: (_) => _RouteEditor(route: route, zones: zones)),
    );
    if (saved != null && context.mounted) {
      await context.read<PreparednessProvider>().saveRoute(saved);
    }
  }
}

class _RouteEditor extends StatefulWidget {
  const _RouteEditor({required this.route, required this.zones});
  final EvacuationRoute? route;
  final List<Zone> zones;

  @override
  State<_RouteEditor> createState() => _RouteEditorState();
}

class _RouteEditorState extends State<_RouteEditor> {
  final _mapController = MapController();
  late final TextEditingController _instructions;
  late String? _zoneId;
  late List<LatLng> _points;

  @override
  void initState() {
    super.initState();
    _zoneId = widget.route?.zoneId ?? widget.zones.firstOrNull?.id ?? 'default';
    _points = widget.route?.routePolyline.toList() ?? [];
    _instructions = TextEditingController(text: widget.route?.instructions.join('\n'));
  }

  @override
  void dispose() {
    _instructions.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.route == null ? 'Create route' : 'Edit route')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: _zoneId,
                decoration: const InputDecoration(labelText: 'Zone'),
                items: [
                  if (widget.zones.isEmpty)
                    const DropdownMenuItem(value: 'default', child: Text('Default zone')),
                  ...widget.zones.map((zone) => DropdownMenuItem(value: zone.id, child: Text(zone.name))),
                ],
                onChanged: (value) => setState(() => _zoneId = value),
              ),
            ),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _points.firstOrNull ?? const LatLng(6.9344, 79.8500),
                      initialZoom: 14,
                      onTap: (_, point) => setState(() => _points.add(point)),
                    ),
                    children: [
                      buildBaseTileLayer(BaseMapStyle.topo),
                      if (_points.length > 1)
                        PolylineLayer(polylines: [Polyline(points: _points, strokeWidth: 5, color: Theme.of(context).colorScheme.primary)]),
                      MarkerLayer(
                        markers: [
                          for (var index = 0; index < _points.length; index++)
                            Marker(
                              point: _points[index],
                              width: 38,
                              height: 42,
                              child: Icon(
                                index == 0 ? Icons.trip_origin : (index == _points.length - 1 ? Icons.place : Icons.more_horiz),
                                color: index == _points.length - 1 ? Colors.green.shade800 : Theme.of(context).colorScheme.primary,
                                size: 34,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton.filledTonal(
                      tooltip: 'Undo last point',
                      onPressed: _points.isEmpty ? null : () => setState(() => _points.removeLast()),
                      icon: const Icon(Icons.undo),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _instructions,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Turn-by-turn instructions (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _points.length < 2 ? null : _save,
                  child: const Text('Save route'),
                ),
              ),
            ),
          ],
        ),
      );

  void _save() {
    final now = DateTime.now();
    Navigator.pop(
      context,
      EvacuationRoute(
        id: widget.route?.id ?? 'route-${now.microsecondsSinceEpoch}',
        zoneId: _zoneId ?? 'default',
        startPoint: _points.first,
        safeZonePoint: _points.last,
        routePolyline: List.unmodifiable(_points),
        instructions: _instructions.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList(),
        lastUpdated: now,
      ),
    );
  }
}