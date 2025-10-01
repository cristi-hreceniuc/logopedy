// lib/features/content/presentation/submodule_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import 'lesson_player_page.dart';

class SubmodulePage extends StatefulWidget {
  const SubmodulePage({
    super.key,
    required this.profileId,
    required this.submoduleId,
    required this.title,
  });

  final int profileId, submoduleId;
  final String title;

  @override
  State<SubmodulePage> createState() => _SubmodulePageState();
}

class _SubmodulePageState extends State<SubmodulePage> {
  late final repo = ContentRepository(GetIt.I<DioClient>());
  late Future<SubmoduleDto> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.submodule(widget.profileId, widget.submoduleId);
  }

  void _refresh() {
    setState(() {
      _f = repo.submodule(widget.profileId, widget.submoduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<SubmoduleDto>(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sub = s.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final l = sub.lessons[i];

              final isLocked = (l is LessonLiteWithStatus)
                  ? l.status == 'LOCKED'
                  : i > 0; // fallback dacă încă folosești LessonLiteDto simplu

              return ListTile(
                leading: Icon(isLocked ? Icons.lock_outline : Icons.play_circle_fill),
                title: Text(l.title),
                subtitle: Text(l.lessonType.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (isLocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deblochează mai întâi lecția anterioară.')),
                    );
                    return;
                  }

                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => LessonPlayerPage(
                        profileId: widget.profileId,
                        lessonId: l.id,
                        title: l.title,
                      ),
                    ),
                  );

                  // dacă player-ul a avansat progresul, refacem lista
                  if (changed == true && mounted) {
                    _refresh();
                  }

                  if (l.status == 'LOCKED') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deblochează întâi lecția anterioară.')),
                    );
                    return;
                  }
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: sub.lessons.length,
          );
        },
      ),
    );
  }
}
