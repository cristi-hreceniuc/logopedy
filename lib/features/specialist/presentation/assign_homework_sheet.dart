import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../content/content_repository.dart';
import '../../content/models/dtos.dart';
import '../../content/models/modules_details_dto.dart';
import '../../content/models/submodule_list_dto.dart';
import '../../content/models/part_dto.dart';
import '../data/homework_api.dart';

class AssignHomeworkSheet extends StatefulWidget {
  final int profileId;
  final String profileName;

  const AssignHomeworkSheet({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<AssignHomeworkSheet> createState() => _AssignHomeworkSheetState();
}

class _AssignHomeworkSheetState extends State<AssignHomeworkSheet> {
  late final HomeworkApi _homeworkApi;
  late final ContentRepository _contentRepo;

  List<ModuleDto>? _modules;
  ModuleDetailsDto? _selectedModule;
  SubmoduleLite? _selectedSubmodule;
  SubmoduleListDto? _submoduleDetails;
  final Set<int> _selectedPartIds = {}; // Changed to Set for multi-select

  DateTime? _dueDate;
  final _notesController = TextEditingController();

  bool _isLoadingModules = true;
  bool _isLoadingSubmodules = false;
  bool _isLoadingParts = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _homeworkApi = HomeworkApi(GetIt.I<DioClient>());
    _contentRepo = ContentRepository(GetIt.I<DioClient>());
    _loadModules();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    try {
      final modules = await _contentRepo.modules(widget.profileId);
      if (mounted) {
        setState(() {
          _modules = modules;
          _isLoadingModules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nu am putut încărca modulele';
          _isLoadingModules = false;
        });
      }
    }
  }

  Future<void> _selectModule(ModuleDto module) async {
    setState(() {
      _selectedModule = null;
      _selectedSubmodule = null;
      _submoduleDetails = null;
      _selectedPartIds.clear();
      _isLoadingSubmodules = true;
    });

    try {
      final details = await _contentRepo.moduleDetails(widget.profileId, module.id);
      if (mounted) {
        setState(() {
          _selectedModule = details;
          _isLoadingSubmodules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nu am putut încărca submodulele';
          _isLoadingSubmodules = false;
        });
      }
    }
  }

  Future<void> _selectSubmodule(SubmoduleLite submodule) async {
    setState(() {
      _selectedSubmodule = submodule;
      _submoduleDetails = null;
      _selectedPartIds.clear();
      _isLoadingParts = true;
    });

    try {
      final details = await _contentRepo.submoduleWithParts(widget.profileId, submodule.id);
      if (mounted) {
        setState(() {
          _submoduleDetails = details;
          _isLoadingParts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nu am putut încărca părțile';
          _isLoadingParts = false;
        });
      }
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  Future<void> _assignHomework() async {
    // Validate selection
    if (_selectedModule == null && _selectedSubmodule == null && _selectedPartIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectează un modul, submodul sau cel puțin o parte')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notes = _notesController.text.isEmpty ? null : _notesController.text;
      
      // If parts are selected, create one homework per part
      if (_selectedPartIds.isNotEmpty) {
        int successCount = 0;
        for (final partId in _selectedPartIds) {
          await _homeworkApi.assignHomework(
            profileId: widget.profileId,
            partId: partId,
            dueDate: _dueDate,
            notes: notes,
          );
          successCount++;
        }
        
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount ${successCount == 1 ? 'temă a fost adăugată' : 'teme au fost adăugate'} cu succes')),
          );
        }
      } else {
        // No parts selected - assign at module or submodule level
        await _homeworkApi.assignHomework(
          profileId: widget.profileId,
          moduleId: _selectedSubmodule == null ? _selectedModule?.id : null,
          submoduleId: _selectedSubmodule?.id,
          dueDate: _dueDate,
          notes: notes,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tema a fost adăugată cu succes')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: ${e.toString()}')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adaugă temă',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Pentru: ${widget.profileName}',
                            style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoadingModules
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSelectionSection(cs),
                                const SizedBox(height: 24),
                                _buildDueDateSection(cs),
                                const SizedBox(height: 16),
                                _buildNotesSection(cs),
                              ],
                            ),
                          ),
              ),

