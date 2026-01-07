import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../kid/data/kid_api.dart';
import '../../profiles/selected_profile_cubit.dart';
import '../content_repository.dart';
import '../models/part_dto.dart';
import 'lesson_player_page.dart';

class PartPage extends StatefulWidget {
  const PartPage({
    super.key,
    required this.profileId,
    required this.partId,
    required this.title,
    this.isKid = false,
  });

  final int profileId;
  final int partId;
  final String title;
  final bool isKid;

  @override
  State<PartPage> createState() => _PartPageState();
}

class _PartPageState extends State<PartPage> {
  late final repo = ContentRepository(GetIt.I<DioClient>());
  late final kidApi = KidApi(GetIt.I<DioClient>());
  PartDto? _data;
  bool _isLoading = true;
  
  // Track if any progress was made during this session (for back navigation)
  bool _progressMade = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(PartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId || oldWidget.partId != widget.partId) {
      _loadData(forceRefresh: true);
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    
    final activePid = context.read<SelectedProfileCubit>().state;
    final pid = activePid ?? widget.profileId;
    
    debugPrint('🔄 Loading part ${widget.partId} for profile $pid (forceRefresh: $forceRefresh, isKid: ${widget.isKid})');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final PartDto data;
      if (widget.isKid) {
        final json = await kidApi.getPart(widget.partId, forceRefresh: forceRefresh);
        data = PartDto.fromJson(json);
      } else {
        data = await repo.getPart(pid, widget.partId, forceRefresh: forceRefresh);
      }
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔄 Error loading part: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refresh() {
    _loadData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final activePid = context.watch<SelectedProfileCubit>().state;
    final cs = Theme.of(context).colorScheme;
    final authState = context.watch<AuthCubit>().state;
    final isSpecialist = authState.userRole == 'SPECIALIST';

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
        ),
        body: SafeArea(
        top: true,
        bottom: true,
        child: Builder(
          builder: (c) {
            if (_isLoading || _data == null) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                ),
              );
            }
            
            final part = _data!;
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
                            final feedback = GetIt.I<FeedbackService>();
                            
                            if (isLocked) {
                              feedback.warning();
                              SnackBarUtils.showInfo(context, 'Deblochează mai întâi lecția anterioară.');
                              return;
                            }
                            
                            // Play navigation feedback
                            feedback.navigation();

                            final pid = activePid ?? widget.profileId;
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => LessonPlayerPage(
                                  profileId: pid,
                                  lessonId: l.id,
                                  title: l.title,
                                  isAlreadyDone: isDone,
                                  isKid: widget.isKid,
                                ),
                              ),
                            );

                            debugPrint('🔄 Returning from lesson ${l.id}, changed=$changed');
                            
                            // Track progress if changes were made
                            if (changed == true) {
                              _progressMade = true;
                            }
                            
                            // Always refresh when returning from lesson to ensure progress is up to date
                            if (mounted) {
                              debugPrint('🔄 Triggering refresh after returning from lesson');
                              _refresh();
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
      ),
    );
  }
}
