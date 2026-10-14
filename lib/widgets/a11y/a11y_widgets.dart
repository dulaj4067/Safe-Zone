import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/accessibility_provider.dart';
import '../../theme/app_colors.dart';

/// Visible 2px focus ring used on custom controls.
class A11yFocus extends StatelessWidget {
  const A11yFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: focused
                  ? Border.all(color: context.brandAccent, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// Errors combine colour, an icon, and a sentence — never colour alone.
class A11yErrorBanner extends StatelessWidget {
  const A11yErrorBanner({
    super.key,
    required this.message,
    this.hint,
  });

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.dangerTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.severityRed.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.severityRed,
              size: 22,
              semanticLabel: 'Error',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.severityRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      hint!,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class A11yEmptyState extends StatelessWidget {
  const A11yEmptyState({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? hint;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: context.brandAccent, semanticLabel: message),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class A11yStepHeader extends StatelessWidget {
  const A11yStepHeader({
    super.key,
    required this.current,
    required this.total,
    required this.label,
    required this.stepTitle,
  });

  final int current;
  final int total;
  final String label;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.brandAccent,
              ),
        ),
        const SizedBox(height: 4),
        Text(stepTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 6,
              backgroundColor: AppColors.hairline,
              color: context.brandInk,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class A11yLink extends StatelessWidget {
  const A11yLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnails first when Data Saver is on; tap loads a sharper copy.
class A11yAdaptiveImage extends StatefulWidget {
  const A11yAdaptiveImage({
    super.key,
    required this.url,
    this.semanticLabel,
    this.height = 140,
    this.borderRadius = 10,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final String? semanticLabel;
  final double height;
  final double borderRadius;

  /// Optional spinner while the full image loads, and a custom failure view;
  /// when omitted the plain image / broken-image icon are used.
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<A11yAdaptiveImage> createState() => _A11yAdaptiveImageState();
}

class _A11yAdaptiveImageState extends State<A11yAdaptiveImage> {
  bool _loadHd = false;

  @override
  Widget build(BuildContext context) {
    AccessibilityProvider? a11y;
    try {
      a11y = context.watch<AccessibilityProvider>();
    } catch (_) {}
    final saver = a11y?.dataSaver ?? false;
    final showThumb = saver && !_loadHd;
    final strings = a11y?.strings;

    if (widget.url.isEmpty) return const SizedBox.shrink();

    return Semantics(
      image: true,
      label: widget.semanticLabel ?? strings?.t('tapHd') ?? 'Image',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Image.network(
                widget.url,
                fit: BoxFit.cover,
                cacheWidth: showThumb ? 240 : null,
                filterQuality:
                    showThumb ? FilterQuality.low : FilterQuality.medium,
                loadingBuilder: widget.loadingBuilder,
                errorBuilder: widget.errorBuilder ??
                    (_, _, _) => Container(
                          color: context.tintSoft,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, semanticLabel: 'Image unavailable'),
                        ),
              ),
            ),
          ),
          if (showThumb)
            Align(
              alignment: Alignment.centerLeft,
              child: A11yLink(
                label: strings?.t('loadHd') ?? 'Load sharper image',
                onTap: () => setState(() => _loadHd = true),
              ),
            ),
        ],
      ),
    );
  }
}

void showA11yUndoSnackBar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
      duration: const Duration(seconds: 5),
    ),
  );
}

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.severityRed, semanticLabel: 'Warning'),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel ?? 'Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.severityRed),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

const submitBroadcastShortcut = SingleActivator(
  LogicalKeyboardKey.enter,
  control: true,
);

class SubmitBroadcastIntent extends Intent {
  const SubmitBroadcastIntent();
}

class A11yInclusionButton extends StatelessWidget {
  const A11yInclusionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = adminStringsOf(context);
    return IconButton(
      icon: const Icon(
        Icons.accessibility_new_rounded,
        semanticLabel: 'Inclusion and accessibility settings',
      ),
      tooltip: strings.t('inclusion'),
      onPressed: () => showA11yInclusionSheet(context),
    );
  }
}

Future<void> showA11yInclusionSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _InclusionSheetContent(),
  );
}

class _InclusionSheetContent extends StatelessWidget {
  const _InclusionSheetContent();

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityProvider>();
    final strings = a11y.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.accessibility_new_rounded,
                    color: context.brandAccent,
                    size: 24,
                    semanticLabel: 'Inclusion and accessibility',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.t('inclusion'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, semanticLabel: 'Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Language selection (i18n / l10n with RTL support)
              Text(
                strings.t('language'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                strings.t('languageHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LanguageChip(
                    label: 'English',
                    code: 'en',
                    selected: a11y.localeCode == 'en',
                    onSelected: () => a11y.setLocaleCode('en'),
                  ),
                  _LanguageChip(
                    label: 'සිංහල (Sinhala)',
                    code: 'si',
                    selected: a11y.localeCode == 'si',
                    onSelected: () => a11y.setLocaleCode('si'),
                  ),
                  _LanguageChip(
                    label: 'தமிழ் (Tamil)',
                    code: 'ta',
                    selected: a11y.localeCode == 'ta',
                    onSelected: () => a11y.setLocaleCode('ta'),
                  ),
                  _LanguageChip(
                    label: 'العربية (Arabic - RTL)',
                    code: 'ar',
                    selected: a11y.localeCode == 'ar',
                    onSelected: () => a11y.setLocaleCode('ar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Economic & Environmental: Data Saver
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.data_saver_on_outlined, color: context.brandAccent),
                title: Text(strings.t('dataSaver'), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.t('dataSaverHint')),
                value: a11y.dataSaver,
                onChanged: (val) => a11y.setDataSaver(val),
              ),

              // Visual: Glare-Aware High Contrast Boost
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.wb_sunny_outlined, color: context.brandAccent),
                title: Text(strings.t('glareBoost'), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.t('glareBoostHint')),
                value: a11y.glareBoost,
                onChanged: (val) => a11y.setGlareBoost(val),
              ),

              // Auditory: Captions & Siren Transcripts
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.closed_caption_outlined, color: context.brandAccent),
                title: Text(strings.t('captions'), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.t('captionsHint')),
                value: a11y.captionsEnabled,
                onChanged: (val) => a11y.setCaptions(val),
              ),

              // Auditory & Motor: Haptic Notifications
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.vibration_outlined, color: context.brandAccent),
                title: Text(strings.t('haptics'), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.t('hapticsHint')),
                value: a11y.hapticsEnabled,
                onChanged: (val) => a11y.setHaptics(val),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onSelected;

  const _LanguageChip({
    required this.label,
    required this.code,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: context.brandInk,
      labelStyle: TextStyle(
        color: selected ? Colors.white : context.inkStrong,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}
