// lib/core/services/sound_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Professional UI sound service for interaction feedback.
/// Uses generated tones for consistent cross-platform sound experience.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();
  
  bool _enabled = true;
  bool _initialized = false;
  double _volume = 1.0; // 0.0 to 1.0 - default to full volume
  
  // Audio players pool for concurrent sounds
  final List<AudioPlayer> _players = [];
  static const int _poolSize = 4;
  int _currentPlayerIndex = 0;
  
  // Pre-generated sound file paths for instant playback
  final Map<String, String> _soundPaths = {};
  
  /// Initialize the sound service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Pre-generate all sounds and save to files first
      await _generateAllSounds();
      
      // Create player pool
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        
        // Set player mode - mediaPlayer for iOS compatibility
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setReleaseMode(ReleaseMode.stop);
        
        // Set audio context - use playback category for reliable audio
        try {
          await player.setAudioContext(
            AudioContext(
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: {AVAudioSessionOptions.mixWithOthers},
              ),
              android: AudioContextAndroid(
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.assistanceSonification,
                audioFocus: AndroidAudioFocus.gainTransientMayDuck,
              ),
            ),
          );
        } catch (_) {
          // Audio context setup failed - sounds may not play
        }
        
        _players.add(player);
      }
      
      _initialized = true;
      debugPrint('🔊 SoundService initialized');
    } catch (e) {
      debugPrint('🔊 SoundService initialization failed: $e');
      // Service will work without sounds - haptics will still function
      _initialized = true;
    }
  }
  
  /// Generate all sound waveforms upfront and save to files for instant playback
  Future<void> _generateAllSounds() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final soundsDir = Directory('${tempDir.path}/ui_sounds');
      
      // Create sounds directory if it doesn't exist
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }
      
      // Define all sounds to generate
      final soundDefinitions = <String, Uint8List>{
        // UI Interaction sounds
        'tap': _generateTone(800, 0.05, type: 'sine', decay: true),
        'click': _generateTone(1200, 0.03, type: 'square', decay: true),
        'select': _generateTone(600, 0.08, type: 'sine', decay: true),
        
        // Navigation sounds
        'nav_forward': _generateSweep(400, 800, 0.1),
        'nav_back': _generateSweep(800, 400, 0.1),
        'tab_switch': _generateTone(700, 0.05, type: 'sine', decay: true),
        
        // Success sounds
        'success_small': _generateChord([523, 659], 0.15), // C5, E5
        'success': _generateChord([523, 659, 784], 0.2), // C5, E5, G5
        'success_big': _generateArpeggio([523, 659, 784, 1047], 0.4), // C5, E5, G5, C6
        
        // Error/Warning sounds
        'error': _generateChord([220, 233], 0.2), // Dissonant
        'warning': _generateTone(350, 0.15, type: 'square', decay: false),
        'wrong': _generateSweep(400, 200, 0.15),
        
        // Letter/Selection sounds
        'letter': _generateTone(880, 0.04, type: 'sine', decay: true),
        'letter_correct': _generateCorrectSound(),
        'letter_wrong': _generateWrongSound(),
        
        // Game/Educational sounds
        'reveal': _generateSweep(300, 600, 0.15),
        'hint': _generateChord([392, 494], 0.2), // G4, B4
        'progress': _generateTone(659, 0.08, type: 'sine', decay: true),
        'audio_start': _generateTone(440, 0.05, type: 'sine', decay: true),
        
        // Celebration sounds
        'lesson_complete': _generateCelebration(),
        'submodule_complete': _generateBigCelebration(),
        'module_complete': _generateFanfare(),
        
        // Notification sounds
        'notification': _generateChord([659, 784], 0.2),
        'pop': _generateTone(1000, 0.03, type: 'sine', decay: true),
      };
      
      // Write all sounds to files
      for (final entry in soundDefinitions.entries) {
        final filePath = '${soundsDir.path}/${entry.key}.wav';
        final file = File(filePath);
        await file.writeAsBytes(entry.value);
        _soundPaths[entry.key] = filePath;
      }
      
      debugPrint('🔊 Generated ${_soundPaths.length} sound effects');
    } catch (e) {
      debugPrint('🔊 Error generating sounds: $e');
    }
  }
  
  /// Enable or disable sounds globally
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  bool get isEnabled => _enabled;
  
  /// Set volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }
  
  double get volume => _volume;
  
  /// Dispose all players and clean up sound files
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    _soundPaths.clear();
    _initialized = false;
  }
  
  /// Get next player from pool (round-robin)
  AudioPlayer _getNextPlayer() {
    final player = _players[_currentPlayerIndex];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _poolSize;
    return player;
  }
  
  /// Play a cached sound
  Future<void> _playSound(String soundName) async {
    if (!_enabled || !_initialized || _volume == 0 || _players.isEmpty) return;
    
    final filePath = _soundPaths[soundName];
    if (filePath == null) return;
    
    // Verify file exists
    final file = File(filePath);
    if (!await file.exists()) return;
    
    try {
      final player = _getNextPlayer();
      await player.stop();
      await player.setVolume(_volume);
      
      // Use UrlSource with file:// prefix for better cross-platform support
      final fileUrl = Uri.file(filePath).toString();
      await player.play(UrlSource(fileUrl));
    } catch (_) {
      // Silently fail - haptics will still work
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOUND GENERATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Generate a simple tone with optional decay
  Uint8List _generateTone(
    double frequency,
    double duration, {
    String type = 'sine',
    bool decay = true,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample;
      
      switch (type) {
        case 'square':
          sample = sin(2 * pi * frequency * t) > 0 ? 0.8 : -0.8;
          break;
        case 'triangle':
          sample = 2 * (t * frequency - (t * frequency + 0.5).floor()).abs() - 1;
          break;
        default: // sine
          sample = sin(2 * pi * frequency * t);
      }
      
      // Apply decay envelope
      if (decay) {
        final envelope = exp(-3 * t / duration);
        sample *= envelope;
      }
      
      samples[i] = sample * 0.9; // Full volume
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a frequency sweep
  Uint8List _generateSweep(double startFreq, double endFreq, double duration) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = t / duration;
      final freq = startFreq + (endFreq - startFreq) * progress;
      final envelope = exp(-2 * t / duration);
      samples[i] = sin(2 * pi * freq * t) * envelope * 0.9;
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a chord (multiple frequencies at once)
  Uint8List _generateChord(List<int> frequencies, double duration) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sum = 0;
      for (final freq in frequencies) {
        sum += sin(2 * pi * freq * t);
      }
      final envelope = exp(-3 * t / duration);
      samples[i] = (sum / frequencies.length) * envelope * 0.85;
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate an arpeggio (notes played in sequence)
  Uint8List _generateArpeggio(List<int> frequencies, double totalDuration) {
    const sampleRate = 44100;
    final noteLength = totalDuration / frequencies.length;
    final numSamples = (sampleRate * totalDuration).toInt();
    final samples = Float64List(numSamples);
    
    for (int noteIndex = 0; noteIndex < frequencies.length; noteIndex++) {
      final freq = frequencies[noteIndex];
      final noteStart = (noteIndex * noteLength * sampleRate).toInt();
      final noteSamples = (noteLength * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        final envelope = exp(-4 * t / noteLength);
        samples[noteStart + i] += sin(2 * pi * freq * t) * envelope * 0.8;
      }
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a cheerful "correct" sound - bright rising ding
  Uint8List _generateCorrectSound() {
    const sampleRate = 44100;
    const duration = 0.2;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    // Two quick rising notes - like a cheerful "ding-ding!"
    final notes = [
      (1319, 0.0, 0.12),  // E6
      (1760, 0.08, 0.12), // A6 - higher, brighter
    ];
    
    for (final (freq, start, length) in notes) {
      final noteStart = (start * sampleRate).toInt();
      final noteSamples = (length * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        // Quick attack, pleasant decay
        final attack = (t < 0.005) ? t / 0.005 : 1.0;
        final decay = exp(-8 * t / length);
        final envelope = attack * decay;
        
        // Bell-like harmonics
        final fundamental = sin(2 * pi * freq * t);
        final second = sin(2 * pi * freq * 2.0 * t) * 0.3;
        final third = sin(2 * pi * freq * 3.0 * t) * 0.1;
        
        samples[noteStart + i] += (fundamental + second + third) * envelope * 0.7;
      }
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a gentle "wrong" sound - descending tone, clearly different
  Uint8List _generateWrongSound() {
    const sampleRate = 44100;
    const duration = 0.25;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    // Descending "bonk" sound - goes down instead of up
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      
      // Frequency drops from 400Hz to 200Hz
      final freq = 400 - (200 * t / duration);
      
      // Quick attack, medium decay
      final attack = (t < 0.01) ? t / 0.01 : 1.0;
      final decay = exp(-6 * t / duration);
      final envelope = attack * decay;
      
      // Slightly hollow sound (fundamental + slight octave below)
      final fundamental = sin(2 * pi * freq * t);
      final subOctave = sin(2 * pi * freq * 0.5 * t) * 0.3;
      
      samples[i] = (fundamental + subOctave) * envelope * 0.7;
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a pleasant celebration sound for lesson completion
  /// Bright, uplifting chime with sparkle effect
  Uint8List _generateCelebration() {
    const sampleRate = 44100;
    const duration = 0.6;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    // Rising bright chimes - C major with sparkle
    final chimes = [
      (1047, 0.0, 0.25),   // C6
      (1319, 0.08, 0.22),  // E6
      (1568, 0.16, 0.20),  // G6
      (2093, 0.24, 0.35),  // C7 - highest, held longer
    ];
    
    for (final (freq, start, length) in chimes) {
      final noteStart = (start * sampleRate).toInt();
      final noteSamples = (length * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        // Bell-like envelope: quick attack, slow decay
        final attack = (t < 0.01) ? t / 0.01 : 1.0;
        final decay = exp(-5 * t / length);
        final envelope = attack * decay;
        
        // Bell harmonics for a pleasant chime
        final fundamental = sin(2 * pi * freq * t);
        final second = sin(2 * pi * freq * 2.0 * t) * 0.5;
        final third = sin(2 * pi * freq * 3.0 * t) * 0.25;
        final fourth = sin(2 * pi * freq * 4.17 * t) * 0.1; // Slight detuning for shimmer
        
        samples[noteStart + i] += (fundamental + second + third + fourth) * envelope * 0.5;
      }
    }
    
    // Add subtle sparkle/shimmer overlay
    final shimmerFreqs = [3520.0, 4186.0, 4699.0]; // High frequencies for sparkle
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      if (t > 0.15 && t < 0.5) {
        final shimmerEnv = exp(-8 * (t - 0.15));
        for (final freq in shimmerFreqs) {
          samples[i] += sin(2 * pi * freq * t) * shimmerEnv * 0.08;
        }
      }
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a bigger celebration for submodule completion
  /// Fuller, more triumphant sound
  Uint8List _generateBigCelebration() {
    const sampleRate = 44100;
    const duration = 1.0;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    // Triumphant chord progression
    final notes = [
      // First chord - C major
      (523, 0.0, 0.35),   // C5
      (659, 0.0, 0.35),   // E5
      (784, 0.0, 0.35),   // G5
      // Rising to higher C major
      (784, 0.25, 0.30),  // G5
      (988, 0.25, 0.30),  // B5
      (1175, 0.25, 0.30), // D6
      // Final triumphant chord
      (1047, 0.50, 0.50), // C6
      (1319, 0.50, 0.50), // E6
      (1568, 0.50, 0.50), // G6
      (2093, 0.55, 0.45), // C7 - top note slightly delayed for sparkle
    ];
    
    for (final (freq, start, length) in notes) {
      final noteStart = (start * sampleRate).toInt();
      final noteSamples = (length * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        final attack = (t < 0.015) ? t / 0.015 : 1.0;
        final decay = exp(-3.5 * t / length);
        final envelope = attack * decay;
        
        // Rich harmonics
        final fundamental = sin(2 * pi * freq * t);
        final second = sin(2 * pi * freq * 2.0 * t) * 0.4;
        final third = sin(2 * pi * freq * 3.0 * t) * 0.2;
        
        samples[noteStart + i] += (fundamental + second + third) * envelope * 0.35;
      }
    }
    
    // Add sparkle at the end
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      if (t > 0.5) {
        final sparkleEnv = exp(-6 * (t - 0.5));
        samples[i] += sin(2 * pi * 3520 * t) * sparkleEnv * 0.1;
        samples[i] += sin(2 * pi * 4186 * t) * sparkleEnv * 0.08;
      }
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Generate a fanfare for major achievements (module completion)
  /// Grand, orchestral feel with brass-like tones
  Uint8List _generateFanfare() {
    const sampleRate = 44100;
    const duration = 1.2;
    final numSamples = (sampleRate * duration).toInt();
    final samples = Float64List(numSamples);
    
    // Triumphant fanfare - brass-like
    final fanfareNotes = [
      // Opening flourish
      (392, 0.0, 0.12),   // G4
      (523, 0.10, 0.12),  // C5
      (659, 0.20, 0.15),  // E5
      (784, 0.33, 0.20),  // G5
      // Hold and resolve
      (1047, 0.50, 0.35), // C6 - triumphant peak
      (784, 0.80, 0.15),  // G5
      (1047, 0.92, 0.28), // C6 - final resolve
    ];
    
    for (final (freq, start, length) in fanfareNotes) {
      final noteStart = (start * sampleRate).toInt();
      final noteSamples = (length * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        // Brass-like envelope
        final attack = (t < 0.02) ? t / 0.02 : 1.0;
        final sustain = (t < length * 0.7) ? 1.0 : exp(-5 * (t - length * 0.7) / (length * 0.3));
        final envelope = attack * sustain;
        
        // Brass harmonics (odd harmonics for trumpet-like)
        final fundamental = sin(2 * pi * freq * t);
        final third = sin(2 * pi * freq * 3.0 * t) * 0.35;
        final fifth = sin(2 * pi * freq * 5.0 * t) * 0.15;
        final seventh = sin(2 * pi * freq * 7.0 * t) * 0.08;
        
        samples[noteStart + i] += (fundamental + third + fifth + seventh) * envelope * 0.45;
      }
    }
    
    // Add bass support
    final bassNotes = [
      (131, 0.0, 0.5),    // C3
      (196, 0.5, 0.7),    // G3
    ];
    
    for (final (freq, start, length) in bassNotes) {
      final noteStart = (start * sampleRate).toInt();
      final noteSamples = (length * sampleRate).toInt();
      
      for (int i = 0; i < noteSamples && (noteStart + i) < numSamples; i++) {
        final t = i / sampleRate;
        final envelope = exp(-2 * t / length);
        samples[noteStart + i] += sin(2 * pi * freq * t) * envelope * 0.25;
      }
    }
    
    // Cymbal shimmer at peak
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      if (t > 0.48 && t < 0.9) {
        final shimmerEnv = exp(-4 * (t - 0.48));
        // White noise-ish shimmer using multiple high frequencies
        samples[i] += sin(2 * pi * 5274 * t + sin(t * 100)) * shimmerEnv * 0.06;
        samples[i] += sin(2 * pi * 6645 * t + sin(t * 150)) * shimmerEnv * 0.05;
        samples[i] += sin(2 * pi * 7902 * t + sin(t * 200)) * shimmerEnv * 0.04;
      }
    }
    
    return _samplesToWav(samples, sampleRate);
  }
  
  /// Convert float samples to WAV format
  Uint8List _samplesToWav(Float64List samples, int sampleRate) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16-bit samples
    final fileSize = 44 + dataSize;
    
    final buffer = ByteData(fileSize);
    var offset = 0;
    
    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E
    
    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // space
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // audio format (PCM)
    offset += 2;
    buffer.setUint16(offset, 1, Endian.little); // num channels (mono)
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, sampleRate * 2, Endian.little); // byte rate
    offset += 4;
    buffer.setUint16(offset, 2, Endian.little); // block align
    offset += 2;
    buffer.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;
    
    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;
    
    // Audio data
    for (int i = 0; i < numSamples; i++) {
      // Clamp and convert to 16-bit
      final clamped = samples[i].clamp(-1.0, 1.0);
      final sample = (clamped * 32767).toInt();
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
    
    return buffer.buffer.asUint8List();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC SOUND METHODS - UI INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Soft tap sound - for subtle interactions
  Future<void> tap() => _playSound('tap');
  
  /// Click sound - for button presses
  Future<void> click() => _playSound('click');
  
  /// Selection sound - for selecting items
  Future<void> select() => _playSound('select');
  
  /// Pop sound - for appearing elements
  Future<void> pop() => _playSound('pop');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC SOUND METHODS - NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Navigation forward sound
  Future<void> navForward() => _playSound('nav_forward');
  
  /// Navigation back sound
  Future<void> navBack() => _playSound('nav_back');
  
  /// Tab switch sound
  Future<void> tabSwitch() => _playSound('tab_switch');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC SOUND METHODS - FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Success sound (small)
  Future<void> successSmall() => _playSound('success_small');
  
  /// Success sound (standard)
  Future<void> success() => _playSound('success');
  
  /// Success sound (big achievement)
  Future<void> successBig() => _playSound('success_big');
  
  /// Error sound
  Future<void> error() => _playSound('error');
  
  /// Warning sound
  Future<void> warning() => _playSound('warning');
  
  /// Wrong answer sound
  Future<void> wrong() => _playSound('wrong');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC SOUND METHODS - EDUCATIONAL / GAME
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Letter selection sound
  Future<void> letterSelect() => _playSound('letter');
  
  /// Correct letter/answer sound
  Future<void> letterCorrect() => _playSound('letter_correct');
  
  /// Wrong letter/answer sound
  Future<void> letterWrong() => _playSound('letter_wrong');
  
  /// Reveal sound - showing hidden content
  Future<void> reveal() => _playSound('reveal');
  
  /// Hint sound
  Future<void> hint() => _playSound('hint');
  
  /// Progress sound
  Future<void> progress() => _playSound('progress');
  
  /// Audio start sound (when starting audio playback)
  Future<void> audioStart() => _playSound('audio_start');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC SOUND METHODS - ACHIEVEMENTS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Lesson complete sound
  Future<void> lessonComplete() => _playSound('lesson_complete');
  
  /// Submodule complete sound
  Future<void> submoduleComplete() => _playSound('submodule_complete');
  
  /// Module complete sound (fanfare!)
  Future<void> moduleComplete() => _playSound('module_complete');
  
  /// Notification sound
  Future<void> notification() => _playSound('notification');
}

