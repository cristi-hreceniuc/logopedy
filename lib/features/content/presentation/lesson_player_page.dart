// lib/features/content/presentation/lesson_player_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/audio_cache_service.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/services/s3_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../kid/data/kid_api.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/enums.dart';

class LessonPlayerPage extends StatefulWidget {
  const LessonPlayerPage({
    super.key,
    required this.profileId,
    required this.lessonId,
    required this.title,
    this.isAlreadyDone = false,
    this.isKid = false,
  });

  final int profileId;
  final int lessonId;
  final String title;
  final bool isAlreadyDone;
  final bool isKid;

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

// ——— Cards comune ———
class _TitleCard extends StatelessWidget {
  const _TitleCard(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  const _BodyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

// buton consistent jos
Widget _primaryBottomButton(
  BuildContext context,
  String label,
  VoidCallback onTap,
) {
  return FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

// helpers simple (dacă nu le ai deja în fișier)
Widget _gap([double h = 12]) => SizedBox(height: h);

/// Helper function to decode MySQL's base64-encoded JSON strings.
/// MySQL uses the format: base64:type##:actualBase64Content
String _decodeBase64String(String input) {
  if (!input.startsWith('base64:')) return input;

  try {
    final parts = input.split(':');
    if (parts.length < 3) return input;

    // Join all parts after the type (in case the content contains colons)
    var base64Content = parts.sublist(2).join(':');

    // Normalize the base64 string - remove any whitespace/newlines
    base64Content = base64Content.replaceAll(RegExp(r'\s'), '');

    // Convert URL-safe base64 to standard base64 if needed
    base64Content = base64Content.replaceAll('-', '+').replaceAll('_', '/');

    // Normalize using Dart's base64Url codec (handles padding automatically)
    final normalized = base64Url.normalize(base64Content);

    // Decode the base64 string to UTF-8
    final decoded = utf8.decode(base64Url.decode(normalized));
    return decoded;
  } catch (e) {
    debugPrint('❌ Error decoding base64 string: $e');
    debugPrint('   Input length: ${input.length}');
    // Try alternative decoding method
    try {
      final parts = input.split(':');
      if (parts.length >= 3) {
        var base64Content = parts.sublist(2).join(':');
        base64Content = base64Content.replaceAll(RegExp(r'\s'), '');
        // Add padding manually if needed
        while (base64Content.length % 4 != 0) {
          base64Content += '=';
        }
        final decoded = utf8.decode(base64.decode(base64Content));
        return decoded;
      }
    } catch (e2) {
      debugPrint('❌ Alternative decode also failed: $e2');
    }
    return input;
  }
}

String _s(Map? m, String k, [String fb = '']) {
  final v = m?[k];
  if (v is String) {
    return _decodeBase64String(v);
  }
  return fb;
}

List _l(Map? m, String k) {
  final v = m?[k];
  return v is List ? v : const [];
}

List<String> _sxList(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is List && v.isNotEmpty) {
      return v.map((e) {
        if (e is String) return _decodeBase64String(e);
        if (e is Map && e['text'] is String) {
          return _decodeBase64String(e['text'] as String);
        }
        return '$e';
      }).toList();
    }
  }
  return const [];
}

/// Hint overlay widget that shows hint text and fades out
class _HintOverlay extends StatefulWidget {
  const _HintOverlay({required this.hint, required this.onDismiss});

  final String hint;
  final VoidCallback onDismiss;

  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    // Calculate fade out duration based on text length
    final baseDuration = widget.hint.length * 50; // 50ms per character
    final seconds = (baseDuration / 1000).clamp(2.0, 8.0);
    final fadeOutDuration = Duration(milliseconds: (seconds * 1000).round());

    // Start fade out after showing
    Future.delayed(fadeOutDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: const Color(0xFFEA2233),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Indiciu',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: widget.onDismiss,
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.hint,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  late final ContentRepository _repo = ContentRepository(GetIt.I<DioClient>());
  late final KidApi _kidApi = KidApi(GetIt.I<DioClient>());
  late final S3Service _s3 = GetIt.I<S3Service>();
  late final AudioCacheService _audioCache = GetIt.I<AudioCacheService>();
  late final FeedbackService _feedback = GetIt.I<FeedbackService>();
  final _player = AudioPlayer();

  LessonDto? _data;
  String? _error;
  bool _loading = true;

  // Timer for minimum screen duration (per screen, not per lesson)
  Timer? _screenTimer;
  int _elapsedSeconds = 0;
  int _minimumSeconds = 10; // Default, will be overridden by screen payload

  // Hint overlay state
  bool _showHint = false;

  // Track if any progress was made during this session (for back navigation)
  bool _progressMade = false;

  @override
  void initState() {
    super.initState();

    // 1) Set player mode FIRST - use mediaPlayer for BytesSource support
    _player.setPlayerMode(PlayerMode.mediaPlayer);

    // 2) Set release mode
    _player.setReleaseMode(ReleaseMode.stop);

    // 3) Set audio context - keep it simple for iOS
    _player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          // redă chiar dacă telefonul e pe mute / switch silențios
          category: AVAudioSessionCategory.playback,
          options: {},
        ),
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          isSpeakerphoneOn: true,
        ),
      ),
    );

    // (opțional) log pentru debugging
    _player.onPlayerStateChanged.listen((s) => debugPrint('AUDIO state: $s'));
    _player.onPlayerComplete.listen((_) => debugPrint('AUDIO complete'));

    // Listen for errors
    _player.eventStream.listen(
      (event) {
        if (event.eventType == AudioEventType.log) {
          debugPrint('🎵 Audio log: ${event.logMessage}');
        }
      },
      onError: (error) {
        debugPrint('\x1B[31mAudioPlayers Exception: $error\x1B[0m');
      },
    );

