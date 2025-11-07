// lib/features/home/tabs/profiles_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/state/active_profile.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../profiles/models/profile_model.dart';
import '../../profiles/presentation/profile_details_page.dart';
import '../../profiles/profile_repository.dart';
import '../../profiles/selected_profile_cubit.dart';

class ProfilesTab extends StatefulWidget {
  const ProfilesTab({super.key, this.shouldOpenCreateDialog = false});
  
  final bool shouldOpenCreateDialog;

  @override
  State<ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<ProfilesTab> {
  late final repo = ProfilesRepository(GetIt.I<DioClient>());
  late Future<List<ProfileCardDto>> _f;
  bool _hasCheckedForEmptyProfiles = false;
  bool _wasAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _f = repo.list();
    // Check if we need to auto-open create dialog
    // Use multiple post-frame callbacks to ensure the widget is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for the next frame to ensure the widget is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndOpenCreateDialog();
      });
    });
  }

  @override
  void didUpdateWidget(ProfilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If shouldOpenCreateDialog changed to true, check again
    if (widget.shouldOpenCreateDialog && !oldWidget.shouldOpenCreateDialog) {
      _hasCheckedForEmptyProfiles = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndOpenCreateDialog();
        });
      });
    }
  }

  Future<void> _checkAndOpenCreateDialog() async {
    if (_hasCheckedForEmptyProfiles) return;
    _hasCheckedForEmptyProfiles = true;
    
    try {
      final profiles = await _f;
      final activeProfileId = GetIt.I<ActiveProfileService>().id;
      
      // If shouldOpenCreateDialog is true (after onboarding) or if no profiles exist, automatically open create dialog
      final shouldOpen = widget.shouldOpenCreateDialog || (profiles.isEmpty && activeProfileId == null);
      
      debugPrint('ProfilesTab: shouldOpenCreateDialog=${widget.shouldOpenCreateDialog}, profiles.isEmpty=${profiles.isEmpty}, activeProfileId=$activeProfileId, shouldOpen=$shouldOpen');
      
      if (shouldOpen && mounted) {
        // Wait a bit for the UI to be ready, especially after onboarding
        await Future.delayed(Duration(milliseconds: widget.shouldOpenCreateDialog ? 1200 : 500));
        if (mounted) {
          debugPrint('ProfilesTab: Opening create profile dialog');
          _wasAutoOpened = true; // Track that dialog was auto-opened
          _showCreateSheet();
        } else {
          debugPrint('ProfilesTab: Widget not mounted, skipping dialog');
        }
      } else {
        debugPrint('ProfilesTab: Not opening dialog - shouldOpen=$shouldOpen, mounted=$mounted');
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking for empty profiles: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _refresh() async {
    setState(() { _f = repo.list(); });
    await _f;
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final avatarCtrl = TextEditingController();
    DateTime? selectedBirthday;
    String? selectedGender;
    final formKey = GlobalKey<FormState>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Text(
                        'Profil nou',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17406B),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nume profil',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoriu' : null,
                      ),
                      const SizedBox(height: 16),
                      // Birthday field
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFEA2233),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedBirthday = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data nașterii',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            selectedBirthday != null
                                ? DateFormat('dd/MM/yyyy').format(selectedBirthday!)
                                : 'Selectează data nașterii',
                            style: TextStyle(
                              color: selectedBirthday != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      if (selectedBirthday == null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            'Obligatoriu',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Gender field
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gen',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Masculin')),
                          DropdownMenuItem(value: 'FEMALE', child: Text('Feminin')),
                        ],
                        onChanged: (v) {
                          setModalState(() {
                            selectedGender = v;
                          });
                        },
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatoriu' : null,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: avatarCtrl,
                        decoration: InputDecoration(
                          labelText: 'Avatar URL (opțional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA2233).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              if (selectedBirthday == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Te rugăm să selectezi data nașterii'),
                                    backgroundColor: Color(0xFFEA2233),
                                  ),
                                );
                                return;
                              }
                              if (selectedGender == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Te rugăm să selectezi genul'),
                                    backgroundColor: Color(0xFFEA2233),
                                  ),
                                );
                                return;
                              }
                              
                              final name = nameCtrl.text.trim();
                              final createdProfile = await repo.create(
                                name: name,
                                avatarUri: avatarCtrl.text.trim().isEmpty
                                    ? null
                                    : avatarCtrl.text.trim(),
                                birthDate: selectedBirthday!,
                                gender: selectedGender!,
                              );
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              SnackBarUtils.showSuccess(context, 'Profil creat');
                              
                              // Refresh to get updated profile list
                              await _refresh();
                              
                              // Automatically select the newly created profile if:
                              // 1. No active profile exists, OR
                              // 2. This profile was created from the auto-opened dialog (after onboarding/welcome page), OR
                              // 3. This is the only profile (first profile created)
                              final activeProfileId = GetIt.I<ActiveProfileService>().id;
                              final profiles = await repo.list();
                              final isOnlyProfile = profiles.length == 1;
                              final shouldSetAsActive = activeProfileId == null || _wasAutoOpened || isOnlyProfile;
                              
                              if (shouldSetAsActive && mounted) {
                                context.read<SelectedProfileCubit>().set(createdProfile.id);
                                await GetIt.I<SecureStore>().saveActiveProfileId(createdProfile.id);
                                GetIt.I<DioClient>().setActiveProfile(createdProfile.id);
                                await GetIt.I<ActiveProfileService>().set(createdProfile.id);
                              }
                              // Reset the flag after creating the profile
                              _wasAutoOpened = false;
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Creează'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
        body: ListenableBuilder(
          listenable: GetIt.I<ActiveProfileService>(),
          builder: (context, child) {
            return FutureBuilder<List<ProfileCardDto>>(
              future: _f,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                      ),
                    );
                }
                final items = s.data ?? [];
                if (items.isEmpty) {
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
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D72D2).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group_outlined,
                                size: 56,
                                color: const Color(0xFF2D72D2),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Nu ai încă profile',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF17406B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Adaugă un profil nou folosind butonul de mai jos.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                    color: const Color(0xFFEA2233),
                  child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final p = items[i];
                      return _ProfileCard(
                        p: p,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProfileDetailsPage(profile: p)),
                          );
                          // If profile was deleted (result is true), refresh the list
                          if (result == true && mounted) {
                            await _refresh();
                          }
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA2233).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _showCreateSheet,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Profil nou',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.p, required this.onTap});
  final ProfileCardDto p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeProfileId = GetIt.I<ActiveProfileService>().id;
    final isActive = p.id == activeProfileId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
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
      child: Stack(
        children: [
              Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                children: [
                    // Premium badge
                  Align(
                    alignment: Alignment.topRight,
                    child: p.premium
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA2233).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                color: const Color(0xFFEA2233),
                                size: 16,
                              ),
                            )
                          : const SizedBox(height: 24, width: 24),
                    ),
                    const SizedBox(height: 2),
                    // Avatar
              Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEA2233),
                                  const Color(0xFF2D72D2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEA2233).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Center(
                              child: Text(
                                _getProfileInitials(p.name),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA2233),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                ],
              ),
            ),
                    const SizedBox(height: 6),
                    // Name
                    Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF17406B),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Additional info - Gender icon + Birthday date (moved up)
                    Builder(
                      builder: (context) {
                        // Debug logging
                        if (p.birthDate != null || p.gender != null) {
                          print('🎨 Profile card "${p.name}" - birthDate: ${p.birthDate}, gender: ${p.gender}');
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (p.birthDate != null || p.gender != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Gender icon (boy or girl)
                          if (p.gender != null) ...[
                            _getGenderIcon(p.gender!),
                            const SizedBox(width: 8),
                          ],
                          // Birthday date only (no label)
                          if (p.birthDate != null)
                            Flexible(
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(p.birthDate!),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 6),
                    // Progress
                    LinearProgressIndicator(
                      value: (p.totalLessons == 0)
                          ? 0
                          : (p.completedLessons / p.totalLessons),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEA2233).withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFEA2233),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.progressPercent}% complet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Active badge
              if (isActive)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA2233).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Activ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }
}

String _getProfileInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty) return 'P';
  if (parts.length == 1) {
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'P';
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

String _getGenderLabel(String gender) {
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

Widget _getGenderIcon(String gender) {
  final lowerGender = gender.toLowerCase();
  if (lowerGender == 'male' || lowerGender == 'm' || lowerGender == 'masculin') {
    // Boy icon - using child_care icon with blue styling
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF2D72D2).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.child_care,
        size: 16,
        color: const Color(0xFF2D72D2),
      ),
    );
  } else if (lowerGender == 'female' || lowerGender == 'f' || lowerGender == 'feminin') {
    // Girl icon - using face icon with pink/red styling
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEA2233).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.face,
        size: 16,
        color: const Color(0xFFEA2233),
      ),
    );
  }
  // Default icon for other genders
  return Icon(
    Icons.person_outline,
    size: 16,
    color: Colors.grey[600],
  );
}
