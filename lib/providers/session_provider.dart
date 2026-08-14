import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/focus_mode.dart';

enum SessionStatus { idle, running, paused, completed }

/// Single source of truth for Sprint 1: which mode is selected, and the
/// state of the current focus session (start / pause / resume / complete).
class FocusState extends ChangeNotifier {
  FocusMode _selectedMode = FocusMode.flowtime;
  SessionStatus _status = SessionStatus.idle;
  int _seconds = 0; // remaining seconds for countdown modes, elapsed for Flowtime
  Timer? _ticker;

  // Off by default — completion should stay quiet until the user opts in.
  bool _soundEnabled = false;
  bool _vibrationEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  FocusMode get selectedMode => _selectedMode;
  SessionStatus get status => _status;
  int get seconds => _seconds;
  bool get isActive =>
      _status == SessionStatus.running || _status == SessionStatus.paused;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    _vibrationEnabled = value;
    notifyListeners();
  }

  /// Mode can only be changed when there is no session in progress,
  /// so an active timer's duration/behavior never changes mid-session.
  void selectMode(FocusMode mode) {
    if (isActive) return;
    _selectedMode = mode;
    notifyListeners();
  }

  /// Starts a session in one call — satisfies the "one tap to start" story.
  void startSession() {
    if (_status == SessionStatus.running) return;
    if (_status == SessionStatus.idle || _status == SessionStatus.completed) {
      _seconds = _selectedMode.workDurationSeconds ?? 0;
    }
    _status = SessionStatus.running;
    _startTicker();
    notifyListeners();
  }

  /// Pauses the session, preserving elapsed/remaining time.
  void pauseSession() {
    if (_status != SessionStatus.running) return;
    _ticker?.cancel();
    _status = SessionStatus.paused;
    notifyListeners();
  }

  /// Resumes from exactly where the session was paused.
  void resumeSession() {
    if (_status != SessionStatus.paused) return;
    _status = SessionStatus.running;
    _startTicker();
    notifyListeners();
  }

  /// Ends the current session and returns to idle, ready for a new one.
  void resetSession() {
    _ticker?.cancel();
    // 1. Play the chime sound & haptic feedback when Complete/Reset is clicked
    _fireCompletionFeedback();
    _status = SessionStatus.idle;
    _seconds = _selectedMode.workDurationSeconds ?? 0;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_selectedMode.isCountdown) {
        if (_seconds <= 0) {
          _completeSession();
          return;
        }
        _seconds -= 1;
      } else {
        _seconds += 1;
      }
      notifyListeners();
    });
  }

  void _completeSession() {
    _ticker?.cancel();
    _status = SessionStatus.completed;
    _fireCompletionFeedback();
    notifyListeners();
  }

  /// Gentle, opt-in only. Nothing fires unless the user has explicitly
  /// turned it on in Settings — matches the "no sound or vibration
  /// unless enabled" requirement.
  void _fireCompletionFeedback() {
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (_soundEnabled) {
      _playChime();
    }
  }

  Future<void> _playChime() async {
    // Kept quiet even at max device volume — a chime, not an alarm.
    await _audioPlayer.setVolume(0.5);
    await _audioPlayer.play(AssetSource('sounds/chime.mp3'));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}