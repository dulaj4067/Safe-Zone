import 'package:flutter/material.dart';

import '../models/route_result.dart';
import '../theme/app_theme.dart';

class RouteSummaryCard extends StatelessWidget {
  final RouteResult result;

  const RouteSummaryCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.alt_route),
            const SizedBox(width: 10),
            Text(result.distanceLabel, style: AppTheme.dataText(context)),
            const SizedBox(width: 16),
            const Icon(Icons.schedule),
            const SizedBox(width: 10),
            Text(result.durationLabel, style: AppTheme.dataText(context)),
          ],
        ),
      ),
    );
  }
}
