import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/incident_detail_sheet.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: Icon(
              provider.viewMode == IncidentViewMode.map
                  ? Icons.list
                  : Icons.map,
            ),
            tooltip: provider.viewMode == IncidentViewMode.map
                ? 'Switch to list'
                : 'Switch to map',
            onPressed: () {
              context.read<IncidentProvider>().setViewMode(
                    provider.viewMode == IncidentViewMode.map
                        ? IncidentViewMode.list
                        : IncidentViewMode.map,
                  );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.isOffline) _OfflineBanner(lastUpdated: provider.lastUpdated),
          Expanded(
            child: provider.isLoading && provider.incidents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.viewMode == IncidentViewMode.map
                    ? _IncidentMap(incidents: provider.sortedIncidents)
                    : _IncidentList(incidents: provider.sortedIncidents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<IncidentProvider>().load(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final DateTime? lastUpdated;
  const _OfflineBanner({this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final label = lastUpdated != null
        ? 'Showing cached data from ${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}'
        : 'Offline — no cached data available';
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _IncidentMap extends StatelessWidget {
  final List<Incident> incidents;
  const _IncidentMap({required this.incidents});

  BitmapDescriptor _markerFor(Incident incident) {
    if (incident.isSos) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    switch (incident.category) {
      case IncidentCategory.trappedPerson:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case IncidentCategory.waterlogging:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      case IncidentCategory.blockedRoad:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case IncidentCategory.powerOutage:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case IncidentCategory.structuralDamage:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case IncidentCategory.other:
        return BitmapDescriptor.defaultMarker;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents reported nearby.'));
    }

    final center = LatLng(incidents.first.latitude, incidents.first.longitude);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13),
      markers: incidents.map((incident) {
        return Marker(
          markerId: MarkerId(incident.id),
          position: LatLng(incident.latitude, incident.longitude),
          icon: _markerFor(incident),
          onTap: () => showModalBottomSheet(
            context: context,
            builder: (_) => IncidentDetailSheet(
              incident: incident,
              onConfirm: () {
                final userId = SupabaseService.currentUserId;
                if (userId != null) {
                  context.read<IncidentProvider>().confirmIncident(
                        incidentId: incident.id,
                        memberId: userId,
                      );
                }
                Navigator.pop(context);
              },
            ),
          ),
        );
      }).toSet(),
    );
  }
}

class _IncidentList extends StatelessWidget {
  final List<Incident> incidents;
  const _IncidentList({required this.incidents});

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents reported nearby.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return Card(
          color: incident.isSos ? Colors.red.shade50 : null,
          child: ListTile(
            leading: incident.isSos
                ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                : const Icon(Icons.report_outlined),
            title: Text(incident.category.label),
            subtitle: Text(
              incident.description ?? 'No description provided',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${incident.credibilityScore} ✓'),
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => IncidentDetailSheet(
                incident: incident,
                onConfirm: () {
                  final userId = SupabaseService.currentUserId;
                  if (userId != null) {
                    context.read<IncidentProvider>().confirmIncident(
                          incidentId: incident.id,
                          memberId: userId,
                        );
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
