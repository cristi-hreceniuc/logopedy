import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../content/presentation/part_page.dart';
import '../../content/presentation/submodule_page.dart';
import '../data/kid_api.dart';
import '../models/homework_dto.dart';

class HomeworkTab extends StatefulWidget {
  final int profileId;

  const HomeworkTab({super.key, required this.profileId});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  late final KidApi _api;
  List<HomeworkDTO>? _homework;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = KidApi(GetIt.I<DioClient>());
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final homework = await _api.getHomework();
      if (mounted) {
        setState(() {
          _homework = homework;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nu am putut încărca temele. Încearcă din nou.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temele mele'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHomework,
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadHomework,
              icon: const Icon(Icons.refresh),
              label: const Text('Reîncearcă'),
            ),
          ],
        ),
      );
    }

    if (_homework == null || _homework!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: cs.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Nicio temă deocamdată',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Specialistul tău nu ți-a dat încă teme.\nVei vedea aici temele când le primești.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _homework!.length,
        itemBuilder: (context, index) {
          final hw = _homework![index];
          return _HomeworkCard(
            homework: hw,
            profileId: widget.profileId,
            onRefresh: _loadHomework,
          );
        },
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final HomeworkDTO homework;
  final int profileId;
  final VoidCallback onRefresh;

  const _HomeworkCard({
    required this.homework,
    required this.profileId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOverdue = homework.dueDate != null && 
        homework.dueDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Navigate to the homework content
          await _navigateToHomework(context);
          // Refresh homework list when returning
          onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      homework.typeDescription,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Întârziat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                homework.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (homework.notes != null && homework.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  homework.notes!,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    homework.dueDate != null
                        ? 'Până la: ${_formatDate(homework.dueDate!)}'
                        : 'Fără termen limită',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOverdue ? cs.error : cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _navigateToHomework(BuildContext context) async {
    // Navigate based on the most specific homework assignment type
    // Priority: part > submodule > module
    if (homework.partId != null) {
      // Navigate to part page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartPage(
            profileId: profileId,
            partId: homework.partId!,
            title: homework.partName ?? 'Partea',
            isKid: true,
          ),
        ),
      );
    } else if (homework.submoduleId != null) {
      // Navigate to submodule page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubmodulePage(
            profileId: profileId,
            submoduleId: homework.submoduleId!,
            title: homework.submoduleName ?? 'Submodul',
            isKid: true,
          ),
        ),
      );
    } else if (homework.moduleId != null) {
      // Navigate directly to the module's submodule selection
      try {
        final kidApi = KidApi(GetIt.I<DioClient>());
        final moduleData = await kidApi.getModule(homework.moduleId!);
        final submodules = (moduleData['submodules'] as List?) ?? [];
        
        if (submodules.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Modulul nu are submodule disponibile.')),
            );
          }
          return;
        }
        
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ModuleSubmoduleSelectionPage(
                profileId: profileId,
                moduleTitle: homework.moduleName ?? 'Modul',
                submodules: submodules,
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la încărcarea modulului: $e')),
          );
        }
      }
    } else {
      // No specific content assigned
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Această temă nu are conținut specific asociat.'),
        ),
      );
    }
  }
}

/// Submodule selection page for module homework
class _ModuleSubmoduleSelectionPage extends StatelessWidget {
  final int profileId;
  final String moduleTitle;
  final List<dynamic> submodules;

  const _ModuleSubmoduleSelectionPage({
    required this.profileId,
    required this.moduleTitle,
    required this.submodules,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(moduleTitle),
        centerTitle: true,
      ),
      body: submodules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: cs.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nu există submodule disponibile.'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: submodules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sub = submodules[index] as Map<String, dynamic>;
                final id = sub['id'] as int;
                final title = sub['title'] as String? ?? 'Submodul ${index + 1}';
                final introText = sub['introText'] as String?;
                
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubmodulePage(
                            profileId: profileId,
                            submoduleId: id,
                            title: title,
                            isKid: true,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (introText != null && introText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    introText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