    _load();
  }

  void _startTimer({int? minSeconds}) {
    _elapsedSeconds = 0;
    _minimumSeconds =
        minSeconds ?? 10; // Use provided minSeconds or default to 10
    _screenTimer?.cancel();
    _screenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _completeTimer() {
    if (mounted) {
      setState(() {
        _elapsedSeconds = _minimumSeconds;
      });
    }
  }

  bool get _canFinishLesson => _elapsedSeconds >= _minimumSeconds;

  int _getMinSecondsFromPayload(Map<String, dynamic> payload) {
    final minSec = payload['minSeconds'];
    if (minSec is int) return minSec;
    if (minSec is String) return int.tryParse(minSec) ?? 10;
    return 10; // Default to 10 seconds
  }

  @override
  void dispose() {
    _screenTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _showHintOverlay() {
    if (_data?.hint == null || _data!.hint!.isEmpty) return;

    // Play hint feedback
    _feedback.hint();

    // Hide previous hint if showing, then show new one
    if (_showHint) {
      setState(() {
        _showHint = false;
      });
      // Wait a bit before showing new hint to allow fade out
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showHint = true;
          });
        }
      });
    } else {
      setState(() {
        _showHint = true;
      });
    }
  }

  // ---------------- helpers “type-safe” pentru payload ----------------
  Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

  List<Map<String, dynamic>> _asListOfMap(Object? v) =>
      v is List ? v.map(_asMap).toList() : const <Map<String, dynamic>>[];

  List _asList(Object? v) => v is List ? v : const [];

  String _asString(Object? v, [String fb = '']) => v is String ? v : fb;

  /// Extrage `uri` dintr-un obiect asset { uri: 'assets/...' }.
  String _assetUri(Object? v) => _asMap(v)['uri'] as String? ?? '';

  /// Construiește calea completă către un asset local.
  /// Ex: _asset('img', 'masa') -> 'assets/images/masa.png'
  String _asset(String folder, String filename) {
    final folderPath = folder == 'img' ? 'images' : folder;
    final extension = folder == 'img' ? 'png' : 'mp3';

    // Dacă filename-ul are deja extensie, o folosim
    if (filename.contains('.')) {
      return 'assets/$folderPath/$filename';
    }
    return 'assets/$folderPath/$filename.$extension';
  }

  /// Convenție pentru butoane (next/back) – payload.buttons e Map.
  Map<String, dynamic> _buttons(Map<String, dynamic> p) => _asMap(p['buttons']);

  InlineSpan _maskedSpan({
    required String masked,
    required String answer,
    required TextStyle base,
    required TextStyle accent,
    required bool revealed,
  }) {
    if (!revealed) return TextSpan(text: masked, style: base);

    final match = RegExp('_+').firstMatch(masked);
    if (match == null) return TextSpan(text: masked, style: base);

    final before = masked.substring(0, match.start);
    final after = masked.substring(match.end);
    return TextSpan(
      children: [
        TextSpan(text: before, style: base),
        TextSpan(text: answer, style: accent),
        TextSpan(text: after, style: base),
      ],
    );
  }

  TextSpan _coloredMaskedWord(
    String masked,
    String letter,
    TextStyle base,
    TextStyle highlight,
  ) {
    final spans = <TextSpan>[];
    bool inserted = false;

    for (var i = 0; i < masked.length; i++) {
      final ch = masked[i];

      if (ch == '_') {
        if (inserted) {
          // dacă am completat deja o dată, sărim peste al doilea/ al treilea '_'
          continue;
        }

        final prev = i > 0 ? masked[i - 1] : null;
        final next = i + 1 < masked.length ? masked[i + 1] : null;
        final dupLeft =
            prev != null && prev.toLowerCase() == letter.toLowerCase();
        final dupRight =
            next != null && next.toLowerCase() == letter.toLowerCase();

        if (dupLeft || dupRight) {
          // nu inserăm litera ca să nu obținem „sscap” etc.
          continue;
        }

        spans.add(TextSpan(text: letter, style: highlight));
        inserted = true;
      } else {
        spans.add(TextSpan(text: ch, style: base));
      }
    }

    return TextSpan(children: spans, style: base);
  }

  /// Get full URL/path for image or audio
  /// Handles S3 keys, full URLs, and legacy asset paths
  String _getMediaUrl(String uriOrKey) {
    if (uriOrKey.isEmpty) return '';

    // Already a full URL
    if (uriOrKey.startsWith('http://') || uriOrKey.startsWith('https://')) {
      return uriOrKey;
    }

    // S3 key - construct full URL
    if (uriOrKey.startsWith('modules/')) {
      return _s3.getFullUrl(uriOrKey);
    }

    // Legacy assets path - return as-is
    if (uriOrKey.startsWith('assets/')) {
      return uriOrKey;
    }

    // Assume it's an S3 key without the full path
    return _s3.getFullUrl(uriOrKey);
  }

  /// Load image from S3, URL, or assets
  Widget _buildImage(
    String uriOrKey, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final url = _getMediaUrl(uriOrKey);
    if (url.isEmpty) {
      return Container(
        width: width ?? 240,
        height: height ?? 240,
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Load from network (S3) with caching
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width ?? 240,
          height: height ?? 240,
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: width ?? 240,
          height: height ?? 240,
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
        ),
      );
    } else {
      // Load from assets
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width ?? 240,
          height: height ?? 240,
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
        ),
      );
    }
  }

  String _s(Map? m, String k, [String fb = '']) {
    final v = m?[k];
    if (v is String) {
      return _decodeBase64String(v);
    }
    return fb;
  }

  List _l(Map? m, String k) {
    final v = m?[k];
    return v is List ? v : const [];
  }

  Widget _gap([double h = 12]) => SizedBox(height: h);

  // ---------------- Error handling ----------------
  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;

      // Try multiple possible error message formats from backend
      String? errorMessage;

      if (data is Map<String, dynamic>) {
        // Try common error message fields
        errorMessage =
            data['message'] as String? ??
            data['error'] as String? ??
            data['errorMessage'] as String? ??
            data['msg'] as String?;

        // If still no message, try errors array/object
        if (errorMessage == null && data['errors'] != null) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            errorMessage = (data['errors'] as List).first.toString();
          } else if (data['errors'] is Map) {
            final errorsMap = data['errors'] as Map;
            // Get first error value
            if (errorsMap.isNotEmpty) {
              final firstError = errorsMap.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                errorMessage = firstError.first.toString();
              } else {
                errorMessage = firstError.toString();
              }
            }
          }
        }
      }

      // If we have a specific error message, return it
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return errorMessage;
      }

      // Handle specific HTTP status codes with user-friendly messages
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        switch (statusCode) {
          case 401:
            return 'Autentificare necesară. Te rog autentifică-te din nou.';
          case 403:
            return 'Acces interzis. Nu ai permisiunea de a accesa această resursă.';
          case 404:
            return 'Lecția nu a fost găsită.';
          case 422:
            return 'Date invalide. Te rog verifică informațiile.';
          case 429:
            return 'Prea multe încercări. Te rog așteaptă un moment.';
          case 500:
          case 502:
          case 503:
            return 'Eroare de server. Te rog încearcă mai târziu.';
          default:
            return e.message ??
                'Eroare la încărcarea lecției. Te rog încearcă din nou.';
        }
      }

      return e.message ?? 'Eroare de rețea. Te rog încearcă din nou.';
    }
    return e.toString();
  }

  // ---------------- API calls ----------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LessonDto d;
      if (widget.isKid) {
        final json = await _kidApi.getLesson(widget.lessonId);
        d = LessonDto.fromJson(json);
      } else {
        d = await _repo.getLesson(widget.profileId, widget.lessonId);
      }
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
      // Reset and restart timer when lesson loads with screen-specific duration
      // Skip timer if lesson is already done
      if (_data!.screens.isNotEmpty && !widget.isAlreadyDone) {
        final firstScreen = _data!.screens.first;
        final minSeconds = _getMinSecondsFromPayload(firstScreen.payload);
        _startTimer(minSeconds: minSeconds);
      } else if (widget.isAlreadyDone) {
        // For already done lessons, set timer to completed state immediately
        _elapsedSeconds = _minimumSeconds;
      }
      // debug payload
      for (final sc in _data!.screens) {
        debugPrint('SCREEN ${sc.screenType} => ${sc.payload}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(LessonPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If lesson ID changed, reload and restart timer
    if (oldWidget.lessonId != widget.lessonId) {
      _load();
    }
  }

  Future<void> _playAudio(
    String uriOrKey, {
    bool waitForCompletion = false,
  }) async {
    if (uriOrKey.isEmpty) return;

    // Play audio start feedback
    _feedback.audioPlay();

    try {
      // Stop any currently playing audio
      await _player.stop();

      // Create completer if we need to wait for completion
      Completer<void>? completer;
      StreamSubscription<void>? subscription;

      if (waitForCompletion) {
        completer = Completer<void>();
        subscription = _player.onPlayerComplete.listen((_) {
          if (!completer!.isCompleted) {
            completer.complete();
          }
        });
      }

      // Check if it's an S3 key or full URL
      if (uriOrKey.startsWith('http://') || uriOrKey.startsWith('https://')) {
        // Full URL - download and cache, then play from file URL
        debugPrint('🎵 Caching and playing audio from URL: $uriOrKey');
        final localPath = await _audioCache.getLocalPath(uriOrKey);

        if (localPath != null) {
          // Verify file exists and has content
          final file = File(localPath);
          if (!await file.exists()) {
            debugPrint('❌ Cached file does not exist: $localPath');
            subscription?.cancel();
            return;
          }

          final fileSize = await file.length();
          debugPrint('🎵 Playing cached file: $localPath ($fileSize bytes)');

          // Use file:// URL for iOS compatibility
          final fileUrl = Uri.file(localPath).toString();
          debugPrint('🎵 File URL: $fileUrl');
          await _player.play(UrlSource(fileUrl), volume: 1.0);
        } else {
          debugPrint('❌ Failed to cache audio, cannot play');
          subscription?.cancel();
          return;
        }
      } else if (uriOrKey.startsWith('modules/') ||
          !uriOrKey.startsWith('assets/')) {
        // S3 key - construct full URL, download and cache, then play from file URL
        final url = _s3.getFullUrl(uriOrKey);
        debugPrint('🎵 Caching and playing audio from S3 key: $uriOrKey');
        final localPath = await _audioCache.getLocalPath(url);

        if (localPath != null) {
          // Verify file exists and has content
          final file = File(localPath);
          if (!await file.exists()) {
            debugPrint('❌ Cached file does not exist: $localPath');
            subscription?.cancel();
            return;
          }

          final fileSize = await file.length();
          debugPrint('🎵 Playing cached file: $localPath ($fileSize bytes)');

          // Verify we can read the file
          try {
            final testBytes = await file.readAsBytes();
            debugPrint('🎵 File is readable: ${testBytes.length} bytes');
            debugPrint(
              '🎵 First bytes: ${testBytes.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
            );
          } catch (e) {
            debugPrint('❌ Cannot read file: $e');
            subscription?.cancel();
            return;
          }

          // Try playing with DeviceFileSource
          debugPrint('🎵 Playing with DeviceFileSource');
          await _player.play(DeviceFileSource(localPath), volume: 1.0);
        } else {
          debugPrint('❌ Failed to cache audio, cannot play');
          subscription?.cancel();
          return;
        }
      } else {
        // Legacy assets/ path - convert to asset source
        final path = uriOrKey.startsWith('assets/')
            ? uriOrKey.substring(7)
            : uriOrKey;
        debugPrint('🎵 Playing audio from assets: $path');
        await _player.play(AssetSource(path), volume: 1.0);
      }

      // Wait for audio to complete if requested
      if (waitForCompletion && completer != null) {
        await completer.future;
        subscription?.cancel();
      }
    } catch (e, stack) {
      debugPrint('\x1B[31m❌ Failed to play audio "$uriOrKey": $e\x1B[0m');
      debugPrint('Stack: $stack');
      // Don't rethrow - just log the error so the app doesn't crash
    }
  }

  /// Check if a lesson exists by trying to load it
  Future<bool> _lessonExists(int lessonId) async {
    try {
      if (widget.isKid) {
        await _kidApi.getLesson(lessonId);
      } else {
        await _repo.getLesson(widget.profileId, lessonId);
      }
      return true;
    } catch (e) {
      debugPrint('🎉 Lesson $lessonId does not exist: $e');
      return false;
    }
  }

  Future<void> _showCompletionDialog(
    bool endOfLesson,
    bool endOfSubmodule,
    bool endOfModule,
  ) async {
    debugPrint(
      '🎉 _showCompletionDialog() called - endOfLesson: $endOfLesson, endOfSubmodule: $endOfSubmodule, endOfModule: $endOfModule',
    );

    // Play celebration feedback based on achievement level
    if (endOfModule) {
      _feedback.moduleComplete();
    } else if (endOfSubmodule) {
      _feedback.submoduleComplete();
    } else if (endOfLesson) {
      _feedback.lessonComplete();
    }

    // Determine which image and message to show
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suffix = isDark ? '_dark' : '';
    String imagePath;
    String message;

    if (endOfModule) {
      imagePath = 'assets/images/finish_module$suffix.png';
      message = 'Excelent! Ai terminat modulul!';
    } else if (endOfSubmodule) {
      imagePath = 'assets/images/finish_submodule$suffix.png';
      message = 'Felicitări! Ai terminat submodulul!';
    } else if (endOfLesson) {
      imagePath = 'assets/images/finish_lesson$suffix.png';
      message = 'Bravo! Ai terminat lecția!';
    } else {
      // Fallback - show lesson completion
      imagePath = 'assets/images/finish_lesson$suffix.png';
      message = 'Bravo! Ai terminat lecția!';
    }

    // Use a timer for auto-dismiss after 4 seconds
    Timer? autoCloseTimer;

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) {
        debugPrint('🎉 Building completion dialog with image: $imagePath');

        // Start the 4-second auto-close timer
        autoCloseTimer = Timer(const Duration(seconds: 4), () {
          if (Navigator.of(dialogContext).canPop()) {
            debugPrint('🎉 Auto-closing completion dialog after 4 seconds');
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          elevation: 8,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  debugPrint(
                    '🎉 User tapped on dialog to continue immediately',
                  );
                  // Cancel the auto-close timer since user tapped
                  autoCloseTimer?.cancel();
                  Navigator.of(dialogContext).pop();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Completion image based on level - wrapped to ensure taps work
                      GestureDetector(
                        onTap: () {
                          debugPrint(
                            '🎉 User tapped on image to continue immediately',
                          );
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Image.asset(
                          imagePath,
                          width: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('🎉 Error loading $imagePath: $error');
                            return Container(
                              width: 300,
                              height: 300,
                              color: Colors.red.withOpacity(0.3),
                              child: const Center(
                                child: Text(
                                  'Image Error',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          debugPrint(
                            '🎉 User tapped on message text to continue immediately',
                          );
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          debugPrint(
                            '🎉 User tapped on instruction text to continue immediately',
                          );
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          'Apasă oriunde pentru a continua',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Cancel timer if it's still running (shouldn't happen, but safety check)
    autoCloseTimer?.cancel();
    debugPrint('🎉 Completion dialog dismissed, proceeding to next lesson');
  }

  /// Lecțiile actuale au 1 singur ecran -> marcăm DONE și ieșim
  Future<void> _finishLesson({bool skipCompletionDialog = false}) async {
    try {
      final AdvanceResp resp;
      if (widget.isKid) {
        final json = await _kidApi.advanceProgress(
          lessonId: widget.lessonId,
          screenIndex: 0,
          done: true,
        );
        resp = AdvanceResp.fromJson(json);
      } else {
        resp = await _repo.advance(
          widget.profileId,
          lessonId: widget.lessonId,
          screenIndex: 0,
          done: true,
        );
      }
      if (!mounted) return;

      // Mark that progress was made (lesson completed)
      _progressMade = true;

      // Debug: Log the response to see what flags are set
      debugPrint(
        '🎉 API Response: endOfLesson=${resp.endOfLesson}, endOfSubmodule=${resp.endOfSubmodule}, endOfModule=${resp.endOfModule}',
      );
      debugPrint(
        '🎉 Current lesson data: moduleId=${resp.moduleId}, submoduleId=${resp.submoduleId}, lessonId=${resp.lessonId}, screenIndex=${resp.screenIndex}',
      );
      debugPrint(
        '🎉 Next lesson data: nextModuleId=${resp.nextModuleId}, nextSubmoduleId=${resp.nextSubmoduleId}, nextLessonId=${resp.nextLessonId}',
      );

      // arată GIF la final de lecție / submodul / modul (alege condiția dorită)
      final shouldCelebrate =
          resp.endOfLesson || resp.endOfSubmodule || resp.endOfModule;
      debugPrint('🎉 Should celebrate: $shouldCelebrate');

      // Show completion dialog unless skipped
      if (!skipCompletionDialog) {
        debugPrint('🎉 Showing completion dialog!');
        await _showCompletionDialog(
          resp.endOfLesson,
          resp.endOfSubmodule,
          resp.endOfModule,
        );
      }

      // Navigate to next lesson if available, otherwise go back to submodule
      if (mounted) {
        // Determine the next lesson ID to navigate to
        // Priority 1: Use explicit nextLessonId from backend
        // Priority 2: If lessonId in response is different and we're not at an end, use that
        int? targetLessonId;

        if (resp.nextLessonId != null &&
            resp.nextLessonId! > 0 &&
            resp.nextLessonId! != widget.lessonId) {
          // Backend explicitly provided next lesson ID
          targetLessonId = resp.nextLessonId;
          debugPrint(
            '🎉 Using explicit nextLessonId from backend: $targetLessonId',
          );
        } else if (!resp.endOfSubmodule &&
            !resp.endOfModule &&
            resp.lessonId != widget.lessonId &&
            resp.lessonId > widget.lessonId) {
          // Backend returned a different lessonId that's greater than current - likely the next lesson
          targetLessonId = resp.lessonId;
          debugPrint(
            '🎉 Using updated lessonId from backend as next lesson: $targetLessonId',
          );
        }

        debugPrint(
          '🎉 Navigation check - targetLessonId: $targetLessonId, widget.lessonId: ${widget.lessonId}, resp.lessonId: ${resp.lessonId}, resp.nextLessonId: ${resp.nextLessonId}',
        );
        debugPrint(
          '🎉 End flags - endOfSubmodule: ${resp.endOfSubmodule}, endOfModule: ${resp.endOfModule}',
        );

        if (targetLessonId != null) {
          final nextLessonId = targetLessonId; // Non-null variable for clarity
          debugPrint('🎉 Attempting to navigate to next lesson: $nextLessonId');
          // Verify the lesson exists before navigating (to prevent 404 errors)
          try {
            final lessonExists = await _lessonExists(nextLessonId);
            if (!lessonExists) {
              debugPrint(
                '🎉 Lesson $nextLessonId does not exist, going back to submodule',
              );
              // Add a longer delay to ensure backend has processed the lesson completion
              // This ensures the current lesson is marked as DONE before we navigate back
              debugPrint(
                '🎉 Waiting for backend to process lesson completion before navigating back...',
              );
              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted) {
                Navigator.of(context).maybePop(true);
              }
              return;
            }

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LessonPlayerPage(
                  profileId: widget.profileId,
                  lessonId: nextLessonId,
                  title:
                      'Lecția $nextLessonId', // You might want to get the actual title
                  isKid: widget.isKid,
                ),
              ),
            );
            debugPrint(
              '🎉 Successfully navigated to next lesson: $nextLessonId',
            );
          } catch (e) {
            debugPrint('🎉 Error navigating to next lesson $nextLessonId: $e');
            debugPrint('🎉 Going back to submodule due to navigation error');
            // Add a small delay to ensure backend has processed the lesson completion
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.of(context).maybePop(true);
            }
          }
        } else {
          debugPrint('🎉 No valid next lesson data, going back to submodule');
          debugPrint(
            '🎉 Next lesson ID: ${resp.nextLessonId}, Response lesson ID: ${resp.lessonId}, Widget lesson ID: ${widget.lessonId}',
          );
          // No fallback navigation - just go back to submodule
          // Add a longer delay to ensure backend has processed the lesson completion
          // This is especially important for the last lesson in a submodule
          // The backend needs time to update the lesson status to DONE
          debugPrint('🎉 Waiting for backend to process lesson completion...');
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            // Always return true to signal that data changed and submodule should refresh
            debugPrint(
              '🎉 Navigating back to submodule after lesson completion',
            );
            Navigator.of(context).maybePop(true);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      // Handle server errors (500) when trying to advance past final lesson
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 500 && statusCode < 600) {
          // Server error - likely no next lesson available
          debugPrint(
            '🎉 Server error when advancing (status $statusCode) - treating as end of lessons',
          );

          // Show completion dialog for finishing the lesson
          if (!skipCompletionDialog) {
            await _showCompletionDialog(true, false, false);
          }

          // Navigate back to submodule and signal refresh
          // Add a longer delay to ensure backend has processed the lesson completion
          // Even if we got a server error, we still want to give the backend time
          // to process the lesson completion before navigating back
          debugPrint(
            '🎉 Server error occurred, but waiting for backend to process lesson completion...',
          );
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            Navigator.of(context).maybePop(true);
          }
          return;
        }
      }

      // For other errors, still return true to allow refresh if the lesson was completed
      // This ensures the submodule page refreshes even if there was a minor error
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }

      // Show error message
      final errorMsg = _extractErrorMessage(e);
      SnackBarUtils.showError(context, errorMsg);
    }
  }

  // ---------------- UI ----------------
  Widget _buildTimerIndicator() {
    if (_canFinishLesson) {
      return const SizedBox.shrink();
    }

    final remainingSeconds = _minimumSeconds - _elapsedSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEA2233).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEA2233).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 18, color: const Color(0xFFEA2233)),
          const SizedBox(width: 6),
          Text(
            '$remainingSeconds',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEA2233),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Return progress state when user navigates back
        Navigator.of(context).pop(_progressMade);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          actions: [
            // Information button for hint
            if (_data?.hint != null && _data!.hint!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: _showHintOverlay,
                tooltip: 'Afișează indiciu',
              ),
            _buildTimerIndicator(),
            const SizedBox(width: 16),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              top: true,
              bottom: true,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFEA2233),
                        ),
                      ),
                    )
                  : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : _data == null || _data!.screens.isEmpty
                  ? const _EmptyView()
                  : _renderScreen(_data!.screens.first, cs),
            ),
            // Hint overlay
            if (_showHint && _data?.hint != null && _data!.hint!.isNotEmpty)
              _HintOverlay(
                hint: _data!.hint!,
                onDismiss: () {
                  setState(() {
                    _showHint = false;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _renderScreen(ScreenDto sc, ColorScheme cs) {
    final p = _asMap(sc.payload);

    switch (sc.screenType) {
      // 1) Text simplu
      case ScreenType.readText:
        {
          final title = _s(p, 'title');
          final text = _s(p, 'text');
          final next = _s(
            (p['buttons'] as Map? ?? const {}),
            'nextLabel',
            'Următorul',
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                // Conținutul în card, centrat și aerisit
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (title.isNotEmpty) ...[
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: cs.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Text(
                                  text,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        height: 1.5,
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Butonul mare jos, consistent cu restul aplicației
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 2) Text + subinstrucțiuni (bullets)
      case ScreenType.readTextWithSub:
        {
          List<String> sxList(Map? p, List<String> keys) {
            final List<dynamic> raw = () {
              for (final k in keys) {
                final v = p?[k];
                if (v is List && v.isNotEmpty) return v;
              }
              return const <dynamic>[];
            }();

            return raw
                .map((e) {
                  if (e is String) return _decodeBase64String(e);
                  if (e is Map && e['text'] is String) {
                    return _decodeBase64String(e['text'] as String);
                  }
                  return '';
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }

          final title = _s(p, 'title');
          final text = _s(p, 'text');
          final subtitle = _s(p, 'subtitle');
          final bullets = sxList(p, [
            'subs',
            'bullets',
            'items',
            'steps',
            'instructions',
          ]);
          final next = _s(
            (p['buttons'] as Map? ?? const {}),
            'nextLabel',
            'Următorul',
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty) ...[
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (text.isNotEmpty) ...[
                            Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    height: 1.5,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (subtitle.isNotEmpty || bullets.isNotEmpty) ...[
                            if (subtitle.isNotEmpty) ...[
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (bullets.isNotEmpty) ...[
                              ...bullets.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(
                                          top: 6,
                                          right: 12,
                                        ),
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEA2233),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          e,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontSize: 16,
                                                height: 1.5,
                                                color: cs.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 3) Paragraf(e)
      case ScreenType.readParagraph:
        {
          final title = _asString(p['title']);
          final paragraphs = _asList(p['paragraphs']);
          final text = _asString(p['text']);
          final next = _asString(_buttons(p)['nextLabel'], 'Următorul');

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty) ...[
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (paragraphs.isNotEmpty)
                            ...paragraphs.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  '$e',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 18,
                                        height: 1.6,
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            )
                          else
                            Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    height: 1.6,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 4) Imagine + cuvânt + silabe (cu audio din assets/uri)
      case ScreenType.imageWordSyllables:
        {
          final title = _asString(p['title']);
          final imgUri = _assetUri(p['image']); // { uri: 'assets/images/...' }
          final word = _asString(_asMap(p['word'])['text']);
          final wordAudioUri = _assetUri(_asMap(_asMap(p['word'])['audio']));
          final syllables = _asListOfMap(
            p['syllables'],
          ); // [{ text, audio:{uri} }, ...]
          final next = _asString(_buttons(p)['nextLabel'], 'Următorul');

          Future<void> play(String uri) async {
            await _playAudio(uri);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (title.isNotEmpty) ...[
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (imgUri.isNotEmpty) ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final orientation = MediaQuery.of(
                                  context,
                                ).orientation;
                                // Responsive image size based on orientation
                                final imageSize =
                                    orientation == Orientation.landscape
                                    ? 160.0 // Smaller in landscape
                                    : 240.0; // Normal in portrait

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildImage(
                                      imgUri,
                                      width: imageSize,
                                      height: imageSize,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (word.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D72D2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      word,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D72D2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.volume_up,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _playAudio(wordAudioUri),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (syllables.isNotEmpty) ...[
                            Text(
                              'Silabe',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: syllables.map((e) {
                                final txt = _asString(e['text']);
                                final uri = _assetUri(e['audio']);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEA2233,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFEA2233,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _playAudio(uri),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              txt,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF17406B),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.volume_up,
                                              size: 18,
                                              color: const Color(0xFFEA2233),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 5) Perechi literă lipsă
      case ScreenType.missingLetterPairs:
        {
          final cs = Theme.of(context).colorScheme;
          final title = _s(p, 'title', 'Completează litera lipsă');
          final pairs = _l(p, 'pairs');
          final next = _s(
            (p['buttons'] as Map? ?? const {}),
            'nextLabel',
            'Următorul',
          );

          // stiluri mari pentru cuvinte
          final wordStyle = Theme.of(context).textTheme.displaySmall!.copyWith(
            fontSize: 40,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          );
          final highlightStyle = wordStyle.copyWith(
            color: const Color(0xFFEA2233),
            fontWeight: FontWeight.w700,
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.separated(
                            itemCount: pairs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 20),
                            itemBuilder: (_, i) {
                              final it = (pairs[i] as Map)
                                  .cast<String, dynamic>();
                              final masked = _s(
                                it,
                                'masked',
                                _s(it, 'word'),
                              ).toUpperCase(); // "__cap" -> "__CAP"
                              final solution = _s(
                                it,
                                'solution',
                                _s(it, 'answer'),
                              ).toUpperCase(); // "s" -> "S"
                              final revealed =
                                  (it['revealed'] as bool?) ?? false;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(
                                        context,
                                      ).inputDecorationTheme.fillColor ??
                                      const Color(0xFFF2F3F6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // cuvântul — mare & centrat pe linie
                                    Expanded(
                                      child: Center(
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: revealed
                                              ? _coloredMaskedWord(
                                                  masked,
                                                  solution,
                                                  wordStyle,
                                                  highlightStyle,
                                                )
                                              : TextSpan(
                                                  text: masked,
                                                  style: wordStyle,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: revealed
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFEA2233,
                                                  ).withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: TextButton(
                                        onPressed: revealed
                                            ? null
                                            : () => setState(
                                                () => it['revealed'] = true,
                                              ),
                                        style: TextButton.styleFrom(
                                          backgroundColor: revealed
                                              ? Colors.grey[200]
                                              : const Color(0xFFEA2233),
                                          foregroundColor: revealed
                                              ? Colors.grey[600]
                                              : Colors.white,
                                          textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          revealed ? 'Arătat' : 'Arată',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 6) Imagine – literă lipsă
      case ScreenType.imageMissingLetter:
        {
          // helpers
          String imgUrl0(Map p) {
            // încearcă pe rând: imageUrl, image.uri, image (string simplu)
            final m = (p['image'] as Map?)?.cast<String, dynamic>();
            final cand = [
              _s(p, 'imageUrl'),
              _s(m, 'uri'),
              _s(p, 'image'),
            ].firstWhere((e) => e.isNotEmpty, orElse: () => '');

            if (cand.isEmpty) return '';

            // dacă e doar numele fișierului → prefix + extensie
            if (!cand.startsWith('http') && !cand.startsWith('assets/')) {
              return _asset(
                'img',
                cand,
              ); // ex: "masa" -> "assets/images/masa.png"
            }
            return cand; // deja complet
          }

          InlineSpan coloredMasked(
            String masked,
            String sol,
            TextStyle base,
            TextStyle hi,
          ) {
            // Ex: "__cap" + "s" -> "scap" cu primul 's' colorat
            final idx = masked.indexOf('_');
            if (idx < 0 || sol.isEmpty) {
              return TextSpan(text: masked, style: base);
            }
            final replaced = masked.replaceFirst('_', sol);
            return TextSpan(
              children: [
                TextSpan(text: replaced.substring(0, idx), style: base),
                TextSpan(text: sol, style: hi),
                TextSpan(text: replaced.substring(idx + 1), style: base),
              ],
            );
          }

          final cs = Theme.of(context).colorScheme;
          final title = _s(p, 'title', 'Completează');
          final imgUrl = imgUrl0(p);

          // masca poate veni ca 'masked', 'word' sau chiar 'subtitle'
          final masked = _s(
            p,
            'masked',
            _s(p, 'word', _s(p, 'subtitle')),
          ).toUpperCase();
          // soluția poate fi 'solution' sau 'answer'
          final solution = _s(p, 'solution', _s(p, 'answer')).toUpperCase();
          final next = _s(
            (p['buttons'] as Map? ?? const {}),
            'nextLabel',
            'Următorul',
          );

          final wordStyle = Theme.of(context).textTheme.displaySmall!.copyWith(
            fontSize: 40,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          );
          final hiStyle = wordStyle.copyWith(
            color: const Color(0xFFEA2233),
            fontWeight: FontWeight.w700,
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(height: 24),

                          if (imgUrl.isNotEmpty) ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final orientation = MediaQuery.of(
                                  context,
                                ).orientation;
                                // Responsive image size based on orientation
                                final imageSize =
                                    orientation == Orientation.landscape
                                    ? 160.0 // Smaller in landscape
                                    : 240.0; // Normal in portrait

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildImage(
                                      imgUrl,
                                      width: imageSize,
                                      height: imageSize,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // mască mare centrată + buton "Arată"
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).inputDecorationTheme.fillColor ??
                                  const Color(0xFFF2F3F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: StatefulBuilder(
                              builder: (ctx, setSB) {
                                final revealed =
                                    (p['revealed'] as bool?) ?? false;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: revealed
                                              ? coloredMasked(
                                                  masked,
                                                  solution,
                                                  wordStyle,
                                                  hiStyle,
                                                )
                                              : TextSpan(
                                                  text: masked,
                                                  style: wordStyle,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: revealed
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFEA2233,
                                                  ).withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: TextButton(
                                        onPressed: revealed
                                            ? null
                                            : () => setSB(
                                                () => p['revealed'] = true,
                                              ),
                                        style: TextButton.styleFrom(
                                          backgroundColor: revealed
                                              ? Colors.grey[200]
                                              : const Color(0xFFEA2233),
                                          foregroundColor: revealed
                                              ? Colors.grey[600]
                                              : Colors.white,
                                          textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          revealed ? 'Arătat' : 'Arată',
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _canFinishLesson ? _finishLesson : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canFinishLesson
                          ? const Color(0xFFEA2233)
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canFinishLesson) ...[
                          Icon(Icons.hourglass_empty, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

      // 7) Denumește imaginea (input + Ajutor)
      // 7) Denumește imaginea (input + Ajutor + validare)
      case ScreenType.imageRevealWord:
        {
          // ---- helpers
          String imgUrl0(Map p) {
            final m = (p['image'] as Map?)?.cast<String, dynamic>();
            final cand = [
              _s(p, 'imageUrl'),
              _s(m, 'uri'),
              _s(p, 'image'),
            ].firstWhere((e) => e.isNotEmpty, orElse: () => '');
            if (cand.isEmpty) return '';
            if (!cand.startsWith('http') && !cand.startsWith('assets/')) {
              return _asset(
                'img',
                cand,
              ); // ex: "soare" -> assets/images/soare.png
            }
            return cand;
          }

          // ---- payload
          final title = _s(p, 'title', 'Denumeste imaginea');
          final subtitle = _s(p, 'subtitle', 'Ce vezi în imagine?');
          final imgUrl = imgUrl0(p);

          // răspunsul corect poate fi în mai multe chei
          final correctWord = [
            _s(p, 'word'),
            _s(p, 'answer'),
            _s(p, 'solution'),
            _s(p, 'revealWord'),
          ].firstWhere((e) => e.isNotEmpty, orElse: () => '');

          final next = _s(
            (p['buttons'] as Map? ?? const {}),
            'nextLabel',
            'Următorul',
          );
          final helpLabel = _s(
            (p['buttons'] as Map? ?? const {}),
            'revealLabel',
            'Ajutor',
          );

          return _ImageRevealWordWidget(
            key: ValueKey('imageRevealWord_${widget.lessonId}'),
            title: title,
            subtitle: subtitle,
            imgUrl: imgUrl,
            correctWord: correctWord,
            nextLabel: next,
            helpLabel: helpLabel,
            payload: p,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 8) Image Selection - select correct image from 3 options
      case ScreenType.imageSelection:
        {
          final question = _s(p, 'question', 'Selectează imaginea corectă');
          final images = _asListOfMap(
            p['images'],
          ); // [{s3Key: string, correct: boolean}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _ImageSelectionWidget(
            key: ValueKey('imageSelection_${widget.lessonId}'),
            question: question,
            images: images,
            nextLabel: next,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 9) Find Sound - tap syllable containing target sound
      case ScreenType.findSound:
        {
          final question = _s(p, 'question', 'Găsește sunetul');
          final word = _s(p, 'word', '');
          final wordAudioKey = _s(p, 's3WordAudioKey', '');
          final syllables = _asListOfMap(
            p['syllables'],
          ); // [{text, s3AudioKey, correct}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FindSoundWidget(
            key: ValueKey('findSound_${widget.lessonId}'),
            question: question,
            word: word,
            wordAudioKey: wordAudioKey,
            syllables: syllables,
            nextLabel: next,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            playAudio: _playAudio,
          );
        }

      // 10) Find Missing Letter - type missing letter in word
      case ScreenType.findMissingLetter:
        {
          final question = _s(p, 'question', 'Găsește litera lipsă');
          final maskedWord = _s(p, 'maskedWord', '');
          final correctLetter = _s(p, 'correctLetter', '');
          final imageKey = _s(p, 's3ImageKey', '');
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FindMissingLetterWidget(
            key: ValueKey('findMissingLetter_${widget.lessonId}'),
            question: question,
            maskedWord: maskedWord,
            correctLetter: correctLetter,
            imageKey: imageKey,
            nextLabel: next,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 11) Find Non-Intruder - select 2 matching images from 3
      case ScreenType.findNonIntruder:
        {
          final question = _s(
            p,
            'question',
            'Selectează cele două imagini care se potrivesc',
          );
          final images = _asListOfMap(p['images']); // [{s3Key, isMatch}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FindNonIntruderWidget(
            key: ValueKey('findNonIntruder_${widget.lessonId}'),
            question: question,
            images: images,
            nextLabel: next,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 12) Format Word - order scrambled letters to form word
      // Supports two modes:
      // - Image mode: shows image + question text (s3ImageKey)
      // - Audio mode: plays audio (s3AudioQuestionKey)
      case ScreenType.formatWord:
        {
          final audioQuestionKey = _s(p, 's3AudioQuestionKey', '');
          final imageKey = _s(p, 's3ImageKey', '');
          final question = _s(p, 'question', '');
          final correctWord = _s(p, 'correctWord', '');
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FormatWordWidget(
            key: ValueKey('formatWord_${widget.lessonId}'),
            audioQuestionKey: audioQuestionKey,
            imageKey: imageKey,
            question: question,
            correctWord: correctWord,
            nextLabel: next,
            onFinish: _finishLesson,
            onCorrectAnswer: _completeTimer,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            playAudio: _playAudio,
            buildImage: _buildImage,
          );
        }

      // 13) Instructions - scrollable text
      case ScreenType.instructions:
        {
          final title = _s(p, 'title', 'Instrucțiuni');
          final text = _s(p, 'text', '');
          final instructions = _l(p, 'instructions');
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _InstructionsWidget(
            key: ValueKey('instructions_${widget.lessonId}'),
            title: title,
            text: text,
            instructions: instructions,
            nextLabel: next,
            onFinish: _finishLesson,
            onCompleteTimer: _completeTimer,
            canFinishLesson: _canFinishLesson,
          );
        }

      // fallback
      default:
        return Center(
          child: Text(
            'Tip ecran neimplementat: ${sc.screenType}',
            style: TextStyle(color: cs.error),
          ),
        );
    }
  }
}

class _ImageRevealWordWidget extends StatefulWidget {
  const _ImageRevealWordWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imgUrl,
    required this.correctWord,
    required this.nextLabel,
    required this.helpLabel,
    required this.payload,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.buildImage,
    required this.onCorrectAnswer,
  });

  final String title;
  final String subtitle;
  final String imgUrl;
  final String correctWord;
  final String nextLabel;
  final String helpLabel;
  final Map<String, dynamic> payload;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit})
  buildImage;
  final VoidCallback onCorrectAnswer;

  @override
  State<_ImageRevealWordWidget> createState() => _ImageRevealWordWidgetState();
}

class _ImageRevealWordWidgetState extends State<_ImageRevealWordWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _revealed = false;
  bool _hasCalledCorrectAnswer = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _revealed = (widget.payload['revealed'] as bool?) ?? false;

    // Listen to text changes to detect when user types correct answer
    _controller.addListener(_onTextChanged);

    // Auto-focus the text field when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onTextChanged() {
    if (_isCorrect && !_hasCalledCorrectAnswer) {
      _hasCalledCorrectAnswer = true;
      GetIt.I<FeedbackService>().correctAnswer();
      widget.onCorrectAnswer();
    } else if (!_isCorrect && _hasCalledCorrectAnswer) {
      _hasCalledCorrectAnswer = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    final lower = s.trim().toLowerCase();
    return lower
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't');
  }

  bool get _isCorrect =>
      _normalize(_controller.text) == _normalize(widget.correctWord);
  bool get _hasError => !_isCorrect && _controller.text.trim().isNotEmpty;
  bool get _canProceed => _isCorrect || _revealed;

  Future<void> _handleNext() async {
    if (_canProceed) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Mai încearcă!');
    }
  }

  void _handleReveal() {
    GetIt.I<FeedbackService>().reveal();
    setState(() {
      _revealed = true;
      widget.payload['revealed'] = true;
      _controller.text = widget.correctWord;
      _focusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    if (widget.imgUrl.isNotEmpty) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final orientation = MediaQuery.of(
                            context,
                          ).orientation;
                          // Responsive image size based on orientation
                          final imageSize = orientation == Orientation.landscape
                              ? 180.0 // Smaller in landscape
                              : 260.0; // Normal in portrait

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: widget.buildImage(
                                widget.imgUrl,
                                width: imageSize,
                                height: imageSize,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) =>
                          setState(() {}), // Rebuild for feedback icons
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleNext(),
                      decoration: InputDecoration(
                        labelText: 'Scrie cuvântul',
                        labelStyle: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F5F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFEA2233),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        suffixIcon: _isCorrect
                            ? const Icon(
                                Icons.check_circle,
                                size: 24,
                                color: Colors.green,
                              )
                            : (_hasError
                                  ? const Icon(
                                      Icons.cancel,
                                      size: 24,
                                      color: Colors.red,
                                    )
                                  : null),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF17406B),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _revealed
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2D72D2,
                                    ).withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: TextButton(
                          onPressed: _revealed ? null : _handleReveal,
                          style: TextButton.styleFrom(
                            backgroundColor: _revealed
                                ? Colors.grey[200]
                                : const Color(0xFF2D72D2),
                            foregroundColor: _revealed
                                ? Colors.grey[600]
                                : Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(widget.helpLabel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _canProceed
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_canProceed && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_canProceed && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSelectionWidget extends StatefulWidget {
  const _ImageSelectionWidget({
    super.key,
    required this.question,
    required this.images,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.buildImage,
    required this.onCorrectAnswer,
  });

  final String question;
  final List<Map<String, dynamic>> images;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit})
  buildImage;
  final VoidCallback onCorrectAnswer;

  @override
  State<_ImageSelectionWidget> createState() => _ImageSelectionWidgetState();
}

class _ImageSelectionWidgetState extends State<_ImageSelectionWidget>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _shuffledImages;
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _showError = false;
  late AnimationController _errorAnimationController;
  late Animation<double> _errorOpacity;
  bool _hasSelectedCorrectAnswer = false;

  @override
  void initState() {
    super.initState();
    // Shuffle images on init
    _shuffledImages = List.from(widget.images)..shuffle();

    // Initialize animation controller for error message fade
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _errorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorAnimationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    super.dispose();
  }

  void _handleImageTap(int index) {
    // Prevent selection if correct answer was already selected
    if (_hasSelectedCorrectAnswer) {
      return;
    }

    final image = _shuffledImages[index];
    final correct = image['correct'] == true;

    // Play selection feedback
    final feedback = GetIt.I<FeedbackService>();
    feedback.imageSelect();

    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      // Correct answer - user can proceed and timer completes
      feedback.correctAnswer();
      _hasSelectedCorrectAnswer = true;
      widget.onCorrectAnswer();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    } else {
      feedback.wrongAnswer();
      // Show error message with fade animation
      _errorAnimationController.forward().then((_) {
        // Auto-hide error after 2 seconds with fade out
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _showError) {
            _errorAnimationController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showError = false;
                  _selectedIndex = null; // Clear selection to allow retry
                });
              }
            });
          }
        });
      });
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(
        context,
        'Selectează imaginea corectă pentru a continua!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.question,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(height: 20),
                          // Display images in a grid layout
                          Flexible(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: List.generate(_shuffledImages.length, (
                                index,
                              ) {
                                final image = _shuffledImages[index];
                                final s3Key =
                                    image['s3Key']?.toString() ??
                                    image['uri']?.toString() ??
                                    '';
                                final isSelected = _selectedIndex == index;
                                final showCorrect = isSelected && _isCorrect;
                                final showWrong = isSelected && !_isCorrect;

                                // Calculate square size based on available space, considering orientation
                                final availableWidth =
                                    constraints.maxWidth -
                                    48; // container padding
                                final availableHeight =
                                    constraints.maxHeight -
                                    150; // space for question and padding
                                final orientation = MediaQuery.of(
                                  context,
                                ).orientation;

                                // Determine optimal size based on orientation and available space
                                double imageSize;
                                if (orientation == Orientation.landscape) {
                                  // In landscape: make images smaller to fit better, use height constraint
                                  final maxByHeight =
                                      (availableHeight - 24) / 2; // 2 rows max
                                  final maxByWidth =
                                      (availableWidth - 12) / 3; // 3 columns
                                  imageSize =
                                      (maxByHeight < maxByWidth
                                              ? maxByHeight
                                              : maxByWidth)
                                          .clamp(80.0, 140.0);
                                } else {
                                  // In portrait: use width-based calculation
                                  imageSize = ((availableWidth - 24) / 2).clamp(
                                    100.0,
                                    160.0,
                                  ); // 2 columns
                                }

                                return GestureDetector(
                                  onTap: _hasSelectedCorrectAnswer
                                      ? null
                                      : () => _handleImageTap(index),
                                  child: Opacity(
                                    opacity:
                                        _hasSelectedCorrectAnswer && !isSelected
                                        ? 0.4
                                        : 1.0,
                                    child: Container(
                                      width: imageSize,
                                      height: imageSize,
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: showCorrect
                                              ? Colors.green
                                              : showWrong
                                              ? Colors.red
                                              : isSelected
                                              ? const Color(0xFFEA2233)
                                              : Colors.grey[300]!,
                                          width: showCorrect || showWrong
                                              ? 3
                                              : 2,
                                        ),
                                        boxShadow: [
                                          if (isSelected)
                                            BoxShadow(
                                              color:
                                                  (showCorrect
                                                          ? Colors.green
                                                          : showWrong
                                                          ? Colors.red
                                                          : const Color(
                                                              0xFFEA2233,
                                                            ))
                                                      .withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            widget.buildImage(
                                              s3Key,
                                              width: imageSize,
                                              height: imageSize,
                                              fit: BoxFit.contain,
                                            ),
                                            if (showCorrect)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            if (showWrong)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      // Error message overlay - positioned at bottom
                      if (_showError)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: FadeTransition(
                            opacity: _errorOpacity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Încercă din nou!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_isCorrect && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindSoundWidget extends StatefulWidget {
  const _FindSoundWidget({
    super.key,
    required this.question,
    required this.word,
    required this.wordAudioKey,
    required this.syllables,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.playAudio,
    required this.onCorrectAnswer,
  });

  final String question;
  final String word;
  final String wordAudioKey;
  final List<Map<String, dynamic>> syllables;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Future<void> Function(String, {bool waitForCompletion}) playAudio;
  final VoidCallback onCorrectAnswer;

  @override
  State<_FindSoundWidget> createState() => _FindSoundWidgetState();
}

class _FindSoundWidgetState extends State<_FindSoundWidget>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  bool _isCorrect = false;
  final Set<int> _wrongAnswers = {}; // Track wrong answers for fade out
  int? _playingIndex; // Track which syllable is currently playing
  int? _flashingWrongIndex; // Track which syllable is flashing red temporarily
  bool _showErrorMessage = false; // Show error message overlay
  late AnimationController _errorAnimationController;
  late Animation<double> _errorOpacity;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for error message fade
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _errorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorAnimationController, curve: Curves.easeIn),
    );

    // Auto-play sequence when entering the question
    _autoPlaySequence();
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    super.dispose();
  }

  Future<void> _autoPlaySequence() async {
    // Wait 0.5 seconds before starting
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Play the whole word first (wait for completion)
    if (widget.wordAudioKey.isNotEmpty) {
      setState(() => _playingIndex = -1); // -1 means all playing
      await widget.playAudio(widget.wordAudioKey, waitForCompletion: true);
      if (!mounted) return;
      // Wait 0.2s after word audio finishes
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _playingIndex = null);
    }

    // Then play each syllable - wait 0.2s after each one finishes
    for (int i = 0; i < widget.syllables.length; i++) {
      if (!mounted) return;
      final audioKey =
          widget.syllables[i]['s3AudioKey']?.toString() ??
          widget.syllables[i]['audioUri']?.toString() ??
          '';
      if (audioKey.isNotEmpty) {
        setState(() => _playingIndex = i);
        await widget.playAudio(audioKey, waitForCompletion: true);
        if (!mounted) return;
        // Wait 0.2s after this syllable's audio finishes
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    if (mounted) setState(() => _playingIndex = null);
  }

  void _handleSyllableTap(int index) {
    final syllable = widget.syllables[index];
    final correct = syllable['correct'] == true;
    final feedback = GetIt.I<FeedbackService>();

    // If this syllable was already marked wrong, show error feedback
    if (_wrongAnswers.contains(index)) {
      feedback.wrongAnswer();
      _showWrongAnswerFeedback(index);
      return;
    }

    // If correct answer already found
    if (_isCorrect) {
      // Only allow tapping wrong syllables to show error
      if (!correct) {
        feedback.wrongAnswer();
        _showWrongAnswerFeedback(index);
      }
      return;
    }

    // Play selection feedback
    feedback.selection();

    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      if (!correct) {
        _wrongAnswers.add(index);
        // Show error feedback immediately for new wrong answers
        _flashingWrongIndex = index;
        _showErrorMessage = true;
      }
    });

    if (correct) {
      feedback.correctAnswer();
      widget.onCorrectAnswer();
    } else {
      feedback.wrongAnswer();
      // Animate the error for new wrong answers
      _errorAnimationController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && _showErrorMessage && _flashingWrongIndex == index) {
            _errorAnimationController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showErrorMessage = false;
                  _flashingWrongIndex = null;
                });
              }
            });
          }
        });
      });
    }
  }

  void _showWrongAnswerFeedback(int index) {
    // Reset animation if already running
    if (_errorAnimationController.isAnimating) {
      _errorAnimationController.reset();
    }

    setState(() {
      _flashingWrongIndex = index;
      _showErrorMessage = true;
    });

    // Show error message with fade animation
    _errorAnimationController.forward().then((_) {
      // Auto-hide error after 1.2 seconds with fade out
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _showErrorMessage && _flashingWrongIndex == index) {
          _errorAnimationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showErrorMessage = false;
                _flashingWrongIndex = null;
              });
            }
          });
        }
      });
    });
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(
        context,
        'Selectează silaba corectă pentru a continua!',
      );
    }
  }

  Future<void> _playSyllable(int index) async {
    final audioKey =
        widget.syllables[index]['s3AudioKey']?.toString() ??
        widget.syllables[index]['audioUri']?.toString() ??
        '';
    if (audioKey.isNotEmpty) {
      setState(() => _playingIndex = index);
      await widget.playAudio(audioKey, waitForCompletion: true);
      // Keep highlight briefly after audio finishes
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _playingIndex = null);
    }
  }

  Future<void> _playWord() async {
    // Only play the whole word
    if (widget.wordAudioKey.isNotEmpty) {
      setState(() => _playingIndex = -1); // -1 means all playing
      await widget.playAudio(widget.wordAudioKey, waitForCompletion: true);
      // Keep highlight briefly after audio finishes
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _playingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          widget.question,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.word.isNotEmpty) ...[
                          // Syllables display as split word with play buttons underneath
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16,
                            ),
                            child: Column(
                              children: [
                                // Single row with syllable columns and dashes between
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < widget.syllables.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        // Dash column - same height structure as syllable
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ' - ',
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[400],
                                                height: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const SizedBox(
                                              height: 36,
                                            ), // Same height as play button
                                          ],
                                        ),
                                      // Each syllable in a column: text + button centered
                                      Builder(
                                        builder: (context) {
                                          final isWrong = _wrongAnswers
                                              .contains(i);
                                          final isCorrectAnswer =
                                              _selectedIndex == i && _isCorrect;
                                          final isPlaying =
                                              _playingIndex == i ||
                                              _playingIndex == -1;
                                          final isFlashingWrong =
                                              _flashingWrongIndex == i;
                                          final syllable = widget.syllables[i];
                                          final isWrongSyllable =
                                              syllable['correct'] != true;

                                          return AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            opacity: isWrong && !isFlashingWrong
                                                ? 0.35
                                                : 1.0,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Syllable text
                                                GestureDetector(
                                                  onTap: () =>
                                                      _handleSyllableTap(i),
                                                  child: AnimatedDefaultTextStyle(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1,
                                                      height: 1.0,
                                                      color: isFlashingWrong
                                                          ? Colors.red[600]
                                                          : isCorrectAnswer
                                                          ? Colors.green[600]
                                                          : isWrong
                                                          ? Colors.grey[400]
                                                          : isPlaying
                                                          ? const Color(
                                                              0xFF2D72D2,
                                                            )
                                                          : (_isCorrect &&
                                                                isWrongSyllable)
                                                          ? const Color(
                                                              0xFF1A1A2E,
                                                            ) // Allow tapping after correct
                                                          : const Color(
                                                              0xFF1A1A2E,
                                                            ),
                                                    ),
                                                    child: Text(
                                                      (widget.syllables[i]['text']
                                                                  ?.toString() ??
                                                              '')
                                                          .toUpperCase(),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Play button centered under text
                                                GestureDetector(
                                                  onTap:
                                                      (isWrong &&
                                                          !isFlashingWrong)
                                                      ? null
                                                      : () => _playSyllable(i),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isFlashingWrong
                                                          ? Colors.red[400]
                                                          : (isWrong &&
                                                                !isFlashingWrong)
                                                          ? Colors.grey[300]
                                                          : isPlaying
                                                          ? const Color(
                                                              0xFF2D72D2,
                                                            )
                                                          : const Color(
                                                              0xFF2D72D2,
                                                            ).withOpacity(0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      isFlashingWrong
                                                          ? Icons.close
                                                          : Icons.volume_up,
                                                      color: isFlashingWrong
                                                          ? Colors.white
                                                          : (isWrong &&
                                                                !isFlashingWrong)
                                                          ? Colors.grey[500]
                                                          : isPlaying
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF2D72D2,
                                                            ),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Play word button
                                GestureDetector(
                                  onTap: () => _playWord(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D72D2),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF2D72D2,
                                          ).withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.play_circle_filled,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Ascultă cuvântul',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                  // Error message overlay - positioned at bottom
                  if (_showErrorMessage)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: FadeTransition(
                        opacity: _errorOpacity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Încercă din nou!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_isCorrect && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindMissingLetterWidget extends StatefulWidget {
  const _FindMissingLetterWidget({
    super.key,
    required this.question,
    required this.maskedWord,
    required this.correctLetter,
    required this.imageKey,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.buildImage,
    required this.onCorrectAnswer,
  });

  final String question;
  final String maskedWord;
  final String correctLetter;
  final String imageKey;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit})
  buildImage;
  final VoidCallback onCorrectAnswer;

  @override
  State<_FindMissingLetterWidget> createState() =>
      _FindMissingLetterWidgetState();
}

class _FindMissingLetterWidgetState extends State<_FindMissingLetterWidget> {
  late List<String> _letterOptions; // 5 letters to choose from
  final Set<int> _disabledIndices = {}; // Wrong letters become disabled (grey)
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _showError = false;

  // Romanian alphabet for generating distractor letters
  static const _alphabet = 'AĂÂBCDEFGHIÎJKLMNOPQRSȘTȚUVWXYZ';

  @override
  void initState() {
    super.initState();
    _generateLetterOptions();
  }

  void _generateLetterOptions() {
    final correctLetter = widget.correctLetter.toUpperCase();
    final distractors = <String>[];

    // Generate 4 unique distractor letters
    final availableLetters =
        _alphabet.split('').where((l) => l != correctLetter).toList()
          ..shuffle();
    for (var i = 0; i < 4 && i < availableLetters.length; i++) {
      distractors.add(availableLetters[i]);
    }

    // Combine correct letter + distractors and shuffle
    _letterOptions = [correctLetter, ...distractors]..shuffle();
  }

  /// Returns the word with the selected letter filled in (replaces _ or __ with the letter)
  String _getDisplayWord() {
    if (_selectedIndex == null) {
      return widget.maskedWord.toUpperCase();
    }
    final selectedLetter = _letterOptions[_selectedIndex!];
    // Replace underscore(s) with the selected letter
    return widget.maskedWord.toUpperCase().replaceAll(
      RegExp(r'_+'),
      selectedLetter,
    );
  }

  void _handleLetterTap(int index) {
    if (_disabledIndices.contains(index) || _isCorrect) return;

    final selectedLetter = _letterOptions[index];
    // Compare case-insensitive but keep diacritics distinct (Ș ≠ S, Ț ≠ T, etc.)
    final correct =
        selectedLetter.toLowerCase() == widget.correctLetter.toLowerCase();

    // Play feedback based on correctness
    final feedback = GetIt.I<FeedbackService>();
    feedback.letterSelect();

    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      feedback.correctAnswer();
      widget.onCorrectAnswer();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    } else {
      feedback.wrongAnswer();
      // Mark this letter as disabled and hide error after delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _disabledIndices.add(index);
            _showError = false;
            _selectedIndex = null;
          });
        }
      });
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(
        context,
        'Selectează litera corectă pentru a continua!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate available space for image to fit everything on one screen
                final orientation = MediaQuery.of(context).orientation;
                final availableWidth = constraints.maxWidth - 40; // padding
                final availableHeight =
                    constraints.maxHeight - 250; // space for text and buttons

                // Determine optimal image size based on orientation
                double imageSize;
                if (orientation == Orientation.landscape) {
                  // In landscape: use smaller size to fit everything
                  imageSize = (availableHeight * 0.6).clamp(120.0, 220.0);
                } else {
                  // In portrait: more space available
                  imageSize = (availableWidth * 0.65).clamp(200.0, 340.0);
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.imageKey.isNotEmpty) ...[
                        Flexible(
                          flex: 2,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: imageSize,
                              maxHeight: imageSize,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cs.outline.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: widget.buildImage(
                                widget.imageKey,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        widget.question,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getDisplayWord(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: _isCorrect
                                  ? Colors.green
                                  : _showError
                                  ? Colors.red
                                  : const Color(0xFF2D72D2),
                              letterSpacing: 6,
                            ),
                      ),
                      const SizedBox(height: 20),
                      // Letter options - 5 buttons to choose from
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: List.generate(_letterOptions.length, (index) {
                          final letter = _letterOptions[index];
                          final isDisabled = _disabledIndices.contains(index);
                          final isSelected = _selectedIndex == index;
                          final showCorrect = isSelected && _isCorrect;
                          final showWrong = isSelected && _showError;
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;

                          return GestureDetector(
                            onTap: (isDisabled || _isCorrect)
                                ? null
                                : () => _handleLetterTap(index),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isDisabled
                                    ? (isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[300])
                                    : showCorrect
                                    ? Colors.green
                                    : showWrong
                                    ? Colors.red
                                    : (isDark
                                          ? const Color(0xFF2D72D2)
                                          : const Color(
                                              0xFF2D72D2,
                                            ).withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDisabled
                                      ? (isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[400]!)
                                      : showCorrect
                                      ? Colors.green
                                      : showWrong
                                      ? Colors.red
                                      : const Color(0xFF2D72D2),
                                  width: 2,
                                ),
                                boxShadow: (isDisabled || showWrong)
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: showCorrect
                                              ? Colors.green.withOpacity(0.3)
                                              : const Color(
                                                  0xFF2D72D2,
                                                ).withOpacity(
                                                  isDark ? 0.3 : 0.1,
                                                ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: isDisabled
                                        ? (isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[500])
                                        : (showCorrect || showWrong || isDark)
                                        ? Colors.white
                                        : const Color(0xFF17406B),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_showError) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Încercă din nou!',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_isCorrect) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check,
                                color: Colors.green[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Corect!',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_isCorrect && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindNonIntruderWidget extends StatefulWidget {
  const _FindNonIntruderWidget({
    super.key,
    required this.question,
    required this.images,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.buildImage,
    required this.onCorrectAnswer,
  });

  final String question;
  final List<Map<String, dynamic>> images;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit})
  buildImage;
  final VoidCallback onCorrectAnswer;

  @override
  State<_FindNonIntruderWidget> createState() => _FindNonIntruderWidgetState();
}

class _FindNonIntruderWidgetState extends State<_FindNonIntruderWidget> {
  late List<Map<String, dynamic>> _shuffledImages;
  final Set<int> _selectedIndices = {};
  bool _isCorrect = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _shuffledImages = List.from(widget.images)..shuffle();
  }

  void _handleImageTap(int index) {
    final feedback = GetIt.I<FeedbackService>();
    feedback.imageSelect();

    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        _isCorrect = false;
        _showError = false;
      } else {
        if (_selectedIndices.length < 2) {
          _selectedIndices.add(index);
        }
      }
    });

    // Check if both selected images are correct
    if (_selectedIndices.length == 2) {
      final allCorrect = _selectedIndices.every((idx) {
        final image = _shuffledImages[idx];
        return image['isMatch'] == true;
      });

      setState(() {
        _isCorrect = allCorrect;
        _showError = !allCorrect;
      });

      if (allCorrect) {
        feedback.correctAnswer();
        widget.onCorrectAnswer();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _showError = false);
          }
        });
      } else {
        feedback.wrongAnswer();
      }
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(
        context,
        'Selectează cele două imagini corecte pentru a continua!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.question,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Selectează 2 imagini',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_showError) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Încercă din nou!',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Display images in a grid layout
                      Flexible(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: List.generate(_shuffledImages.length, (
                            index,
                          ) {
                            final image = _shuffledImages[index];
                            final s3Key =
                                image['s3Key']?.toString() ??
                                image['uri']?.toString() ??
                                '';
                            final isSelected = _selectedIndices.contains(index);
                            final showCorrect =
                                isSelected &&
                                _isCorrect &&
                                _selectedIndices.length == 2;
                            final showWrong =
                                isSelected &&
                                _showError &&
                                _selectedIndices.length == 2;

                            // Calculate square size based on available space, considering orientation
                            final availableWidth =
                                constraints.maxWidth - 48; // container padding
                            final availableHeight =
                                constraints.maxHeight -
                                200; // space for question, text, and padding
                            final orientation = MediaQuery.of(
                              context,
                            ).orientation;

                            // Determine optimal size based on orientation and available space
                            double imageSize;
                            if (orientation == Orientation.landscape) {
                              // In landscape: make images smaller to fit better
                              final maxByHeight =
                                  (availableHeight - 24) / 2; // 2 rows max
                              final maxByWidth =
                                  (availableWidth - 12) / 3; // 3 columns
                              imageSize =
                                  (maxByHeight < maxByWidth
                                          ? maxByHeight
                                          : maxByWidth)
                                      .clamp(80.0, 140.0);
                            } else {
                              // In portrait: use width-based calculation
                              imageSize = ((availableWidth - 12) / 2).clamp(
                                120.0,
                                200.0,
                              ); // 2 columns
                            }

                            return GestureDetector(
                              onTap: () => _handleImageTap(index),
                              child: Container(
                                width: imageSize,
                                height: imageSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: showCorrect
                                        ? Colors.green
                                        : showWrong
                                        ? Colors.red
                                        : isSelected
                                        ? const Color(0xFFEA2233)
                                        : Colors.grey[300]!,
                                    width: showCorrect || showWrong ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color:
                                            (showCorrect
                                                    ? Colors.green
                                                    : showWrong
                                                    ? Colors.red
                                                    : const Color(0xFFEA2233))
                                                .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      widget.buildImage(
                                        s3Key,
                                        width: imageSize,
                                        height: imageSize,
                                        fit: BoxFit.contain,
                                      ),
                                      if (showCorrect)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      if (showWrong)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      if (isSelected &&
                                          !showCorrect &&
                                          !showWrong)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEA2233),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${_selectedIndices.toList().indexOf(index) + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_isCorrect && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatWordWidget extends StatefulWidget {
  const _FormatWordWidget({
    super.key,
    required this.audioQuestionKey,
    required this.imageKey,
    required this.question,
    required this.correctWord,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.playAudio,
    required this.buildImage,
    required this.onCorrectAnswer,
  });

  final String audioQuestionKey;
  final String imageKey;
  final String question;
  final String correctWord;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Future<void> Function(String) playAudio;
  final Widget Function(String, {double? width, double? height, BoxFit fit})
  buildImage;
  final VoidCallback onCorrectAnswer;

  /// Returns true if this is image mode (has image key but no audio)
  bool get isImageMode => imageKey.isNotEmpty && audioQuestionKey.isEmpty;

  @override
  State<_FormatWordWidget> createState() => _FormatWordWidgetState();
}

class _FormatWordWidgetState extends State<_FormatWordWidget> {
  late List<String>
  _allLetters; // All letters (shuffled), never modified after init
  final List<int> _selectedIndices = []; // Indices of selected letters in order
  late Set<int> _usedIndices; // Track which indices are used
  bool _isCorrect = false;
  bool _showError = false;
  bool _hasPlayedAudio = false;

  @override
  void initState() {
    super.initState();
    _allLetters = widget.correctWord.split('')..shuffle();
    _usedIndices = {};

    // Audio mode: play audio on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isImageMode &&
          !_hasPlayedAudio &&
          widget.audioQuestionKey.isNotEmpty) {
        _hasPlayedAudio = true;
        widget.playAudio(widget.audioQuestionKey);
      }
    });
  }

  void _handleLetterTap(int index) {
    if (_usedIndices.contains(index))
      return; // Already used, don't allow re-use

    // Play letter selection feedback
    GetIt.I<FeedbackService>().letterSelect();

    setState(() {
      _selectedIndices.add(index);
      _usedIndices.add(index);
      _showError = false;
    });

    // Check if word is complete (all letters used)
    if (_usedIndices.length == _allLetters.length) {
      _checkAnswer();
    }
  }

  void _handleSelectedTap(int tapIndex) {
    // Play light feedback for removing letters
    GetIt.I<FeedbackService>().lightTap();

    // Remove this letter and all letters after it from selection
    setState(() {
      // Get indices to remove (from tapIndex to end)
      final indicesToRemove = _selectedIndices.sublist(tapIndex);
      for (final idx in indicesToRemove) {
        _usedIndices.remove(idx);
      }
      _selectedIndices.removeRange(tapIndex, _selectedIndices.length);
      _isCorrect = false;
      _showError = false;
    });
  }

  void _checkAnswer() {
    final formedWord = _selectedIndices.map((i) => _allLetters[i]).join('');
    final correct =
        formedWord.toLowerCase() == widget.correctWord.toLowerCase();
    final feedback = GetIt.I<FeedbackService>();

    setState(() {
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      feedback.correctAnswer();
      widget.onCorrectAnswer();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    } else {
      feedback.wrongAnswer();
      // Auto-reset after 800ms so user doesn't have to press reset button
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _showError) {
          _reset();
        }
      });
    }
  }

  void _reset() {
    setState(() {
      _allLetters = widget.correctWord.split('')..shuffle();
      _selectedIndices.clear();
      _usedIndices.clear();
      _isCorrect = false;
      _showError = false;
    });
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(
        context,
        'Formează cuvântul corect pentru a continua!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Calculate letter box size based on word length to fit all on screen
    final letterCount = _allLetters.length;
    final letterBoxSize = letterCount > 8
        ? 50.0
        : (letterCount > 6 ? 60.0 : 70.0);
    final letterFontSize = letterCount > 8
        ? 24.0
        : (letterCount > 6 ? 28.0 : 32.0);
    final selectedFontSize = letterCount > 8
        ? 20.0
        : (letterCount > 6 ? 24.0 : 28.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Image mode: show question text + image
                  if (widget.isImageMode) ...[
                    Text(
                      widget.question.isNotEmpty
                          ? widget.question
                          : 'Formează cuvântul din imagine',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Image display - use Expanded to take available space
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.buildImage(
                            widget.imageKey,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Audio mode: show text + play button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Ascultă și formează cuvântul',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () =>
                              widget.playAudio(widget.audioQuestionKey),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2D72D2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volume_up,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 1),
                  ],
                  const SizedBox(height: 12),
                  // Selected letters area
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? Colors.green.withOpacity(0.1)
                          : _showError
                          ? Colors.red.withOpacity(0.1)
                          : Theme.of(context).inputDecorationTheme.fillColor ??
                                const Color(0xFFF2F3F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isCorrect
                            ? Colors.green
                            : _showError
                            ? Colors.red
                            : cs.outline.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: _selectedIndices.isEmpty
                        ? Center(
                            child: Text(
                              'Selectează literele...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: cs.onSurface.withOpacity(0.4),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: List.generate(_selectedIndices.length, (
                              index,
                            ) {
                              final letterIndex = _selectedIndices[index];
                              return GestureDetector(
                                onTap: () => _handleSelectedTap(index),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _isCorrect
                                        ? Colors.green
                                        : _showError
                                        ? Colors.red
                                        : const Color(0xFFEA2233),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _allLetters[letterIndex].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: selectedFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                  ),
                  // Show error message when wrong, or reset button when user has selected letters
                  if (_showError) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, color: Colors.red[700], size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Încearcă din nou!',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedIndices.isNotEmpty && !_isCorrect) ...[
                    // Reset button - visible when user has selected letters but not got it right yet
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _reset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).inputDecorationTheme.fillColor ??
                              const Color(0xFFF2F3F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              color: cs.onSurface.withOpacity(0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Resetează',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Available letters in grid boxes - all letters always visible
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(_allLetters.length, (index) {
                      final isUsed = _usedIndices.contains(index);
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return GestureDetector(
                        onTap: isUsed ? null : () => _handleLetterTap(index),
                        child: Container(
                          width: letterBoxSize,
                          height: letterBoxSize,
                          decoration: BoxDecoration(
                            color: isUsed
                                ? (isDark ? Colors.grey[800] : Colors.grey[300])
                                : (isDark
                                      ? const Color(0xFF2D72D2)
                                      : const Color(
                                          0xFF2D72D2,
                                        ).withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUsed
                                  ? (isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[400]!)
                                  : const Color(0xFF2D72D2),
                              width: 2,
                            ),
                            boxShadow: isUsed
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2D72D2,
                                      ).withOpacity(isDark ? 0.3 : 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              _allLetters[index].toUpperCase(),
                              style: TextStyle(
                                fontSize: letterFontSize,
                                fontWeight: FontWeight.w700,
                                color: isUsed
                                    ? (isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[500])
                                    : (isDark
                                          ? Colors.white
                                          : const Color(0xFF17406B)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (!widget.isImageMode) const Spacer(flex: 1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isCorrect
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: (_isCorrect && widget.canFinishLesson)
                  ? _handleNext
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson)
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reîncearcă')),
        ],
      ),
    );
  }
}

class _InstructionsWidget extends StatefulWidget {
  const _InstructionsWidget({
    super.key,
    required this.title,
    required this.text,
    required this.instructions,
    required this.nextLabel,
    required this.onFinish,
    required this.onCompleteTimer,
    required this.canFinishLesson,
  });

  final String title;
  final String text;
  final List instructions;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final VoidCallback onCompleteTimer;
  final bool canFinishLesson;

  @override
  State<_InstructionsWidget> createState() => _InstructionsWidgetState();
}

class _InstructionsWidgetState extends State<_InstructionsWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Check immediately if content is already fully visible (no scrolling needed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfContentFitsScreen();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfContentFitsScreen() {
    if (!mounted) return;

    // If content fits on screen without scrolling, complete timer immediately
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0 && !_hasScrolledToBottom) {
        // Content fits on screen, no scrolling needed
        debugPrint('📜 Instructions content fits on screen, completing timer');
        _hasScrolledToBottom = true;
        widget.onCompleteTimer();
      }
    }
  }

  void _onScroll() {
    if (_hasScrolledToBottom || !mounted) return;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final threshold = maxScroll * 0.9; // 90% scrolled

      if (currentScroll >= threshold) {
        debugPrint(
          '📜 User scrolled to bottom of instructions, completing timer',
        );
        setState(() {
          _hasScrolledToBottom = true;
        });
        widget.onCompleteTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title.isNotEmpty) ...[
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (widget.text.isNotEmpty) ...[
                      Text(
                        widget.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          height: 1.6,
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.instructions.isNotEmpty) ...[
                      ...widget.instructions.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 6,
                                  right: 12,
                                ),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEA2233),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$e',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 16,
                                        height: 1.5,
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.canFinishLesson
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA2233).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FilledButton(
              onPressed: widget.canFinishLesson ? widget.onFinish : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.canFinishLesson
                    ? const Color(0xFFEA2233)
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.canFinishLesson) ...[
                    const Icon(Icons.hourglass_empty, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.nextLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Lecția nu are conținut.'));
}
