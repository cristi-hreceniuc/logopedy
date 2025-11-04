// lib/features/content/presentation/lesson_player_page.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
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
  final _player = AudioPlayer();

  LessonDto? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // 1) Context audio corect (iOS + Android)
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setAudioContext(
      const AudioContext(
        iOS: AudioContextIOS(
          // redă chiar dacă telefonul e pe mute / switch silențios
          category: AVAudioSessionCategory.playback,
          options: [AVAudioSessionOptions.mixWithOthers],
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

    _load();
  }

  @override
  void dispose() {
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

  String _asset(String kind, String name) {
    if (name.isEmpty) return name;
    if (name.startsWith('assets/')) return name;
    if (kind == 'img') {
      final base = 'assets/images/';
      return name.contains('.') ? '$base$name' : '$base$name.png';
    } else if (kind == 'snd') {
      final base = 'assets/audio/';
      return name.contains('.') ? '$base$name' : '$base$name.m4a';
    }
    return name;
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
      // debug payload
      for (final sc in _data!.screens) {
        debugPrint('SCREEN ${sc.screenType} => ${sc.payload}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _playAssetAudio(String uri) async {
    if (uri.isEmpty) return;
    // AssetSource primește calea FĂRĂ prefixul "assets/"
    final path = uri.startsWith('assets/') ? uri.substring(7) : uri;
    await _player.stop();
    await _player.play(AssetSource(path), volume: 1.0);
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 2),
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
              Navigator.of(context).maybePop(true);
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
            Navigator.of(context).maybePop(true);
          }
        } else {
          debugPrint('🎉 No valid next lesson data, going back to submodule');
          debugPrint('🎉 Next lesson ID: ${resp.nextLessonId}, Response lesson ID: ${resp.lessonId}, Widget lesson ID: ${widget.lessonId}');
          // No fallback navigation - just go back to submodule
          Navigator.of(context).maybePop(true);
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
          
          // Navigate back to submodule
          if (mounted) {
            Navigator.of(context).maybePop(true);
          }
          return;
        }
      }
      
      // For other errors, show error message
      SnackBarUtils.showError(context, e.toString());
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF17406B),
          ),
        ),
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
                          color: Colors.white,
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
                                      color: const Color(0xFF17406B),
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
                                    color: const Color(0xFF17406B),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                        color: Colors.white,
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
                                color: const Color(0xFF17406B),
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
                                color: const Color(0xFF17406B),
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
                                  color: const Color(0xFF17406B),
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
                                            color: const Color(0xFF17406B),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                        color: Colors.white,
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
                                color: const Color(0xFF17406B),
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
                                    color: const Color(0xFF17406B),
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
                                color: const Color(0xFF17406B),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
            if (uri.isEmpty) return;
            await _player.stop();
            await _playAssetAudio(uri);
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
                        color: Colors.white,
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
                                color: const Color(0xFF17406B),
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
                                child: Image.asset(
                                  imgUri,
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 240,
                                    height: 240,
                                    color: Colors.grey[200],
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                                  ),
                                ),
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
                                  Text(
                                    word,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF17406B),
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
                                      onPressed: () => _playAssetAudio(wordAudioUri),
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
                                color: const Color(0xFF17406B),
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
                                      onTap: () => _playAssetAudio(uri),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
            color: const Color(0xFF17406B),
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
                      color: Colors.white,
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
                            color: const Color(0xFF17406B),
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
                                  color: const Color(0xFFF3F5F8),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
            color: const Color(0xFF17406B),
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
                        color: Colors.white,
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
                              color: const Color(0xFF17406B),
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
                                child: imgUrl.startsWith('assets/')
                                    ? Image.asset(
                                        imgUrl,
                                        width: 240,
                                        height: 240,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        imgUrl,
                                        width: 240,
                                        height: 240,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // mască mare centrată + buton "Arată"
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F5F8),
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
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2233),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                  color: Colors.white,
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
                        color: const Color(0xFF17406B),
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
                          child: widget.imgUrl.startsWith('assets/')
                              ? Image.asset(
                                  widget.imgUrl,
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  widget.imgUrl,
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.cover,
                                ),
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
              onPressed: _canProceed ? _handleNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: _canProceed ? const Color(0xFFEA2233) : Colors.grey[400],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.nextLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
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
