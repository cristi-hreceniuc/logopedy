// lib/features/content/presentation/modules_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../features/session/session_info.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/modules_details_dto.dart';
import 'submodule_page.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage({super.key, required this.profileId});
  final int profileId;

  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
  late final repo = ContentRepository(GetIt.I<DioClient>());
  late Future<List<ModuleDto>> _f;
  bool? _isPremium;

  @override
  void initState() {
    super.initState();
    _f = repo.modules(widget.profileId);
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final sessionInfo = await SessionInfo.fromStorage();
    if (mounted) {
      setState(() {
        _isPremium = sessionInfo?.isPremium ?? false;
      });
    }
  }

  @override
  void didUpdateWidget(ModulesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      setState(() {
        _f = repo.modules(widget.profileId);
      });
    }
  }

  Future<void> _refreshModules() async {
    setState(() {
      _f = repo.modules(widget.profileId);
    });
  }

  Future<double> _getModuleProgress(ModuleDto module) async {
    try {
      final details = await repo.moduleDetails(widget.profileId, module.id);
      if (details.submodules.isEmpty) return 0.0;

      int completedSubmodules = 0;
      for (final sub in details.submodules) {
        try {
          final submoduleData = await repo.submodule(widget.profileId, sub.id);
          final totalLessons = submoduleData.lessons.length;
          if (totalLessons == 0) continue;
          
          final completedLessons = submoduleData.lessons.where((l) =>
            l is LessonLiteWithStatus && l.status == 'DONE'
          ).length;
          
          if (completedLessons == totalLessons) {
            completedSubmodules++;
          }
        } catch (e) {
          // Skip submodules that can't be loaded
          continue;
        }
      }

      return details.submodules.isNotEmpty
          ? completedSubmodules / details.submodules.length
          : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _openModule(ModuleDto m) async {
    // Check if module is premium and user doesn't have premium access
    if (m.isPremium && _isPremium != true) {
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        'Acest modul necesită cont Premium. Contactează administratorul pentru a obține acces.',
      );
      return;
    }

    // 1) ia detaliile modulului (lista de submodule)
    late final ModuleDetailsDto md;
    try {
      md = await repo.moduleDetails(widget.profileId, m.id);
    } catch (e) {
      if (!mounted) return;
      
      // Check if it's a 403 Forbidden error
      if (e is DioException && e.response?.statusCode == 403) {
        SnackBarUtils.showInfo(
          context,
          'Acest modul necesită cont Premium. Contactează administratorul pentru a obține acces.',
        );
      } else {
        SnackBarUtils.showError(context, 'Nu pot încărca submodulele: $e');
      }
      return;
    }

    if (!mounted) return;

    // 2) dacă nu are submodule, anunță
    if (md.submodules.isEmpty) {
      SnackBarUtils.showInfo(context, 'Modulul nu are submodule disponibile.');
      return;
    }

    // 3) navighează către o pagină de selecție submodule
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SubmoduleSelectionPage(
          profileId: widget.profileId,
          moduleTitle: m.title,
          submodules: md.submodules,
        ),
      ),
    );
    
    // Refresh modules if returning from submodule navigation
    // This ensures progress updates are reflected
    if (result == true && mounted) {
      _refreshModules();
    }
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
          'Module',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: FutureBuilder<List<ModuleDto>>(
            future: _f,
            builder: (c, s) {
              if (!s.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                  ),
                );
              }
              final modules = s.data!;
              if (modules.isEmpty) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Nu există module',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final m = modules[i];
                  final isPremiumModule = m.isPremium;
                  final hasPremiumAccess = _isPremium == true;
                  final isLocked = isPremiumModule && !hasPremiumAccess;
                  
                  return FutureBuilder<double>(
                    future: _getModuleProgress(m),
                    builder: (context, progressSnapshot) {
                      final progress = progressSnapshot.data ?? 0.0;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openModule(m),
                          borderRadius: BorderRadius.circular(24),
                          child: Opacity(
                            opacity: isLocked ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(20),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isLocked
                                              ? Colors.grey.withOpacity(0.1)
                                              : const Color(0xFF2D72D2).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          size: 28,
                                          color: isLocked
                                              ? Colors.grey[600]
                                              : const Color(0xFF2D72D2),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    m.title,
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      color: isLocked
                                                          ? Colors.grey[600]
                                                          : Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (isPremiumModule) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isLocked
                                                          ? Colors.grey.withOpacity(0.2)
                                                          : const Color(0xFFEA2233).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isLocked
                                                            ? Colors.grey.withOpacity(0.3)
                                                            : const Color(0xFFEA2233).withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.star_rounded,
                                                          size: 12,
                                                          color: isLocked
                                                              ? Colors.grey[600]
                                                              : const Color(0xFFEA2233),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Premium',
                                                          style: TextStyle(
                                                            color: isLocked
                                                                ? Colors.grey[600]
                                                                : const Color(0xFFEA2233),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (m.introText != null && m.introText!.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                m.introText!,
                                                style: TextStyle(
                                                  color: isLocked
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
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
                                        isLocked
                                            ? Icons.lock_outline_rounded
                                            : Icons.chevron_right_rounded,
                                        color: isLocked
                                            ? Colors.grey[600]
                                            : const Color(0xFF2D72D2),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                  if (progress > 0 || progressSnapshot.connectionState == ConnectionState.done) ...[
                                    const SizedBox(height: 16),
                                    LinearProgressIndicator(
                                      value: progress,
                                      borderRadius: BorderRadius.circular(8),
                                      minHeight: 8,
                                      backgroundColor: isLocked
                                          ? Colors.grey.withOpacity(0.1)
                                          : const Color(0xFF2D72D2).withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isLocked
                                            ? Colors.grey[600]!
                                            : const Color(0xFF2D72D2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(progress * 100).round()}% complet',
                                      style: TextStyle(
                                        color: isLocked
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
    );
  }
}

// Submodule Selection Page
class _SubmoduleSelectionPage extends StatelessWidget {
  final int profileId;
  final String moduleTitle;
  final List<SubmoduleLite> submodules;

  const _SubmoduleSelectionPage({
    required this.profileId,
    required this.moduleTitle,
    required this.submodules,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          moduleTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: submodules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) {
              final s = submodules[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubmodulePage(
                          profileId: profileId,
                          submoduleId: s.id,
                          title: s.title,
                        ),
                      ),
                    );
                    
                    // Refresh modules page when returning from submodule
                    // This ensures progress updates are reflected
                    if (result == true && context.mounted) {
                      // Return true to signal parent modules page to refresh
                      Navigator.of(context).pop(true);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D72D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.book_rounded,
                            size: 28,
                            color: const Color(0xFF2D72D2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (s.introText != null && s.introText!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  s.introText!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
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
                          color: const Color(0xFF2D72D2),
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
    );
  }
}