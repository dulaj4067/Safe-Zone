enum DisasterDatePrecision { day, month, year }

class DisasterHistoryRecord {
  const DisasterHistoryRecord({
    required this.id,
    required this.zoneId,
    required this.disasterType,
    required this.date,
    required this.summary,
    this.severity,
    this.datePrecision = DisasterDatePrecision.day,
    this.endDate,
    this.endDatePrecision = DisasterDatePrecision.day,
    this.eventName,
    this.disasterSubtype,
    this.locationDescription,
    this.sourceEventId,
    this.sourceName,
    this.sourceUrl,
    this.sourceVersion,
    this.totalDeaths,
    this.totalInjured,
    this.totalAffected,
    this.totalHomeless,
    this.adjustedDamageKusd,
    this.isSample = false,
  });

  final String id;
  final String? zoneId;
  final String disasterType;
  final DateTime date;
  final DisasterDatePrecision datePrecision;
  final DateTime? endDate;
  final DisasterDatePrecision endDatePrecision;
  final String? severity;
  final String summary;
  final String? eventName;
  final String? disasterSubtype;
  final String? locationDescription;
  final String? sourceEventId;
  final String? sourceName;
  final String? sourceUrl;
  final String? sourceVersion;
  final int? totalDeaths;
  final int? totalInjured;
  final int? totalAffected;
  final int? totalHomeless;
  final num? adjustedDamageKusd;
  final bool isSample;

  bool get isNational => zoneId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'zoneId': zoneId,
    'disasterType': disasterType,
    'date': _formatPartialDate(date, datePrecision),
    'datePrecision': datePrecision.name,
    'endDate': endDate == null
        ? null
        : _formatPartialDate(endDate!, endDatePrecision),
    'endDatePrecision': endDatePrecision.name,
    'severity': severity,
    'summary': summary,
    'eventName': eventName,
    'disasterSubtype': disasterSubtype,
    'locationDescription': locationDescription,
    'sourceEventId': sourceEventId,
    'sourceName': sourceName,
    'sourceUrl': sourceUrl,
    'sourceVersion': sourceVersion,
    'totalDeaths': totalDeaths,
    'totalInjured': totalInjured,
    'totalAffected': totalAffected,
    'totalHomeless': totalHomeless,
    'adjustedDamageKusd': adjustedDamageKusd,
    'isSample': isSample,
  };

  factory DisasterHistoryRecord.fromJson(Map<String, dynamic> json) {
    final dateValue = json['date'] as String;
    final datePrecision = _readPrecision(
      json['datePrecision'] as String?,
      dateValue,
    );
    final endDateValue = json['endDate'] as String?;

    return DisasterHistoryRecord(
      id: json['id'] as String,
      zoneId: json['zoneId'] as String?,
      disasterType: json['disasterType'] as String,
      date: _parsePartialDate(dateValue),
      datePrecision: datePrecision,
      endDate: endDateValue == null ? null : _parsePartialDate(endDateValue),
      endDatePrecision: _readPrecision(
        json['endDatePrecision'] as String?,
        endDateValue ?? '',
      ),
      severity: json['severity'] as String?,
      summary: json['summary'] as String? ?? '',
      eventName: json['eventName'] as String?,
      disasterSubtype: json['disasterSubtype'] as String?,
      locationDescription: json['locationDescription'] as String?,
      sourceEventId: json['sourceEventId'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      sourceVersion: json['sourceVersion'] as String?,
      totalDeaths: _readInteger(json['totalDeaths']),
      totalInjured: _readInteger(json['totalInjured']),
      totalAffected: _readInteger(json['totalAffected']),
      totalHomeless: _readInteger(json['totalHomeless']),
      adjustedDamageKusd: _readNumber(json['adjustedDamageKusd']),
      isSample: json['isSample'] as bool? ?? false,
    );
  }

  static String _formatPartialDate(
    DateTime value,
    DisasterDatePrecision precision,
  ) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return switch (precision) {
      DisasterDatePrecision.year => value.year.toString(),
      DisasterDatePrecision.month => '${value.year}-$month',
      DisasterDatePrecision.day => '${value.year}-$month-${day}T00:00:00.000',
    };
  }

  static DateTime _parsePartialDate(String value) {
    if (value.length == 4) return DateTime(int.parse(value));
    if (value.length == 7) return DateTime.parse('$value-01');
    return DateTime.parse(value);
  }

  static DisasterDatePrecision _readPrecision(String? value, String date) {
    if (value != null) {
      return DisasterDatePrecision.values.byName(value);
    }
    return switch (date.length) {
      4 => DisasterDatePrecision.year,
      7 => DisasterDatePrecision.month,
      _ => DisasterDatePrecision.day,
    };
  }

  static int? _readInteger(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    if (value is String && value.trim().isEmpty) return null;
    if (value is String) return int.parse(value);
    throw FormatException('Expected an integer, received $value.');
  }

  static num? _readNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String && value.trim().isEmpty) return null;
    if (value is String) return num.parse(value);
    throw FormatException('Expected a number, received $value.');
  }
}
