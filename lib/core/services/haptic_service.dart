// lib/core/services/haptic_service.dart
import 'package:flutter/services.dart';

/// Professional haptic feedback service with various feedback patterns.
/// Uses iOS-style haptics on iOS and vibration patterns on Android.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();
  
  bool _enabled = true;
  
  /// Enable or disable haptics globally
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  bool get isEnabled => _enabled;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT FEEDBACK - Subtle, non-intrusive
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Light tap - for subtle UI elements, toggles, switches
  /// Use for: checkbox taps, toggle switches, small buttons
  Future<void> lightTap() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }
  
  /// Selection tick - for scrolling through lists/pickers
  /// Use for: date picker scroll, list item selection, tab switching
  Future<void> selectionTick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIUM FEEDBACK - Standard interaction feedback
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Medium tap - standard button press feedback
  /// Use for: primary buttons, navigation items, card taps
  Future<void> mediumTap() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }
  
  /// Button press - explicit button interaction
  /// Use for: filled buttons, action buttons, submit buttons
  Future<void> buttonPress() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEAVY FEEDBACK - Important actions
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Heavy tap - for important or destructive actions
  /// Use for: delete actions, critical confirmations
  Future<void> heavyTap() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }
  
  /// Navigation feedback - navigating between major screens
  /// Use for: page transitions, bottom nav taps
  Future<void> navigation() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUCCESS / ERROR / WARNING PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Success feedback - task completed successfully
  /// Use for: form submission success, lesson completion, correct answer
  Future<void> success() async {
    if (!_enabled) return;
    // iOS uses notification feedback, Android gets a pattern
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
  
  /// Double success - bigger achievement
  /// Use for: submodule/module completion, major milestones
  Future<void> celebration() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
  
  /// Error feedback - something went wrong
  /// Use for: form validation errors, wrong answer, failed action
  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
  
  /// Warning feedback - attention needed
  /// Use for: leaving unsaved changes, confirmations
  Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GAME-LIKE / EDUCATIONAL PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Letter selection - selecting a letter/character
  /// Use for: letter grid selection, keyboard input
  Future<void> letterSelect() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
  
  /// Correct answer - answered correctly in a game/quiz
  /// Use for: correct letter selection, right image choice
  Future<void> correctAnswer() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }
  
  /// Wrong answer - answered incorrectly
  /// Use for: wrong letter selection, incorrect choice
  Future<void> wrongAnswer() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }
  
  /// Reveal - showing hidden content
  /// Use for: revealing answer, showing hint
  Future<void> reveal() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.selectionClick();
  }
  
  /// Audio play - starting audio playback
  /// Use for: play button tap, audio lesson start
  Future<void> audioPlay() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
  
  /// Progress step - completing a step in a multi-step process
  /// Use for: multi-screen lessons, progress updates
  Future<void> progressStep() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LESSON COMPLETION PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Lesson complete - finished a lesson
  Future<void> lessonComplete() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.selectionClick();
  }
  
  /// Submodule complete - finished a submodule
  Future<void> submoduleComplete() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.selectionClick();
  }
  
  /// Module complete - finished an entire module (big achievement!)
  Future<void> moduleComplete() async {
    if (!_enabled) return;
    // Triple pulse celebration pattern
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAG & DROP / GESTURES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Drag start - beginning a drag operation
  Future<void> dragStart() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
  
  /// Drag over valid target - hovering over a valid drop zone
  Future<void> dragOverTarget() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
  
  /// Drop success - successfully dropped in valid location
  Future<void> dropSuccess() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }
  
  /// Swipe - swipe gesture detected
  Future<void> swipe() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }
}

