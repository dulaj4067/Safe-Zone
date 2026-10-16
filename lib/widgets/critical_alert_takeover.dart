import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/alert.dart';
import '../services/siren_player.dart';
import '../l10n/ui_text.dart';

/// Full-screen takeover for a critical (red) alert that applies to the
/// person: siren, repeating vibration, the instructions in large text, and
/// three clear ways out: find a shelter, call 119, or dismiss.
///
/// Sound and vibration are only a supplement; everything is also on screen,
/// so a deaf user or someone with the phone on silent still gets the full
/// message. The siren can be muted with one tap, and it stops the moment
/// the alert is dismissed.
class CriticalAlertTakeover extends StatefulWidget {
  final DisasterAlert alert;

  /// Dismiss for good. The shell also uses this after "Find nearest shelter".
  final VoidCallback onDismiss;

  /// Opens the Shelters tab (the shell dismisses the takeover afterwards).
  final VoidCallback onFindShelter;

  /// Whether to play the siren; follows the "siren override" setting.
  final bool sirenEnabled;

  /// Swapped for a fake in tests.
  final SirenPlayer? player;

  const CriticalAlertTakeover({
    super.key,
    required this.alert,
    required this.onDismiss,
    required this.onFindShelter,
    this.sirenEnabled = true,
    this.player,
  });

  @override
  State<CriticalAlertTakeover> createState() => _CriticalAlertTakeoverState();
}

class _CriticalAlertTakeoverState extends State<CriticalAlertTakeover> {
  /// Red tuned to keep white text above 4.5:1.
  static const Color _red = Color(0xFFC1272D);

  late final SirenPlayer _siren = widget.player ?? AudioSirenPlayer();
  Timer? _buzz;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    if (widget.sirenEnabled) _siren.start();
    // A strong pulse straight away, then every 1.2 s until dismissed. This
    // is deliberate for a life-safety alert and does not depend on the
    // optional haptics setting.
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => HapticFeedback.heavyImpact(),
    );
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _siren.stop();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _siren.setMuted(_muted);
  }

  Future<void> _call119() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(Uri(scheme: 'tel', path: '119'));
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text(context.tr('Dial 119 on your phone.'))));
    }
  }

  /// Instructions without the siren-script part, which has its own caption.
  String? _instructions() {
    final raw = widget.alert.instructions;
    if (raw == null) return null;
    final at = raw.indexOf('Transcript:');
    final body = (at >= 0 ? raw.substring(0, at) : raw).trim();
    return body.isEmpty ? null : body;
  }

  @override
  Widget build(BuildContext context) {
    final strings = appStringsOf(context);
    final instructions = _instructions();
    const textStyle = TextStyle(color: Colors.white);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: strings.t('criticalAlert'),
      child: Material(
        color: _red,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, size: 52, color: _red),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(
                            strings.t('criticalAlert').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: textStyle.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.alert.title,
                          textAlign: TextAlign.center,
                          style: textStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        if (instructions != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            instructions,
                            textAlign: TextAlign.center,
                            style: textStyle.copyWith(fontSize: 16, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          key: const Key('takeover_find_shelter'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _red,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: widget.onFindShelter,
                          icon: const Icon(Icons.place_outlined),
                          label: Text(
                            strings.t('findNearestShelter'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('takeover_call_119'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _call119,
                          icon: const Icon(Icons.call_outlined),
                          label: Text(
                            strings.t('callEmergency'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const Key('takeover_dismiss'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: widget.onDismiss,
                          child: Text(
                            strings.t('dismissAlert'),
                            style: const TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.sirenEnabled)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    key: const Key('takeover_mute'),
                    tooltip: strings.t(_muted ? 'unmuteSiren' : 'muteSiren'),
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                    color: Colors.white,
                    onPressed: _toggleMute,
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
