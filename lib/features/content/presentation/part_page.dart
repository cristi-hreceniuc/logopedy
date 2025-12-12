import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../profiles/selected_profile_cubit.dart';
import '../content_repository.dart';
import '../models/part_dto.dart';
import '../models/lesson_list_item_dto.dart';
import '../models/enums.dart';
import 'lesson_player_page.dart';

class PartPage extends StatefulWidget {
  const PartPage({
    super.key,
    required this.profileId,
    required this.partId,
    required this.title,
  });

  final int profileId;
  final int partId;
  final String title;

  @override
  State<PartPage> createState() => _PartPageState();
}

class _PartPageState extends State<PartPage> {
  late final repo = ContentRepository(GetIt.I<DioClient>());
  late Future<PartDto> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.getPart(widget.profileId, widget.partId);
  }

  @override
  void didUpdateWidget(PartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId || oldWidget.partId != widget.partId) {
      setState(() {
        _f = repo.getPart(widget.profileId, widget.partId);
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    final activePid = context.read<SelectedProfileCubit>().state;
    final pid = activePid ?? widget.profileId;
    
    debugPrint('🔄 Refreshing part ${widget.partId} for profile $pid');
    
    setState(() {
      _f = repo.getPart(pid, widget.partId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePid = context.watch<SelectedProfileCubit>().state;
    final cs = Theme.of(context).colorScheme;
    final authState = context.watch<AuthCubit>().state;
    final isSpecialist = authState.userRole == 'SPECIALIST';

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
        child: FutureBuilder<PartDto>(
          future: _f,
          builder: (c, s) {
            if (!s.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                ),
              );
            }
            
            final part = s.data!;
            final progress = part.totalLessons > 0 
                ? part.completedLessons / part.totalLessons 
                : 0.0;

            return Column(
              children: [
                // Progress card
                if (part.totalLessons > 0)
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
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.track_changes_rounded,
                                size: 28,
                                color: Color(0xFF4CAF50),
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
                                    '${part.completedLessons} din ${part.totalLessons} lecții completate',
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
                          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4CAF50),
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
                    itemCount: part.lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final l = part.lessons[i];
                      final isLocked = isSpecialist 
                          ? false 
                          : l.status == 'LOCKED';
                      final isDone = l.status == 'DONE';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (isLocked) {
                              SnackBarUtils.showInfo(context, 'Deblochează mai întâi lecția anterioară.');
                              return;
                            }

                            final pid = activePid ?? widget.profileId;
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => LessonPlayerPage(
                                  profileId: pid,
                                  lessonId: l.id,
                                  title: l.title,
                                  isAlreadyDone: isDone,
                                ),
                              ),
                            );

                            debugPrint('🔄 Returning from lesson ${l.id}, changed=$changed');
                            if (mounted && changed == true) {
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
                                      color: const Color(0xFF4CAF50).withOpacity(0.3),
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
                                            ? const Color(0xFF4CAF50).withOpacity(0.1)
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
                                            ? const Color(0xFF4CAF50)
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
                                      if (l.hint != null && l.hint!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          l.hint!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 24,
                                  color: Colors.grey[400],
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
