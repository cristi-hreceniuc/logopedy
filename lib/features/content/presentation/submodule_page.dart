import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../profiles/selected_profile_cubit.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/enums.dart';
import 'lesson_player_page.dart';

class SubmodulePage extends StatefulWidget {
  const SubmodulePage({
    super.key,
    required this.profileId,
    required this.submoduleId,
    required this.title,
  });

  final int profileId;
  final int submoduleId;
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

  @override
  void didUpdateWidget(SubmodulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if profileId or submoduleId changed
    if (oldWidget.profileId != widget.profileId || oldWidget.submoduleId != widget.submoduleId) {
      setState(() {
        _f = repo.submodule(widget.profileId, widget.submoduleId, forceRefresh: true);
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    // Use active profile ID if available, otherwise use widget.profileId
    final activePid = context.read<SelectedProfileCubit>().state;
    final pid = activePid ?? widget.profileId;
    
    debugPrint('🔄 Refreshing submodule ${widget.submoduleId} for profile $pid (force refresh)');
    
    setState(() {
      // Refresh with the active profile ID and force refresh to bypass cache
      // This ensures we get the latest lesson completion status from the backend
      _f = repo.submodule(pid, widget.submoduleId, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePid = context.watch<SelectedProfileCubit>().state;
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
        ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: FutureBuilder<SubmoduleDto>(
        future: _f,
        builder: (c, s) {
              if (!s.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                  ),
                );
              }
          final sub = s.data!;

              // Calculate progress - ensure we're using the active profile's data
              final totalLessons = sub.lessons.length;
              final completedLessons = sub.lessons.where((l) =>
                l is LessonLiteWithStatus && l.status == 'DONE'
              ).length;
              final progress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;

              return Column(
                children: [
                  // Progress card
                  if (totalLessons > 0)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA2233).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.track_changes_rounded,
                                  size: 28,
                                  color: const Color(0xFFEA2233),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Progres',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedLessons din $totalLessons lecții completate',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: progress,
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFEA2233).withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFEA2233),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).round()}% complet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Lessons list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: sub.lessons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final l = sub.lessons[i];
              // dacă ai LessonLiteWithStatus, l.status există; altfel fallback: prima deblocată
              final isLocked = (l is LessonLiteWithStatus)
                  ? l.status == 'LOCKED'
                  : i > 0;
                        final isDone = (l is LessonLiteWithStatus) && l.status == 'DONE';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                onTap: () async {
                  if (isLocked) {
                                SnackBarUtils.showInfo(context, 'Deblochează mai întâi lecția anterioară.');
                    return;
                  }

                  // Use active profile ID if available, otherwise use widget.profileId
                  final pid = activePid ?? widget.profileId;
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => LessonPlayerPage(
                        profileId: pid,
                        lessonId: l.id,
                        title: l.title,
                      ),
                    ),
                  );

                  // Always refresh when returning from lesson to show updated progress
                  // This ensures the last lesson completion is reflected
                  // Add a delay to ensure backend has processed the update
                  debugPrint('🔄 Returning from lesson ${l.id}, changed=$changed');
                  if (mounted && changed == true) {
                    // Wait longer to ensure backend has processed the lesson completion
                    // This is especially important for the last lesson in a submodule
                    await Future.delayed(const Duration(milliseconds: 1000));
                    if (mounted) {
                      debugPrint('🔄 Triggering refresh after lesson completion');
                      _refresh();
                    }
                  }
                },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: isDone
                                    ? Border.all(
                                        color: const Color(0xFFEA2233).withOpacity(0.3),
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isLocked
                                          ? Colors.grey.withOpacity(0.1)
                                          : isDone
                                              ? const Color(0xFFEA2233).withOpacity(0.1)
                                              : const Color(0xFF2D72D2).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isLocked
                                          ? Icons.lock_outline_rounded
                                          : isDone
                                              ? Icons.check_circle_rounded
                                              : Icons.play_circle_filled_rounded,
                                      size: 28,
                                      color: isLocked
                                          ? Colors.grey[600]
                                          : isDone
                                              ? const Color(0xFFEA2233)
                                              : const Color(0xFF2D72D2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l.lessonType.romanianDescription,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isDone)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEA2233).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Complet',
                                        style: TextStyle(
                                          color: const Color(0xFFEA2233),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isLocked ? Colors.grey[400] : const Color(0xFF2D72D2),
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}