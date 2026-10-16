import '../models/disaster_history_record.dart';

final disasterHistorySamples = [
  DisasterHistoryRecord(
    id: 'sample-flood-practice',
    zoneId: null,
    disasterType: 'Flood',
    date: DateTime(2024, 5),
    datePrecision: DisasterDatePrecision.month,
    severity: null,
    summary:
        'Fictional sample record for previewing the history screen. Not based on a real event.',
    eventName: 'Practice scenario A',
    disasterSubtype: 'Illustrative scenario',
    locationDescription: 'Fictional multi-district area',
    sourceName: 'SafeZone demo sample',
    isSample: true,
  ),
  DisasterHistoryRecord(
    id: 'sample-storm-practice',
    zoneId: null,
    disasterType: 'Storm',
    date: DateTime(2023),
    datePrecision: DisasterDatePrecision.year,
    severity: null,
    summary:
        'Fictional sample record for previewing the history screen. Not based on a real event.',
    eventName: 'Practice scenario B',
    disasterSubtype: 'Illustrative scenario',
    locationDescription: 'Fictional coastal area',
    sourceName: 'SafeZone demo sample',
    isSample: true,
  ),
  DisasterHistoryRecord(
    id: 'sample-landslide-practice',
    zoneId: null,
    disasterType: 'Landslide',
    date: DateTime(2022, 11, 12),
    severity: null,
    summary:
        'Fictional sample record for previewing the history screen. Not based on a real event.',
    eventName: 'Practice scenario C',
    disasterSubtype: 'Illustrative scenario',
    locationDescription: 'Fictional hillside area',
    sourceName: 'SafeZone demo sample',
    isSample: true,
  ),
];
