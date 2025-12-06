// lib/features/content/presentation/lesson_player_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/audio_cache_service.dart';
import '../../../core/services/s3_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/enums.dart';

class LessonPlayerPage extends StatefulWidget {
  const LessonPlayerPage({
    super.key,
    required this.profileId,
    required this.lessonId,
    required this.title,
  });

  final int profileId;
  final int lessonId;
  final String title;

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

// ——— Cards comune ———
class _TitleCard extends StatelessWidget {
  const _TitleCard(this.title, {super.key});

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
  const _BodyCard({super.key, required this.child});

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

String _s(Map? m, String k, [String fb = '']) {
  final v = m?[k];
  return v is String ? v : fb;
}

List _l(Map? m, String k) {
  final v = m?[k];
  return v is List ? v : const [];
}

List<String> _sxList(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is List && v.isNotEmpty) return v.map((e) => '$e').toList();
  }
  return const [];
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  late final ContentRepository _repo = ContentRepository(GetIt.I<DioClient>());
  late final S3Service _s3 = GetIt.I<S3Service>();
  late final AudioCacheService _audioCache = GetIt.I<AudioCacheService>();
  final _player = AudioPlayer();

  LessonDto? _data;
  String? _error;
  bool _loading = true;
  
  // Timer for minimum screen duration (per screen, not per lesson)
  Timer? _screenTimer;
  int _elapsedSeconds = 0;
  int _minimumSeconds = 10; // Default, will be overridden by screen payload

  @override
  void initState() {
    super.initState();

    // 1) Set player mode FIRST for better compatibility
    _player.setPlayerMode(PlayerMode.lowLatency);
    
    // 2) Set release mode
    _player.setReleaseMode(ReleaseMode.release);
    
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
    _player.eventStream.listen((event) {
      if (event.eventType == AudioEventType.log) {
        debugPrint('🎵 Audio log: ${event.logMessage}');
      }
    }, onError: (error) {
      debugPrint('\x1B[31mAudioPlayers Exception: $error\x1B[0m');
    });

    _load();
  }

