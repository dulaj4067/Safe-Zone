import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/utils/alert_relevance.dart';
import 'package:safezone/widgets/location_alert_banner.dart';

DisasterAlert _alert(String id, AlertSeverity s, double lat, double lng, {int radius = 1000}) =>
    DisasterAlert(
      id: id,
      title: 'Alert $id',
      alertType: 'flood',
      severity: s,
      status: AlertStatus.active,
      centerLat: lat,
      centerLng: lng,
      radiusMeters: radius,
      source: 'manual',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  const here = LatLng(6.9, 79.9);

  test('relevance: a nearby orange alert outranks a distant red one', () {
    final nearOrange = _alert('a', AlertSeverity.orange, 6.9, 79.9);
    final farRed = _alert('b', AlertSeverity.red, 6.9, 79.935); // ~3.9 km away
    expect(alertRelevance(nearOrange, here)!, greaterThan(alertRelevance(farRed, here)!));
  });

  test('relevance: red on top of you beats everything', () {
    final red = _alert('a', AlertSeverity.red, 6.9, 79.9);
    final orange = _alert('b', AlertSeverity.orange, 6.9, 79.9);
    expect(alertRelevance(red, here)!, greaterThan(alertRelevance(orange, here)!));
  });

  test('relevance: too far away is null, unknown position falls back to severity', () {
    final far = _alert('a', AlertSeverity.red, 8.0, 80.9);
    expect(alertRelevance(far, here), isNull);
    expect(alertRelevance(far, null), 100);
  });

  testWidgets('only one banner: the in-screen strip hides while the top banner is up',
      (tester) async {
    final provider = AlertProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<AlertProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: LocationAlertBanner(userLocation: here)),
        ),
      ),
    );
    expect(find.byType(LocationAlertBanner), findsOneWidget);
    // With no alerts and no banner nothing renders either way.
    expect(find.text('Alert a'), findsNothing);
  });
}
