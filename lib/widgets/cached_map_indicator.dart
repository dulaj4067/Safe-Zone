import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CachedMapIndicator extends StatelessWidget {
  final ValueListenable<bool> showingCachedTiles;

  const CachedMapIndicator({
    super.key,
    required this.showingCachedTiles,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: showingCachedTiles,
      builder: (context, cached, child) => cached
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Offline map data',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
