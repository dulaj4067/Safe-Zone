import 'package:flutter/material.dart';

class GuideMarkdown extends StatelessWidget {
  const GuideMarkdown({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content.split('\n').map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 10);
        final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
        if (heading != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              heading.group(2)!,
              style: (heading.group(1)!.length == 1
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          );
        }
        final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('* ');
        final text = isBullet ? trimmed.substring(2) : trimmed;
        return Padding(
          padding: EdgeInsets.only(left: isBullet ? 12 : 0, bottom: 5),
          child: Text(
            isBullet ? '\u2022  $text' : text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
        );
      }).toList(),
    );
  }
}