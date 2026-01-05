// lib/core/services/feedback_service.dart
import 'package:flutter/foundation.dart';
import 'haptic_service.dart';
import 'sound_service.dart';

/// Unified feedback service that combines haptics and sounds.
/// Provides a single interface for all user feedback throughout the app.
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();
  
  final HapticService _haptics = HapticService();
  final SoundService _sounds = SoundService();
  
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
  bool _initialized = false;
  
  /// Initialize the feedback service
  Future<void> initialize() async {
    if (_initialized) return;
    await _sounds.initialize();
    _initialized = true;
    debugPrint('✨ FeedbackService initialized');
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _sounds.dispose();
    _initialized = false;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Enable/disable haptics
  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    _haptics.setEnabled(enabled);
  }
  
  bool get hapticsEnabled => _hapticsEnabled;
  
  /// Enable/disable sounds
  void setSoundsEnabled(bool enabled) {
    _soundsEnabled = enabled;
    _sounds.setEnabled(enabled);
  }
  
  bool get soundsEnabled => _soundsEnabled;
  
  /// Set sound volume (0.0 to 1.0)
  void setSoundVolume(double volume) {
    _sounds.setVolume(volume);
  }
  
  double get soundVolume => _sounds.volume;

  // ═══════════════════════════════════════════════════════════════════════════
  // BASIC INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Light tap feedback - for subtle UI interactions
  /// Use for: toggles, small buttons, list items
  Future<void> lightTap() async {
    await Future.wait([
      _haptics.lightTap(),
      _sounds.tap(),
    ]);
  }
  
  /// Button press feedback - standard button interaction
  /// Use for: primary buttons, action buttons
  Future<void> buttonPress() async {
    await Future.wait([
      _haptics.buttonPress(),
      _sounds.click(),
    ]);
  }
  
  /// Selection feedback - selecting an item
  /// Use for: list selection, picker selection
  Future<void> selection() async {
    await Future.wait([
      _haptics.selectionTick(),
      _sounds.select(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Navigation feedback - moving between screens
  /// Use for: page navigation, tab switches
  Future<void> navigation() async {
    await Future.wait([
      _haptics.navigation(),
      _sounds.navForward(),
    ]);
  }
  
  /// Back navigation feedback
  Future<void> navigateBack() async {
    await Future.wait([
      _haptics.lightTap(),
      _sounds.navBack(),
    ]);
  }
  
  /// Tab switch feedback
  Future<void> tabSwitch() async {
    await Future.wait([
      _haptics.selectionTick(),
      _sounds.tabSwitch(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUCCESS / ERROR / WARNING
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Success feedback - action completed successfully
  Future<void> success() async {
    await Future.wait([
      _haptics.success(),
      _sounds.success(),
    ]);
  }
  
  /// Small success feedback - minor positive action
  Future<void> successSmall() async {
    await Future.wait([
      _haptics.correctAnswer(),
      _sounds.successSmall(),
    ]);
  }
  
  /// Big success feedback - major achievement
  Future<void> successBig() async {
    await Future.wait([
      _haptics.celebration(),
      _sounds.successBig(),
    ]);
  }
  
  /// Error feedback - something went wrong
  Future<void> error() async {
    await Future.wait([
      _haptics.error(),
      _sounds.error(),
    ]);
  }
  
  /// Warning feedback - attention needed
  Future<void> warning() async {
    await Future.wait([
      _haptics.warning(),
      _sounds.warning(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDUCATIONAL / GAME INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Letter selection feedback
  /// Use for: letter grid, keyboard input, character selection
  Future<void> letterSelect() async {
    await Future.wait([
      _haptics.letterSelect(),
      _sounds.letterSelect(),
    ]);
  }
  
  /// Correct answer feedback
  /// Use for: correct letter chosen, right answer selected
  Future<void> correctAnswer() async {
    await Future.wait([
      _haptics.correctAnswer(),
      _sounds.letterCorrect(),
    ]);
  }
  
  /// Wrong answer feedback
  /// Use for: incorrect letter chosen, wrong answer selected
  Future<void> wrongAnswer() async {
    await Future.wait([
      _haptics.wrongAnswer(),
      _sounds.letterWrong(),
    ]);
  }
  
  /// Reveal feedback - showing hidden content
  /// Use for: reveal answer, show solution
  Future<void> reveal() async {
    await Future.wait([
      _haptics.reveal(),
      _sounds.reveal(),
    ]);
  }
  
  /// Hint feedback - showing a hint
  Future<void> hint() async {
    await Future.wait([
      _haptics.lightTap(),
      _sounds.hint(),
    ]);
  }
  
  /// Audio play feedback - starting audio playback
  Future<void> audioPlay() async {
    await Future.wait([
      _haptics.audioPlay(),
      _sounds.audioStart(),
    ]);
  }
  
  /// Progress step feedback
  Future<void> progressStep() async {
    await Future.wait([
      _haptics.progressStep(),
      _sounds.progress(),
    ]);
  }
  
  /// Image selection feedback
  Future<void> imageSelect() async {
    await Future.wait([
      _haptics.selectionTick(),
      _sounds.select(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LESSON COMPLETION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Lesson complete feedback
  Future<void> lessonComplete() async {
    await Future.wait([
      _haptics.lessonComplete(),
      _sounds.lessonComplete(),
    ]);
  }
  
  /// Submodule complete feedback
  Future<void> submoduleComplete() async {
    await Future.wait([
      _haptics.submoduleComplete(),
      _sounds.submoduleComplete(),
    ]);
  }
  
  /// Module complete feedback - big celebration!
  Future<void> moduleComplete() async {
    await Future.wait([
      _haptics.moduleComplete(),
      _sounds.moduleComplete(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAG & DROP
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Drag start feedback
  Future<void> dragStart() async {
    await _haptics.dragStart();
  }
  
  /// Drag over valid target feedback
  Future<void> dragOverTarget() async {
    await _haptics.dragOverTarget();
  }
  
  /// Drop success feedback
  Future<void> dropSuccess() async {
    await Future.wait([
      _haptics.dropSuccess(),
      _sounds.pop(),
    ]);
  }
  
  /// Swipe feedback
  Future<void> swipe() async {
    await _haptics.swipe();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Notification feedback
  Future<void> notification() async {
    await Future.wait([
      _haptics.lightTap(),
      _sounds.notification(),
    ]);
  }
  
  /// Pop feedback - for appearing elements
  Future<void> pop() async {
    await Future.wait([
      _haptics.lightTap(),
      _sounds.pop(),
    ]);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HAPTIC-ONLY METHODS (when sound isn't appropriate)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Haptic-only feedback for continuous actions
  Future<void> hapticOnly() => _haptics.selectionTick();
  
  /// Medium haptic-only feedback
  Future<void> hapticMedium() => _haptics.mediumTap();
  
  /// Heavy haptic-only feedback
  Future<void> hapticHeavy() => _haptics.heavyTap();
}