  void _startTimer({int? minSeconds}) {
    _elapsedSeconds = 0;
    _minimumSeconds = minSeconds ?? 10; // Use provided minSeconds or default to 10
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
  Widget _buildImage(String uriOrKey, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
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
    return v is String ? v : fb;
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
        errorMessage = data['message'] as String? ??
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
            return e.message ?? 'Eroare la încărcarea lecției. Te rog încearcă din nou.';
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
      final d = await _repo.getLesson(widget.profileId, widget.lessonId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
      // Reset and restart timer when lesson loads with screen-specific duration
      if (_data!.screens.isNotEmpty) {
        final firstScreen = _data!.screens.first;
        final minSeconds = _getMinSecondsFromPayload(firstScreen.payload);
        _startTimer(minSeconds: minSeconds);
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

  Future<void> _playAudio(String uriOrKey) async {
    if (uriOrKey.isEmpty) return;
    
    try {
      // Stop any currently playing audio
      await _player.stop();
      
      // Check if it's an S3 key or full URL
      if (uriOrKey.startsWith('http://') || uriOrKey.startsWith('https://')) {
        // Full URL - download and cache, then play from bytes in memory
        debugPrint('🎵 Caching and playing audio from URL: $uriOrKey');
        final localPath = await _audioCache.getLocalPath(uriOrKey);
        
        if (localPath != null) {
          debugPrint('🎵 Loading cached audio into memory: $localPath');
          // Read file into memory and play from bytes
          final file = File(localPath);
          final bytes = await file.readAsBytes();
          debugPrint('🎵 Playing ${bytes.length} bytes from memory');
          await _player.play(BytesSource(bytes), volume: 1.0);
        } else {
          debugPrint('❌ Failed to cache audio, cannot play');
        }
      } else if (uriOrKey.startsWith('modules/') || !uriOrKey.startsWith('assets/')) {
        // S3 key - construct full URL, download and cache, then play from bytes in memory
        final url = _s3.getFullUrl(uriOrKey);
        debugPrint('🎵 Caching and playing audio from S3 key: $uriOrKey');
        final localPath = await _audioCache.getLocalPath(url);
        
        if (localPath != null) {
          debugPrint('🎵 Loading cached audio into memory: $localPath');
          // Read file into memory and play from bytes
          final file = File(localPath);
          final bytes = await file.readAsBytes();
          debugPrint('🎵 Playing ${bytes.length} bytes from memory');
          await _player.play(BytesSource(bytes), volume: 1.0);
        } else {
          debugPrint('❌ Failed to cache audio, cannot play');
        }
      } else {
        // Legacy assets/ path - convert to asset source
        final path = uriOrKey.startsWith('assets/') ? uriOrKey.substring(7) : uriOrKey;
        debugPrint('🎵 Playing audio from assets: $path');
        await _player.play(AssetSource(path), volume: 1.0);
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
      await _repo.getLesson(widget.profileId, lessonId);
      return true;
    } catch (e) {
      debugPrint('🎉 Lesson $lessonId does not exist: $e');
      return false;
    }
  }

  Future<void> _showCompletionDialog(bool endOfLesson, bool endOfSubmodule, bool endOfModule) async {
    debugPrint('🎉 _showCompletionDialog() called - endOfLesson: $endOfLesson, endOfSubmodule: $endOfSubmodule, endOfModule: $endOfModule');
    
    // Determine which image and message to show
    String imagePath;
    String message;
    
    if (endOfModule) {
      imagePath = 'assets/images/finish_module.png';
      message = 'Excelent! Ai terminat modulul!';
    } else if (endOfSubmodule) {
      imagePath = 'assets/images/finish_submodule copy.png';
      message = 'Felicitări! Ai terminat submodulul!';
    } else if (endOfLesson) {
      imagePath = 'assets/images/finish_lesson.png';
      message = 'Bravo! Ai terminat lecția!';
    } else {
      // Fallback - show lesson completion
      imagePath = 'assets/images/finish_lesson.png';
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
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
                  debugPrint('🎉 User tapped on dialog to continue immediately');
                  // Cancel the auto-close timer since user tapped
                  autoCloseTimer?.cancel();
                  Navigator.of(dialogContext).pop();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Completion image based on level - wrapped to ensure taps work
                      GestureDetector(
                        onTap: () {
                          debugPrint('🎉 User tapped on image to continue immediately');
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Image.asset(
                          imagePath,
                          width: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('🎉 Error loading $imagePath: $error');
                            return Container(
                              width: 220,
                              height: 220,
                              color: Colors.red.withOpacity(0.3),
                              child: const Center(
                                child: Text('Image Error', style: TextStyle(color: Colors.white)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          debugPrint('🎉 User tapped on message text to continue immediately');
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          debugPrint('🎉 User tapped on instruction text to continue immediately');
                          autoCloseTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          'Apasă oriunde pentru a continua',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
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
      final resp = await _repo.advance(
        widget.profileId,
        lessonId: widget.lessonId,
        screenIndex: 0,
        done: true,
      );
      if (!mounted) return;

      // Debug: Log the response to see what flags are set
      debugPrint('🎉 API Response: endOfLesson=${resp.endOfLesson}, endOfSubmodule=${resp.endOfSubmodule}, endOfModule=${resp.endOfModule}');
      debugPrint('🎉 Current lesson data: moduleId=${resp.moduleId}, submoduleId=${resp.submoduleId}, lessonId=${resp.lessonId}, screenIndex=${resp.screenIndex}');
      debugPrint('🎉 Next lesson data: nextModuleId=${resp.nextModuleId}, nextSubmoduleId=${resp.nextSubmoduleId}, nextLessonId=${resp.nextLessonId}');
      
      // arată GIF la final de lecție / submodul / modul (alege condiția dorită)
      final shouldCelebrate = resp.endOfLesson || resp.endOfSubmodule || resp.endOfModule;
      debugPrint('🎉 Should celebrate: $shouldCelebrate');
      
      // Show completion dialog unless skipped
      if (!skipCompletionDialog) {
        debugPrint('🎉 Showing completion dialog!');
        await _showCompletionDialog(resp.endOfLesson, resp.endOfSubmodule, resp.endOfModule);
      }

      // Navigate to next lesson if available, otherwise go back to submodule
      if (mounted) {
        // Determine the next lesson ID to navigate to
        // Priority 1: Use explicit nextLessonId from backend
        // Priority 2: If lessonId in response is different and we're not at an end, use that
        int? targetLessonId;
        
        if (resp.nextLessonId != null && resp.nextLessonId! > 0 && resp.nextLessonId! != widget.lessonId) {
          // Backend explicitly provided next lesson ID
          targetLessonId = resp.nextLessonId;
          debugPrint('🎉 Using explicit nextLessonId from backend: $targetLessonId');
        } else if (!resp.endOfSubmodule && 
                   !resp.endOfModule && 
                   resp.lessonId != widget.lessonId && 
                   resp.lessonId > widget.lessonId) {
          // Backend returned a different lessonId that's greater than current - likely the next lesson
          targetLessonId = resp.lessonId;
          debugPrint('🎉 Using updated lessonId from backend as next lesson: $targetLessonId');
        }
        
        debugPrint('🎉 Navigation check - targetLessonId: $targetLessonId, widget.lessonId: ${widget.lessonId}, resp.lessonId: ${resp.lessonId}, resp.nextLessonId: ${resp.nextLessonId}');
        debugPrint('🎉 End flags - endOfSubmodule: ${resp.endOfSubmodule}, endOfModule: ${resp.endOfModule}');
        
        if (targetLessonId != null) {
          final nextLessonId = targetLessonId!; // Non-null variable for clarity
          debugPrint('🎉 Attempting to navigate to next lesson: $nextLessonId');
          // Verify the lesson exists before navigating (to prevent 404 errors)
          try {
            final lessonExists = await _lessonExists(nextLessonId);
            if (!lessonExists) {
              debugPrint('🎉 Lesson $nextLessonId does not exist, going back to submodule');
              // Add a longer delay to ensure backend has processed the lesson completion
              // This ensures the current lesson is marked as DONE before we navigate back
              debugPrint('🎉 Waiting for backend to process lesson completion before navigating back...');
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
                  title: 'Lecția $nextLessonId', // You might want to get the actual title
                ),
              ),
            );
            debugPrint('🎉 Successfully navigated to next lesson: $nextLessonId');
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
          debugPrint('🎉 Next lesson ID: ${resp.nextLessonId}, Response lesson ID: ${resp.lessonId}, Widget lesson ID: ${widget.lessonId}');
          // No fallback navigation - just go back to submodule
          // Add a longer delay to ensure backend has processed the lesson completion
          // This is especially important for the last lesson in a submodule
          // The backend needs time to update the lesson status to DONE
          debugPrint('🎉 Waiting for backend to process lesson completion...');
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            // Always return true to signal that data changed and submodule should refresh
            debugPrint('🎉 Navigating back to submodule after lesson completion');
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
          debugPrint('🎉 Server error when advancing (status $statusCode) - treating as end of lessons');
          
          // Show completion dialog for finishing the lesson
          if (!skipCompletionDialog) {
            await _showCompletionDialog(true, false, false);
          }
          
          // Navigate back to submodule and signal refresh
          // Add a longer delay to ensure backend has processed the lesson completion
          // Even if we got a server error, we still want to give the backend time
          // to process the lesson completion before navigating back
          debugPrint('🎉 Server error occurred, but waiting for backend to process lesson completion...');
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
          Icon(
            Icons.hourglass_empty,
            size: 18,
            color: const Color(0xFFEA2233),
          ),
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
    return Scaffold(
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
          _buildTimerIndicator(),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                ),
              )
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _data == null || _data!.screens.isEmpty
                    ? const _EmptyView()
                    : _renderScreen(_data!.screens.first, cs),
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
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
          String _s(Map? m, String k, [String fb = '']) {
            final v = m?[k];
            return v is String ? v : fb;
          }

          List<String> _sxList(Map? p, List<String> keys) {
            final List<dynamic> raw = () {
              for (final k in keys) {
                final v = p?[k];
                if (v is List && v.isNotEmpty) return v;
              }
              return const <dynamic>[];
            }();

            return raw
                .map((e) {
                  if (e is String) return e;
                  if (e is Map && e['text'] is String)
                    return e['text'] as String;
                  return '';
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }

          final title = _s(p, 'title');
          final text = _s(p, 'text');
          final subtitle = _s(p, 'subtitle');
          final bullets = _sxList(p, [
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 12),
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
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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

          Future<void> _play(String uri) async {
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (imgUri.isNotEmpty) ...[
                            Container(
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
                                child: _buildImage(imgUri, width: 240, height: 240),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (word.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                                      icon: const Icon(Icons.volume_up, color: Colors.white),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                    color: const Color(0xFFEA2233).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFEA2233).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _playAudio(uri),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                            Icon(Icons.volume_up, size: 18, color: const Color(0xFFEA2233)),
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.separated(
                            itemCount: pairs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 20),
                            itemBuilder: (_, i) {
                              final it = (pairs[i] as Map).cast<String, dynamic>();
                              final masked = _s(
                                it,
                                'masked',
                                _s(it, 'word'),
                              ); // "__cap"
                              final solution = _s(
                                it,
                                'solution',
                                _s(it, 'answer'),
                              ); // "s"
                              final revealed = (it['revealed'] as bool?) ?? false;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                              : TextSpan(text: masked, style: wordStyle),
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
                                                  color: const Color(0xFFEA2233).withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: TextButton(
                                        onPressed: revealed
                                            ? null
                                            : () => setState(() => it['revealed'] = true),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(revealed ? 'Arătat' : 'Arată'),
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
          String _imgUrl(Map p) {
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

          InlineSpan _coloredMasked(
            String masked,
            String sol,
            TextStyle base,
            TextStyle hi,
          ) {
            // Ex: "__cap" + "s" -> "scap" cu primul 's' colorat
            final idx = masked.indexOf('_');
            if (idx < 0 || sol.isEmpty)
              return TextSpan(text: masked, style: base);
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
          final imgUrl = _imgUrl(p);

          // masca poate veni ca 'masked', 'word' sau chiar 'subtitle'
          final masked = _s(p, 'masked', _s(p, 'word', _s(p, 'subtitle')));
          // soluția poate fi 'solution' sau 'answer'
          final solution = _s(p, 'solution', _s(p, 'answer'));
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (imgUrl.isNotEmpty) ...[
                            Container(
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
                                child: _buildImage(imgUrl, width: 240, height: 240),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // mască mare centrată + buton "Arată"
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: StatefulBuilder(
                              builder: (ctx, setSB) {
                                final revealed = (p['revealed'] as bool?) ?? false;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: revealed
                                              ? _coloredMasked(
                                                  masked,
                                                  solution,
                                                  wordStyle,
                                                  hiStyle,
                                                )
                                              : TextSpan(text: masked, style: wordStyle),
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
                                                  color: const Color(0xFFEA2233).withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: TextButton(
                                        onPressed: revealed
                                            ? null
                                            : () => setSB(() => p['revealed'] = true),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(revealed ? 'Arătat' : 'Arată'),
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
          String _imgUrl(Map p) {
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
          final imgUrl = _imgUrl(p);

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
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 8) Image Selection - select correct image from 3 options
      case ScreenType.imageSelection:
        {
          final question = _s(p, 'question', 'Selectează imaginea corectă');
          final images = _asListOfMap(p['images']); // [{s3Key: string, correct: boolean}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _ImageSelectionWidget(
            key: ValueKey('imageSelection_${widget.lessonId}'),
            question: question,
            images: images,
            nextLabel: next,
            onFinish: _finishLesson,
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
          final syllables = _asListOfMap(p['syllables']); // [{text, s3AudioKey, correct}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FindSoundWidget(
            key: ValueKey('findSound_${widget.lessonId}'),
            question: question,
            word: word,
            syllables: syllables,
            nextLabel: next,
            onFinish: _finishLesson,
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
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 11) Find Non-Intruder - select 2 matching images from 3
      case ScreenType.findNonIntruder:
        {
          final question = _s(p, 'question', 'Selectează cele două imagini care se potrivesc');
          final images = _asListOfMap(p['images']); // [{s3Key, isMatch}]
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FindNonIntruderWidget(
            key: ValueKey('findNonIntruder_${widget.lessonId}'),
            question: question,
            images: images,
            nextLabel: next,
            onFinish: _finishLesson,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            buildImage: _buildImage,
          );
        }

      // 12) Format Word - order scrambled letters to form word
      case ScreenType.formatWord:
        {
          final audioQuestionKey = _s(p, 's3AudioQuestionKey', '');
          final correctWord = _s(p, 'correctWord', '');
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

          return _FormatWordWidget(
            key: ValueKey('formatWord_${widget.lessonId}'),
            audioQuestionKey: audioQuestionKey,
            correctWord: correctWord,
            nextLabel: next,
            onFinish: _finishLesson,
            onShowCompletionDialog: _showCompletionDialog,
            canFinishLesson: _canFinishLesson,
            playAudio: _playAudio,
          );
        }

      // 13) Instructions - scrollable text
      case ScreenType.instructions:
        {
          final title = _s(p, 'title', 'Instrucțiuni');
          final text = _s(p, 'text', '');
          final instructions = _l(p, 'instructions');
          final next = _s(_buttons(p), 'nextLabel', 'Următorul');

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty) ...[
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (text.isNotEmpty) ...[
                            Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                height: 1.6,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (instructions.isNotEmpty) ...[
                            ...instructions.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6, right: 12),
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
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      backgroundColor: _canFinishLesson ? const Color(0xFFEA2233) : Colors.grey[400],
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
                          const Icon(Icons.hourglass_empty, size: 20),
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
  final Widget Function(String, {double? width, double? height, BoxFit fit}) buildImage;

  @override
  State<_ImageRevealWordWidget> createState() => _ImageRevealWordWidgetState();
}

class _ImageRevealWordWidgetState extends State<_ImageRevealWordWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _revealed = (widget.payload['revealed'] as bool?) ?? false;
    
    // Auto-focus the text field when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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

  bool get _isCorrect => _normalize(_controller.text) == _normalize(widget.correctWord);
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    if (widget.imgUrl.isNotEmpty) ...[
                      Container(
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
                          child: widget.buildImage(widget.imgUrl, width: 260, height: 260),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}), // Rebuild for feedback icons
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        suffixIcon: _isCorrect
                            ? const Icon(Icons.check_circle, size: 24, color: Colors.green)
                            : (_hasError ? const Icon(Icons.cancel, size: 24, color: Colors.red) : null),
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
                                    color: const Color(0xFF2D72D2).withOpacity(0.2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              onPressed: (_canProceed && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_canProceed && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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
  });

  final String question;
  final List<Map<String, dynamic>> images;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit}) buildImage;

  @override
  State<_ImageSelectionWidget> createState() => _ImageSelectionWidgetState();
}

class _ImageSelectionWidgetState extends State<_ImageSelectionWidget> {
  late List<Map<String, dynamic>> _shuffledImages;
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    // Shuffle images on init
    _shuffledImages = List.from(widget.images)..shuffle();
  }

  void _handleImageTap(int index) {
    final image = _shuffledImages[index];
    final correct = image['correct'] == true;

    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      // Correct answer - user can proceed
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Selectează imaginea corectă pentru a continua!');
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
                      widget.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_showError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.red[700], size: 20),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(_shuffledImages.length, (index) {
                        final image = _shuffledImages[index];
                        final s3Key = image['s3Key']?.toString() ?? image['uri']?.toString() ?? '';
                        final isSelected = _selectedIndex == index;
                        final showCorrect = isSelected && _isCorrect;
                        final showWrong = isSelected && !_isCorrect;

                        // Calculate square size based on screen width
                        final screenWidth = MediaQuery.of(context).size.width;
                        final imageSize = (screenWidth - 88) / 2; // 88 = padding (16*2) + container padding (24*2) + spacing (12) + borders

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
                                    color: (showCorrect
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
                                  widget.buildImage(s3Key, width: imageSize, height: imageSize, fit: BoxFit.contain),
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
                                        child: const Icon(Icons.check, color: Colors.white, size: 24),
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
                                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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
              onPressed: (_isCorrect && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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
    required this.syllables,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.playAudio,
  });

  final String question;
  final String word;
  final List<Map<String, dynamic>> syllables;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Future<void> Function(String) playAudio;

  @override
  State<_FindSoundWidget> createState() => _FindSoundWidgetState();
}

class _FindSoundWidgetState extends State<_FindSoundWidget> {
  int? _selectedIndex;
  bool _isCorrect = false;
  bool _showError = false;

  void _handleSyllableTap(int index) {
    final syllable = widget.syllables[index];
    final correct = syllable['correct'] == true;

    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Selectează silaba corectă pentru a continua!');
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
                child: Column(
                  children: [
                    Text(
                      widget.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.word.isNotEmpty) ...[
                      Text(
                        widget.word,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D72D2),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_showError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.red[700], size: 20),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(widget.syllables.length, (index) {
                        final syllable = widget.syllables[index];
                        final text = syllable['text']?.toString() ?? '';
                        final audioKey = syllable['s3AudioKey']?.toString() ?? syllable['audioUri']?.toString() ?? '';
                        final isSelected = _selectedIndex == index;
                        final showCorrect = isSelected && _isCorrect;
                        final showWrong = isSelected && !_isCorrect;

                        return GestureDetector(
                          onTap: () => _handleSyllableTap(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: showCorrect
                                  ? Colors.green.withOpacity(0.1)
                                  : showWrong
                                      ? Colors.red.withOpacity(0.1)
                                      : const Color(0xFFEA2233).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: showCorrect
                                    ? Colors.green
                                    : showWrong
                                        ? Colors.red
                                        : const Color(0xFFEA2233).withOpacity(0.3),
                                width: showCorrect || showWrong ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: (showCorrect ? Colors.green : showWrong ? Colors.red : const Color(0xFFEA2233))
                                            .withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: showCorrect
                                          ? Colors.green[700]
                                          : showWrong
                                              ? Colors.red[700]
                                              : const Color(0xFF17406B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => widget.playAudio(audioKey),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D72D2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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
              onPressed: (_isCorrect && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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
  });

  final String question;
  final String maskedWord;
  final String correctLetter;
  final String imageKey;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit}) buildImage;

  @override
  State<_FindMissingLetterWidget> createState() => _FindMissingLetterWidgetState();
}

class _FindMissingLetterWidgetState extends State<_FindMissingLetterWidget> {
  final _controller = TextEditingController();
  bool _isCorrect = false;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    // Remove diacritics and convert to lowercase
    return text
        .toLowerCase()
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .trim();
  }

  void _checkAnswer() {
    final input = _controller.text;
    final correct = _normalize(input) == _normalize(widget.correctLetter);

    setState(() {
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Completează litera corectă pentru a continua!');
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
                child: Column(
                  children: [
                    if (widget.imageKey.isNotEmpty) ...[
                      Container(
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
                          child: widget.buildImage(widget.imageKey, width: 200, height: 200),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      widget.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.maskedWord,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D72D2),
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: TextField(
                        controller: _controller,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _isCorrect
                                  ? Colors.green
                                  : _showError
                                      ? Colors.red
                                      : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _isCorrect
                                  ? Colors.green
                                  : _showError
                                      ? Colors.red
                                      : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _isCorrect
                                  ? Colors.green
                                  : _showError
                                      ? Colors.red
                                      : const Color(0xFFEA2233),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _checkAnswer();
                          } else {
                            setState(() {
                              _isCorrect = false;
                              _showError = false;
                            });
                          }
                        },
                      ),
                    ),
                    if (_showError) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.red[700], size: 20),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: Colors.green[700], size: 20),
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
              onPressed: (_isCorrect && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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
  });

  final String question;
  final List<Map<String, dynamic>> images;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Widget Function(String, {double? width, double? height, BoxFit fit}) buildImage;

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
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _showError = false);
          }
        });
      }
    }
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Selectează cele două imagini corecte pentru a continua!');
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
                      widget.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selectează 2 imagini',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_showError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.red[700], size: 20),
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
                    ...List.generate(_shuffledImages.length, (index) {
                      final image = _shuffledImages[index];
                      final s3Key = image['s3Key']?.toString() ?? image['uri']?.toString() ?? '';
                      final isSelected = _selectedIndices.contains(index);
                      final showCorrect = isSelected && _isCorrect && _selectedIndices.length == 2;
                      final showWrong = isSelected && _showError && _selectedIndices.length == 2;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => _handleImageTap(index),
                          child: Container(
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
                                    color: (showCorrect
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
                                children: [
                                  widget.buildImage(s3Key, width: double.infinity, height: 180, fit: BoxFit.cover),
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
                                        child: const Icon(Icons.check, color: Colors.white, size: 24),
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
                                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  if (isSelected && !showCorrect && !showWrong)
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
                        ),
                      );
                    }),
                  ],
                ),
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
              onPressed: (_isCorrect && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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
    required this.correctWord,
    required this.nextLabel,
    required this.onFinish,
    required this.onShowCompletionDialog,
    required this.canFinishLesson,
    required this.playAudio,
  });

  final String audioQuestionKey;
  final String correctWord;
  final String nextLabel;
  final Future<void> Function({bool skipCompletionDialog}) onFinish;
  final Future<void> Function(bool, bool, bool) onShowCompletionDialog;
  final bool canFinishLesson;
  final Future<void> Function(String) playAudio;

  @override
  State<_FormatWordWidget> createState() => _FormatWordWidgetState();
}

class _FormatWordWidgetState extends State<_FormatWordWidget> {
  late List<String> _availableLetters;
  final List<String> _selectedLetters = [];
  bool _isCorrect = false;
  bool _showError = false;
  bool _hasPlayedAudio = false;

  @override
  void initState() {
    super.initState();
    _availableLetters = widget.correctWord.split('')..shuffle();
    
    // Play audio question on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasPlayedAudio && widget.audioQuestionKey.isNotEmpty) {
        _hasPlayedAudio = true;
        widget.playAudio(widget.audioQuestionKey);
      }
    });
  }

  void _handleLetterTap(int index) {
    setState(() {
      final letter = _availableLetters[index];
      _selectedLetters.add(letter);
      _availableLetters.removeAt(index);
      _showError = false;
    });

    // Check if word is complete
    if (_availableLetters.isEmpty) {
      _checkAnswer();
    }
  }

  void _handleSelectedTap(int index) {
    setState(() {
      final letter = _selectedLetters[index];
      _availableLetters.add(letter);
      _selectedLetters.removeAt(index);
      _isCorrect = false;
      _showError = false;
    });
  }

  void _checkAnswer() {
    final formedWord = _selectedLetters.join('');
    final correct = formedWord.toLowerCase() == widget.correctWord.toLowerCase();

    setState(() {
      _isCorrect = correct;
      _showError = !correct;
    });

    if (correct) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showError = false);
        }
      });
    }
  }

  void _reset() {
    setState(() {
      _availableLetters = widget.correctWord.split('')..shuffle();
      _selectedLetters.clear();
      _isCorrect = false;
      _showError = false;
    });
  }

  Future<void> _handleNext() async {
    if (_isCorrect) {
      await widget.onShowCompletionDialog(true, false, false);
      await widget.onFinish(skipCompletionDialog: true);
    } else {
      SnackBarUtils.showInfo(context, 'Formează cuvântul corect pentru a continua!');
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Ascultă și formează cuvântul',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => widget.playAudio(widget.audioQuestionKey),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2D72D2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.volume_up, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Selected letters area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isCorrect
                            ? Colors.green.withOpacity(0.1)
                            : _showError
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCorrect
                              ? Colors.green
                              : _showError
                                  ? Colors.red
                                  : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _selectedLetters.isEmpty
                          ? Text(
                              'Selectează literele...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: List.generate(_selectedLetters.length, (index) {
                                return GestureDetector(
                                  onTap: () => _handleSelectedTap(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isCorrect
                                          ? Colors.green
                                          : _showError
                                              ? Colors.red
                                              : const Color(0xFFEA2233),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _selectedLetters[index].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                    ),
                    if (_showError) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Încearcă din nou!',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _reset,
                              child: const Text('Resetează'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Available letters
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(_availableLetters.length, (index) {
                        return GestureDetector(
                          onTap: () => _handleLetterTap(index),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D72D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2D72D2).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _availableLetters[index].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17406B),
                              ),
                            ),
                          ),
                        );
                      }),
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
              onPressed: (_isCorrect && widget.canFinishLesson) ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: (_isCorrect && widget.canFinishLesson) ? const Color(0xFFEA2233) : Colors.grey[400],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Lecția nu are conținut.'));
}
