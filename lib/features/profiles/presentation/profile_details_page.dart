// lib/features/profiles/presentation/profile_details_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/state/active_profile.dart';
import '../models/profile_model.dart';
import '../profile_repository.dart';
import '../selected_profile_cubit.dart';
import 'profile_picker_sheet.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key, required this.profile});
  final ProfileCardDto profile;

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late final repo = ProfilesRepository(GetIt.I<DioClient>());
  late Future<List<LessonProgressDto>> _f;
  late Future<ProfileCardDto> _profileDetails;
  
  // Track expanded state for modules and submodules (collapsed by default)
  final Set<int> _expandedModules = <int>{};
  final Set<int> _expandedSubmodules = <int>{};

  @override
  void initState() {
    super.initState();
    _f = repo.lessonProgress(widget.profile.id);
    _profileDetails = repo.getProfileDetails(widget.profile.id);
  }

  Future<void> _selectThisProfile() async {
    context.read<SelectedProfileCubit>().set(widget.profile.id);
    await GetIt.I<SecureStore>().saveActiveProfileId(widget.profile.id);
    GetIt.I<DioClient>().setActiveProfile(widget.profile.id);
    await GetIt.I<ActiveProfileService>().set(widget.profile.id);
    
    if (!mounted) return;
    SnackBarUtils.showSuccess(context, 'Profil activ: ${widget.profile.name}');
    setState(() {});
  }

  Future<void> _pickAnotherProfile() async {
    final picked = await showModalBottomSheet<ProfileCardDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfilePickerSheet(),
    );
    if (picked != null && mounted) {
      _f = repo.lessonProgress(picked.id);
      _profileDetails = repo.getProfileDetails(picked.id);
      setState(() {});
    }
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Șterge profil',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF17406B),
          ),
        ),
        content: Text(
          'Sigur vrei să ștergi profilul "${widget.profile.name}"? Toate datele asociate acestui profil vor fi șterse permanent. Această acțiune nu poate fi anulată.',
          style: const TextStyle(color: Color(0xFF17406B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulează'),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA2233).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA2233),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Șterge'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await repo.delete(widget.profile.id);
        if (!mounted) return;
        
        // If this was the active profile, clear it
        final activeId = GetIt.I<ActiveProfileService>().id;
        if (activeId == widget.profile.id) {
          context.read<SelectedProfileCubit>().set(null);
          await GetIt.I<SecureStore>().saveActiveProfileId(null);
          GetIt.I<DioClient>().setActiveProfile(null);
          await GetIt.I<ActiveProfileService>().clear();
        }
        
        SnackBarUtils.showSuccess(context, 'Profil șters cu succes');
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        SnackBarUtils.showError(context, 'Eroare la ștergere: $e');
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    
    // Romanian month names
    const romanianMonths = [
      'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
      'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
    ];
    
    final day = date.day;
    final month = romanianMonths[date.month - 1];
    final year = date.year;
    
    return '$day $month $year';
  }

  String _getGenderLabel(String? gender) {
    if (gender == null) return '—';
    final lowerGender = gender.toLowerCase();
    if (lowerGender == 'male' || lowerGender == 'm' || lowerGender == 'masculin') {
      return 'Băiat';
    } else if (lowerGender == 'female' || lowerGender == 'f' || lowerGender == 'feminin') {
      return 'Fată';
    } else if (lowerGender == 'other' || lowerGender == 'o' || lowerGender == 'altul') {
      return 'Altul';
    }
    return gender;
  }

  @override
  Widget build(BuildContext context) {
    final activeId = context.watch<SelectedProfileCubit>().state;
    final isActive = activeId == widget.profile.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              widget.profile.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17406B),
              ),
            ),
        actions: [
          if (!isActive)
            TextButton(
              onPressed: _selectThisProfile,
                  child: const Text(
                    'Setează activ',
                    style: TextStyle(
                      color: Color(0xFFEA2233),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Activ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
                  ),
                ),
            ],
          ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: FutureBuilder<ProfileCardDto>(
            future: _profileDetails,
            builder: (context, profileSnapshot) {
              return FutureBuilder<List<LessonProgressDto>>(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                      ),
                    );
                  }
                  
                  final profile = profileSnapshot.data ?? widget.profile;
                  final items = s.data!;

          return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // Profile Info Card
                      Container(
                        padding: const EdgeInsets.all(24),
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
                          children: [
                            // Avatar
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEA2233), Color(0xFF2D72D2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEA2233).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: ClipOval(
                                    child: (profile.avatarUri != null &&
                                            profile.avatarUri!.isNotEmpty)
                                        ? Image.network(
                                            profile.avatarUri!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.person_rounded,
                                              color: const Color(0xFFEA2233),
                                              size: 50,
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_rounded,
                                            color: const Color(0xFFEA2233),
                                            size: 50,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF17406B),
                              ),
                            ),
                            if (profile.premium)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA2233).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFEA2233).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, size: 16, color: const Color(0xFFEA2233)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          color: const Color(0xFFEA2233),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            // Details
                            Builder(
                              builder: (context) {
                                // Debug logging
                                print('🎨 Profile details page - birthDate: ${profile.birthDate}, gender: ${profile.gender}');
                                return const SizedBox.shrink();
                              },
                            ),
                            if (profile.birthDate != null || profile.gender != null || profile.age != null) ...[
                              if (profile.birthDate != null)
                                _DetailRow(
                                  icon: Icons.cake_outlined,
                                  iconColor: const Color(0xFF2D72D2),
                                  label: 'Zi de naștere',
                                  value: _formatDate(profile.birthDate!),
                                ),
                              if (profile.birthDate != null && (profile.gender != null || profile.age != null))
                                const SizedBox(height: 16),
                              if (profile.gender != null)
                                _DetailRow(
                                  icon: Icons.person_outline_rounded,
                                  iconColor: const Color(0xFF2D72D2),
                                  label: 'Gen',
                                  value: _getGenderLabel(profile.gender),
                                ),
                              if (profile.gender != null && profile.age != null)
                                const SizedBox(height: 16),
                              if (profile.age != null)
                                _DetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  iconColor: const Color(0xFFEA2233),
                                  label: 'Vârstă',
                                  value: '${profile.age} ani',
                                ),
                              const SizedBox(height: 24),
                            ],
                            // Progress
                            LinearProgressIndicator(
                              value: (profile.totalLessons == 0)
                                  ? 0
                                  : (profile.completedLessons / profile.totalLessons),
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 10,
                              backgroundColor: const Color(0xFFEA2233).withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFEA2233),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${profile.progressPercent}% complet (${profile.completedLessons}/${profile.totalLessons} lecții)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Delete Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: _deleteProfile,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Șterge profil'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lessons Progress
                      if (items.isNotEmpty) ...[
                        Container(
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
                              Text(
                                'Progres lecții',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF17406B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._buildModulesList(items),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
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
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'Nu există lecții',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D72D2).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _pickAnotherProfile,
          backgroundColor: const Color(0xFF2D72D2),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text(
            'Schimbă profilul',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'DONE':
        return Icon(Icons.check_circle_rounded, color: const Color(0xFFEA2233), size: 24);
      case 'UNLOCKED':
        return Icon(Icons.radio_button_unchecked, color: const Color(0xFF2D72D2), size: 24);
      default:
        return Icon(Icons.lock_outline_rounded, color: Colors.grey[400], size: 24);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DONE':
        return const Color(0xFFEA2233);
      case 'UNLOCKED':
        return const Color(0xFF2D72D2);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'DONE':
        return 'Complet';
      case 'UNLOCKED':
        return 'Disponibil';
      default:
        return 'Blocat';
    }
  }

  List<Widget> _buildModulesList(List<LessonProgressDto> items) {
    // First group by module, then by submodule
    final Map<int, Map<int, List<LessonProgressDto>>> modulesMap = {};
    
    for (final item in items) {
      modulesMap.putIfAbsent(item.moduleId, () => {});
      modulesMap[item.moduleId]!.putIfAbsent(item.submoduleId, () => []);
      modulesMap[item.moduleId]![item.submoduleId]!.add(item);
    }

    return modulesMap.entries.map((moduleEntry) {
      final moduleId = moduleEntry.key;
      final moduleData = moduleEntry.value;
      final firstItem = moduleData.values.first.first;
      final moduleTitle = firstItem.moduleTitle;
      final isModuleExpanded = _expandedModules.contains(moduleId);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF3F5F8),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Module header (clickable)
            InkWell(
              onTap: () {
                setState(() {
                  if (isModuleExpanded) {
                    _expandedModules.remove(moduleId);
                  } else {
                    _expandedModules.add(moduleId);
                  }
                });
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isModuleExpanded ? Icons.expand_more : Icons.chevron_right,
                      color: const Color(0xFF17406B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        moduleTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF17406B),
                        ),
                      ),
                    ),
                    Text(
                      '${moduleData.length} submodule${moduleData.length != 1 ? '' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Submodules (shown when module is expanded)
            if (isModuleExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: moduleData.entries.map((submoduleEntry) {
                    final submoduleId = submoduleEntry.key;
                    final submoduleItems = submoduleEntry.value;
                    final firstSubmoduleItem = submoduleItems.first;
                    final submoduleTitle = firstSubmoduleItem.submoduleTitle;
                    final isSubmoduleExpanded = _expandedSubmodules.contains(submoduleId);

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Submodule header (clickable)
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isSubmoduleExpanded) {
                                  _expandedSubmodules.remove(submoduleId);
                                } else {
                                  _expandedSubmodules.add(submoduleId);
                                }
                              });
                            },
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    isSubmoduleExpanded ? Icons.expand_more : Icons.chevron_right,
                                    color: const Color(0xFF17406B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      submoduleTitle,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF17406B),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${submoduleItems.length} lecții',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Lessons (shown when submodule is expanded)
                          if (isSubmoduleExpanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                              child: Column(
                                children: submoduleItems.map((l) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      _statusIcon(l.status),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.lessonTitle,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF17406B),
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${l.moduleTitle} • Lecția ${l.lessonId}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(l.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusLabel(l.status),
                                          style: TextStyle(
                                            color: _getStatusColor(l.status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF17406B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper extension for grouping
extension ListExtension<T> on List<T> {
  Map<K, List<T>> groupBy<K>(K Function(T) keyFunction) {
    final map = <K, List<T>>{};
    for (final item in this) {
      final key = keyFunction(item);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}