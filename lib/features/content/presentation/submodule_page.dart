import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../profiles/selected_profile_cubit.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/submodule_list_dto.dart';
import '../models/enums.dart';
import 'lesson_player_page.dart';
import 'part_page.dart';

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
  late Future<SubmoduleListDto> _f;
  
  // Track if any progress was made during this session (for back navigation)
  bool _progressMade = false;

  @override
  void initState() {
    super.initState();
    _f = repo.submoduleWithParts(widget.profileId, widget.submoduleId);
  }

  @override
  void didUpdateWidget(SubmodulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if profileId or submoduleId changed
    if (oldWidget.profileId != widget.profileId || oldWidget.submoduleId != widget.submoduleId) {
      setState(() {
        _f = repo.submoduleWithParts(widget.profileId, widget.submoduleId, forceRefresh: true);
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
      _f = repo.submoduleWithParts(pid, widget.submoduleId, forceRefresh: true);
    });
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
        child: FutureBuilder<SubmoduleListDto>(
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

              // Calculate progress from parts
              final totalLessons = sub.parts.fold<int>(0, (sum, p) => sum + p.totalLessons);
              final completedLessons = sub.parts.fold<int>(0, (sum, p) => sum + p.completedLessons);
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
                  // Parts list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: sub.parts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final part = sub.parts[i];
                        final partProgress = part.totalLessons > 0 
                            ? part.completedLessons / part.totalLessons 
                            : 0.0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final pid = activePid ?? widget.profileId;
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => PartPage(
                                    profileId: pid,
                                    partId: part.id,
                                    title: part.name,
                                  ),
                                ),
                              );

                              debugPrint('🔄 Returning from part ${part.id}, changed=$changed');
                              if (mounted && changed == true) {
                                // Track that progress was made
                                _progressMade = true;
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (mounted) {
                                  debugPrint('🔄 Triggering refresh after returning from part');
                                  _refresh();
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: part.isCompleted
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: part.isCompleted
                                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                                              : part.isInProgress
                                                  ? const Color(0xFF2D72D2).withOpacity(0.1)
                                                  : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          part.isCompleted
                                              ? Icons.check_circle_rounded
                                              : part.isInProgress
                                                  ? Icons.play_circle_filled_rounded
                                                  : Icons.folder_rounded,
                                          size: 30,
                                          color: part.isCompleted
                                              ? const Color(0xFF4CAF50)
                                              : part.isInProgress
                                                  ? const Color(0xFF2D72D2)
                                                  : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              part.name,
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${part.completedLessons}/${part.totalLessons} lecții',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 28,
                                        color: part.isCompleted
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFF2D72D2),
                                      ),
                                    ],
                                  ),
                                  if (part.totalLessons > 0) ...[
                                    const SizedBox(height: 16),
                                      LinearProgressIndicator(
                                        value: partProgress,
                                        borderRadius: BorderRadius.circular(6),
                                        minHeight: 8,
                                        backgroundColor: part.isCompleted
                                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                                            : const Color(0xFF2D72D2).withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          part.isCompleted
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFF2D72D2),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${(partProgress * 100).round()}% complet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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