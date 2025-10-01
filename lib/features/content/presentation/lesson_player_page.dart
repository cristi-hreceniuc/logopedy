// lib/features/content/presentation/lesson_player_page.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
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

Widget _gap([double h = 12]) => SizedBox(height: h);


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

  /// Lecțiile actuale au 1 singur ecran -> marcăm DONE și ieșim
  Future<void> _finishLesson() async {
    try {
      await _repo.advance(
        widget.profileId,
        lessonId: widget.lessonId,
        screenIndex: 0,
        done: true,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _data == null || _data!.screens.isEmpty
          ? const _EmptyView()
          : _renderScreen(_data!.screens.first, cs),
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

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Conținutul în card, centrat și aerisit
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (title.isNotEmpty) ...[
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      // titlu mare (aceeași familie de font din app theme)
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    // corp mărit și lizibil
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(fontSize: 20, height: 1.45),
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      next,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 12),

                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.45,
                      ),
                    ),

                  if (subtitle.isNotEmpty || bullets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    if (bullets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...bullets.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(
                                child: Text(
                                  e,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],

                  const Spacer(),
                  FilledButton(
                    onPressed: _finishLesson,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
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
                ],
              ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (title.isNotEmpty) _gap(8),
                Expanded(
                  child: SingleChildScrollView(
                    child: paragraphs.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...paragraphs.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '$e',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                  ),
                ),
                _gap(),
                FilledButton(onPressed: _finishLesson, child: Text(next)),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty)
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                _gap(12),
                if (imgUri.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        imgUri,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 64),
                      ),
                    ),
                  ),
                _gap(16),
                if (word.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          word,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () => _playAssetAudio(wordAudioUri),
                      ),
                    ],
                  ),
                if (syllables.isNotEmpty) ...[
                  _gap(8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: syllables.map((e) {
                      final txt = _asString(e['text']);
                      final uri = _assetUri(e['audio']);
                      return ActionChip(
                        label: Text(txt),
                        onPressed: () => _playAssetAudio(uri),
                      );
                    }).toList(),
                  ),
                ],
                const Spacer(),
                FilledButton(onPressed: _finishLesson, child: Text(next)),
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
          );
          final highlightStyle = wordStyle.copyWith(
            color: cs.error,
            fontWeight: FontWeight.w700,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    itemCount: pairs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 28, thickness: 1),
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

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // cuvântul — mare & centrat pe linie
                          Expanded(
                            child: Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: revealed
                                    ? _coloredMaskedWord(
                                        // helperul pe care ți l-am dat
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

                          TextButton(
                            onPressed: () =>
                                setState(() => it['revealed'] = true),
                            style: TextButton.styleFrom(
                              textStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              foregroundColor: revealed ? cs.outline : cs.error,
                            ),
                            child: Text('Arată'),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _finishLesson,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    'Următorul',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
          );
          final hiStyle = wordStyle.copyWith(
            color: cs.error,
            fontWeight: FontWeight.w700,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                if (imgUrl.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imgUrl.startsWith('assets/')
                          ? Image.asset(
                              imgUrl,
                              width: 220,
                              height: 220,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              imgUrl,
                              width: 220,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),

                const SizedBox(height: 16),

                // mască mare centrată + buton "Arată"
                StatefulBuilder(
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
                        TextButton(
                          onPressed: () => setSB(() => p['revealed'] = true),
                          style: TextButton.styleFrom(
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            foregroundColor: revealed ? cs.outline : cs.error,
                          ),
                          child: const Text('Arată'),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),
                FilledButton(
                  onPressed: _finishLesson,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    next,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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

          final cs = Theme.of(context).colorScheme;
          final ctrl = TextEditingController();

          return StatefulBuilder(
            builder: (ctx, setSB) {
              bool revealed = (p['revealed'] as bool?) ?? false;
              bool isCorrect() =>
                  _normalize(ctrl.text) == _normalize(correctWord);

              void _onChanged(String _) => setSB(() {
                /* doar re-build pentru feedback */
              });

              Future<void> _onNext() async {
                if (isCorrect() || revealed) {
                  await _finishLesson();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mai încearcă!')),
                  );
                }
              }

              final good = isCorrect();
              final bad = !good && ctrl.text.trim().isNotEmpty;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 12),

                    if (imgUrl.isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: imgUrl.startsWith('assets/')
                              ? Image.asset(
                                  imgUrl,
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  imgUrl,
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: ctrl,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onNext(),
                      decoration: InputDecoration(
                        labelText: 'Scrie cuvântul',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: good ? cs.primary : cs.primary,
                          ),
                        ),
                        suffixIcon: good
                            ? const Icon(Icons.check_circle, size: 24)
                            : (bad ? const Icon(Icons.cancel, size: 24) : null),
                        suffixIconColor: good
                            ? Colors.green
                            : (bad ? Colors.red : null),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: revealed
                            ? null
                            : () => setSB(() {
                                p['revealed'] = true;
                                revealed = true;
                                ctrl.text = correctWord; // autopopulează
                              }),
                        style: TextButton.styleFrom(
                          foregroundColor: revealed ? cs.outline : cs.error,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(helpLabel),
                      ),
                    ),

                    const Spacer(),

                    FilledButton(
                      onPressed: _onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        next,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
