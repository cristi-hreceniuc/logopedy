import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../content/presentation/modules_page.dart';
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
          );
        },
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final HomeworkDTO homework;
  final int profileId;

  const _HomeworkCard({
    required this.homework,
    required this.profileId,
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
        onTap: () {
          // Navigate to the homework content
          _navigateToHomework(context);
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

  void _navigateToHomework(BuildContext context) {
    // Navigate based on the most specific homework assignment type
    // Priority: part > submodule > module
    if (homework.partId != null) {
      // Navigate to part page
      Navigator.push(
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
      Navigator.push(
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
      // Navigate to modules page (show the specific module)
      // For simplicity, we'll navigate to the modules page
      // The user can then select the specific module
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ModulesPage(
            profileId: profileId,
            isKid: true,
          ),
        ),
      );
    } else {
      // No specific content assigned, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Această temă nu are conținut specific asociat.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

