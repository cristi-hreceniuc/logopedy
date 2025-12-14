// lib/features/home/tabs/profiles_tab.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/image_upload_service.dart';
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
    DateTime? selectedBirthday;
    String? selectedGender;
    File? selectedImage;
    bool isUploadingImage = false;
    final formKey = GlobalKey<FormState>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final titleColor = isDark ? Colors.white : const Color(0xFF17406B);
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cs.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Profil nou',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Adaugă un profil nou pentru copilul tău',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Form card
                      Card(
                        color: cs.surface,
                        elevation: 0.5,
                        shadowColor: cs.shadow.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Name field
                              TextFormField(
                                controller: nameCtrl,
                                style: TextStyle(fontSize: 16, color: cs.onSurface),
                                decoration: InputDecoration(
                                  labelText: 'Nume profil',
                                  labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                                  floatingLabelStyle: TextStyle(color: cs.primary, fontSize: 14),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.error),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.error, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: cs.surfaceContainerLowest,
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoriu' : null,
                              ),
                              const SizedBox(height: 14),
                              // Birthday field
                              GestureDetector(
                                onTap: () => _showDatePicker(ctx, selectedBirthday, (date) {
                                  setModalState(() {
                                    selectedBirthday = date;
                                  });
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Data nașterii',
                                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              selectedBirthday != null
                                                  ? DateFormat('dd/MM/yyyy').format(selectedBirthday!)
                                                  : 'Selectează',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: selectedBirthday != null ? cs.onSurface : cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.calendar_today_rounded, color: cs.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Gender field
                              GestureDetector(
                                onTap: () => _showGenderPicker(ctx, selectedGender, (value) {
                                  setModalState(() {
                                    selectedGender = value;
                                  });
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Gen',
                                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              selectedGender != null
                                                  ? (selectedGender == 'MALE' ? 'Masculin' : 'Feminin')
                                                  : 'Selectează',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: selectedGender != null ? cs.onSurface : cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Avatar selection
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.outline.withOpacity(0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.photo_camera_rounded, color: cs.onSurfaceVariant, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Avatar (opțional)',
                                          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (selectedImage != null) ...[
                                      Center(
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                selectedImage!,
                                                height: 100,
                                                width: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setModalState(() {
                                                    selectedImage = null;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: cs.error,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.close, color: cs.onError, size: 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              final ImagePicker picker = ImagePicker();
                                              final XFile? image = await picker.pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 1024,
                                                maxHeight: 1024,
                                                imageQuality: 85,
                                              );
                                              if (image != null) {
                                                setModalState(() {
                                                  selectedImage = File(image.path);
                                                });
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: cs.primary,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.photo_library_outlined, size: 18, color: cs.primary),
                                                const SizedBox(width: 6),
                                                Text('Galerie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: cs.outline.withOpacity(0.3),
                                        ),
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              final ImagePicker picker = ImagePicker();
                                              final XFile? image = await picker.pickImage(
                                                source: ImageSource.camera,
                                                maxWidth: 1024,
                                                maxHeight: 1024,
                                                imageQuality: 85,
                                              );
                                              if (image != null) {
                                                setModalState(() {
                                                  selectedImage = File(image.path);
                                                });
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: cs.primary,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.camera_alt_outlined, size: 18, color: cs.primary),
                                                const SizedBox(width: 6),
                                                Text('Cameră', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Submit button
                              FilledButton(
                                onPressed: isUploadingImage ? null : () async {
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
                                  
                                  // Upload image first if selected
                                  if (selectedImage != null) {
                                    setModalState(() {
                                      isUploadingImage = true;
                                    });
                                    
                                    try {
                                      final name = nameCtrl.text.trim();
                                      final tempProfile = await repo.create(
                                        name: name,
                                        avatarUri: null,
                                        birthDate: selectedBirthday!,
                                        gender: selectedGender!,
                                      );
                                      
                                      final imageUploadService = ImageUploadService(GetIt.I<DioClient>());
                                      await imageUploadService.uploadProfileAvatar(
                                        tempProfile.id,
                                        selectedImage!,
                                      );
                                      
                                      setModalState(() {
                                        isUploadingImage = false;
                                      });
                                      
                                      if (!mounted) return;
                                      Navigator.pop(ctx);
                                      SnackBarUtils.showSuccess(context, 'Profil creat cu avatar');
                                      
                                      await _refresh();
                                      
                                      final activeProfileId = GetIt.I<ActiveProfileService>().id;
                                      final profiles = await repo.list();
                                      final isOnlyProfile = profiles.length == 1;
                                      final shouldSetAsActive = activeProfileId == null || _wasAutoOpened || isOnlyProfile;
                                      
                                      if (shouldSetAsActive && mounted) {
                                        context.read<SelectedProfileCubit>().set(tempProfile.id);
                                        await GetIt.I<SecureStore>().saveActiveProfileId(tempProfile.id);
                                        GetIt.I<DioClient>().setActiveProfile(tempProfile.id);
                                        await GetIt.I<ActiveProfileService>().set(tempProfile.id);
                                      }
                                      _wasAutoOpened = false;
                                      return;
                                      
                                    } catch (e) {
                                      setModalState(() {
                                        isUploadingImage = false;
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Eroare la încărcarea imaginii: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  
                                  // Create profile without image
                                  final name = nameCtrl.text.trim();
                                  final createdProfile = await repo.create(
                                    name: name,
                                    avatarUri: null,
                                    birthDate: selectedBirthday!,
                                    gender: selectedGender!,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  SnackBarUtils.showSuccess(context, 'Profil creat');
                                  
                                  await _refresh();
                                  
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
                                  _wasAutoOpened = false;
                                },
                                child: isUploadingImage
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Creează'),
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
          },
        );
      },
    );
  }

  void _showGenderPicker(BuildContext context, String? currentGender, Function(String) onSelect) {
    final cs = Theme.of(context).colorScheme;
    final genders = ['MALE', 'FEMALE'];
    final genderLabels = ['Masculin', 'Feminin'];
    int selectedIndex = currentGender == 'FEMALE' ? 1 : 0;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header with title and buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Anulează',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Gen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onSelect(genders[selectedIndex]);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Gata',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Gender wheel picker
              SizedBox(
                height: 150,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                        fontSize: 20,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      selectedIndex = index;
                    },
                    children: genderLabels.map((label) => Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, DateTime? currentDate, Function(DateTime) onSelect) {
    final cs = Theme.of(context).colorScheme;
    DateTime tempDate = currentDate ?? DateTime.now().subtract(const Duration(days: 365 * 5));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header with title and buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Anulează',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Data nașterii',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onSelect(tempDate);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Gata',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Date picker
              SizedBox(
                height: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 20,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempDate,
                    maximumDate: DateTime.now(),
                    minimumDate: DateTime(1900),
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateSheet,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 2,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Profil nou',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
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
                            child: ClipOval(
                              child: p.avatarUri != null && p.avatarUri!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: p.avatarUri!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) {
                                        return Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              const Color(0xFFEA2233),
                                            ),
                                          ),
                                        );
                                      },
                                      errorWidget: (context, url, error) {
                                        return Center(
                                          child: Text(
                                            _getProfileInitials(p.name),
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFEA2233),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
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