              // Actions
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _isSaving ? null : _assignHomework,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_selectedPartIds.length > 1 
                            ? 'Adaugă ${_selectedPartIds.length} teme'
                            : 'Adaugă temă'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selectează conținut',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Module selection
        _buildDropdown<ModuleDto>(
          label: 'Modul',
          value: _selectedModule != null 
              ? _modules?.firstWhere((m) => m.id == _selectedModule!.id)
              : null,
          items: _modules ?? [],
          itemLabel: (m) => m.title,
          onChanged: (m) => m != null ? _selectModule(m) : null,
        ),
        const SizedBox(height: 12),

        // Submodule selection
        if (_selectedModule != null) ...[
          if (_isLoadingSubmodules)
            const Center(child: CircularProgressIndicator())
          else
            _buildDropdown<SubmoduleLite>(
              label: 'Submodul (opțional)',
              value: _selectedSubmodule,
              items: _selectedModule!.submodules,
              itemLabel: (s) => s.title,
              onChanged: (s) => s != null ? _selectSubmodule(s) : setState(() {
                _selectedSubmodule = null;
                _submoduleDetails = null;
                _selectedPartIds.clear();
              }),
            ),
        ],
        const SizedBox(height: 12),

        // Part selection (checklist)
        if (_selectedSubmodule != null) ...[
          if (_isLoadingParts)
            const Center(child: CircularProgressIndicator())
          else if (_submoduleDetails != null && _submoduleDetails!.parts.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Părți (opțional)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                // Select all / Deselect all buttons
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedPartIds.addAll(
                            _submoduleDetails!.parts.map((p) => p.id),
                          );
                        });
                      },
                      child: const Text('Toate', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedPartIds.clear();
                        });
                      },
                      child: const Text('Niciunul', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _submoduleDetails!.parts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final part = entry.value;
                  final isSelected = _selectedPartIds.contains(part.id);
                  final isLast = index == _submoduleDetails!.parts.length - 1;
                  
                  return Column(
                    children: [
                      CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedPartIds.add(part.id);
                            } else {
                              _selectedPartIds.remove(part.id);
                            }
                          });
                        },
                        title: Text(
                          part.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                        subtitle: part.totalLessons > 0
                            ? Text('${part.totalLessons} lecții')
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: index == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: isLast ? const Radius.circular(12) : Radius.zero,
                          ),
                        ),
                      ),
                      if (!isLast) Divider(height: 1, color: cs.outline.withOpacity(0.2)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],

        // Selection summary
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.assignment, color: cs.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getSelectionSummary(),
                  style: TextStyle(color: cs.onSurface),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('Selectează...', style: TextStyle(color: Colors.grey[500])),
        ),
        ...items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel(item)),
        )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDueDateSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Termen limită (opțional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDueDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  _dueDate != null
                      ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                      : 'Selectează data...',
                  style: TextStyle(
                    color: _dueDate != null ? cs.onSurface : cs.onSurface.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (opțional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Adaugă instrucțiuni sau note pentru copil...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  String _getSelectionSummary() {
    if (_selectedPartIds.isNotEmpty && _submoduleDetails != null) {
      final selectedParts = _submoduleDetails!.parts
          .where((p) => _selectedPartIds.contains(p.id))
          .map((p) => p.name)
          .toList();
      if (selectedParts.length == 1) {
        return 'Parte: ${selectedParts.first}';
      }
      return '${selectedParts.length} părți selectate:\n• ${selectedParts.join('\n• ')}';
    }
    if (_selectedSubmodule != null) {
      return 'Submodul: ${_selectedSubmodule!.title}';
    }
    if (_selectedModule != null) {
      return 'Modul: ${_selectedModule!.title}';
    }
    return 'Selectează un modul pentru a continua';
  }
}

