// lib/features/content/presentation/modules_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/snackbar_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _f = repo.modules(widget.profileId);
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
    // 1) ia detaliile modulului (lista de submodule)
    late final ModuleDetailsDto md;
    try {
      md = await repo.moduleDetails(widget.profileId, m.id);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Nu pot încărca submodulele: $e');
      return;
    }

    if (!mounted) return;

    // 2) dacă nu are submodule, anunță
    if (md.submodules.isEmpty) {
      SnackBarUtils.showInfo(context, 'Modulul nu are submodule disponibile.');
      return;
    }

    // 3) navighează către o pagină de selecție submodule
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SubmoduleSelectionPage(
          profileId: widget.profileId,
          moduleTitle: m.title,
          submodules: md.submodules,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Module',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF17406B),
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
                  return FutureBuilder<double>(
                    future: _getModuleProgress(m),
                    builder: (context, progressSnapshot) {
                      final progress = progressSnapshot.data ?? 0.0;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openModule(m),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D72D2).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.menu_book_rounded,
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
                                            m.title,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF17406B),
                                            ),
                                          ),
                                          if (m.introText != null && m.introText!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              m.introText!,
                                              style: TextStyle(
                                                color: Colors.grey[600],
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
                                      Icons.chevron_right_rounded,
                                      color: const Color(0xFF2D72D2),
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
                                    backgroundColor: const Color(0xFF2D72D2).withOpacity(0.1),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2D72D2),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(progress * 100).round()}% complet',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          moduleTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF17406B),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubmodulePage(
                          profileId: profileId,
                          submoduleId: s.id,
                          title: s.title,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                                  color: const Color(0xFF17406B),
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