import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:safezone/models/alert.dart';
import 'package:safezone/providers/alert_provider.dart';
import 'package:safezone/widgets/alert_banner.dart';
import 'package:safezone/widgets/location_alert_banner.dart';

/// A 3 km red flood alert centred on Kelaniya, like the live one.
DisasterAlert _kelaniyaFlood() => DisasterAlert(
      id: 'a1',
      title: 'Kelani River Flood Warning - Kelaniya',
      alertType: 'flood',
      severity: AlertSeverity.red,
      status: AlertStatus.active,
      centerLat: 6.9553,
      centerLng: 79.9220,
      radiusMeters: 3000,
      source: 'manual',
      createdAt: DateTime(2026, 10, 15),
      updatedAt: DateTime(2026, 10, 15),
    );

void main() {
  Future<bool> bannerShownAt(WidgetTester tester, LatLng where) async {
    final alerts = AlertProvider()..activeAlerts.add(_kelaniyaFlood());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: alerts,
        child: MaterialApp(home: Scaffold(body: LocationAlertBanner(userLocation: where))),
      ),
    );
    await tester.pump();
    final shown = find.byType(AlertBanner).evaluate().isNotEmpty;
    await tester.pumpWidget(const SizedBox.shrink());
    return shown;
  }

  testWidgets('shows for someone inside the alert radius', (tester) async {
    expect(await bannerShownAt(tester, const LatLng(6.9553, 79.9220)), isTrue);
    expect(await bannerShownAt(tester, const LatLng(6.9615, 79.9010)), isTrue);
  });

  testWidgets('hides a few kilometres outside the radius', (tester) async {
    // Colombo Fort is about 11 km away: outside the circle, so no banner. (It
    // used to show up to 6x the radius, so people outside a red zone got a red
    // banner.)
    expect(await bannerShownAt(tester, const LatLng(6.9344, 79.8428)), isFalse);
  });

  testWidgets('hides for someone far away', (tester) async {
    // Kandy is about 95 km away; Galle about 120 km.
    expect(await bannerShownAt(tester, const LatLng(7.2906, 80.6337)), isFalse);
    expect(await bannerShownAt(tester, const LatLng(6.0535, 80.2210)), isFalse);
  });
}
