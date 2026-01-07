import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../widgets/profile_avatar.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../auth/data/domain/auth_repository.dart';
import '../../auth/data/models/user_response_dto.dart';
import '../../session/session_info.dart';
import '../../theme/theme_cubit.dart';
import '../../../widgets/app_version.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  bool _isUploadingImage = false;

  Future<void> _uploadProfileImage(File imageFile, UserResponseDto? user) async {
    if (user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Clear the old cached image first
      if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(user.profileImageUrl!);
        debugPrint('🗑️ Cleared cache for old profile image: ${user.profileImageUrl}');
      }

      final imageUploadService = ImageUploadService(GetIt.I<DioClient>());
      final s3Key = await imageUploadService.uploadUserProfileImage(imageFile);

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Imaginea de profil a fost încărcată cu succes');
        // Trigger a rebuild by refreshing the user data
        setState(() {
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        SnackBarUtils.showError(context, 'Eroare la încărcarea imaginii: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = GetIt.I<AuthRepository>();

    return SafeArea(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<UserResponseDto?>(
          future: repo.getCurrentUser().then<UserResponseDto?>((user) => user).catchError((e) {
            debugPrint('Error fetching user: $e');
            return null;
          }),
          builder: (context, userSnap) {
            final user = userSnap.data;
            final isLoadingUser = !userSnap.hasData;

            return FutureBuilder<SessionInfo?>(
        future: SessionInfo.fromStorage(),
              builder: (context, sessionSnap) {
                final sessionInfo = sessionSnap.data;

                if (isLoadingUser) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA2233)),
                    ),
                  );
                }

                // Use API data if available, fallback to session info
                final displayUser = user ?? _mapSessionToUser(sessionInfo);

          return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      // Header Section with Avatar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Avatar with upload functionality
                            _isUploadingImage
                                ? const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFEA2233),
                                        ),
                                      ),
                                    ),
                                  )
                                : ProfileAvatar(
                                    imageUrl: displayUser?.profileImageUrl,
                                    initials: _getInitials(displayUser),
                                    size: 80,
                                    showEditButton: true,
                                    onImageSelected: (file) => _uploadProfileImage(file, displayUser),
                                  ),
                            const SizedBox(height: 12),
                          // Name
                          Text(
                            _getDisplayName(displayUser),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Email
                          if (displayUser?.email != null && displayUser!.email.isNotEmpty)
                            Text(
                              displayUser.email,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (displayUser?.isPremium == true) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA2233).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFEA2233).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
            children: [
                                  Icon(Icons.star_rounded, size: 14, color: const Color(0xFFEA2233)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: const Color(0xFFEA2233),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (displayUser?.isPremium ?? false)
                                  ? const Color(0xFFEA2233).withOpacity(0.1)
                                  : const Color(0xFF2D72D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              (displayUser?.isPremium ?? false) ? Icons.star_rounded : Icons.person_outline_rounded,
                              size: 22,
                              color: (displayUser?.isPremium ?? false) ? const Color(0xFFEA2233) : const Color(0xFF2D72D2),
                            ),
                          ),
                          const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                                  'Status cont',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                        ),
                        const SizedBox(height: 2),
                                Text(
                                  (displayUser?.isPremium ?? false) ? 'Premium' : 'Standard',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: (displayUser?.isPremium ?? false) ? const Color(0xFFEA2233) : const Color(0xFF2D72D2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (displayUser?.isPremium == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
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
                ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Account Details Card (Collapsible)
                    _CollapsibleSection(
                      title: 'Detalii cont',
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF2D72D2),
                      initiallyExpanded: false,
                      children: [
                        if (displayUser?.firstName != null && displayUser!.firstName!.isNotEmpty)
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            iconColor: const Color(0xFF2D72D2),
                            label: 'Prenume',
                            value: displayUser.firstName!,
                          ),
                        if (displayUser?.firstName != null && displayUser!.firstName!.isNotEmpty)
                          const SizedBox(height: 10),
                        if (displayUser?.lastName != null && displayUser!.lastName!.isNotEmpty)
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            iconColor: const Color(0xFF2D72D2),
                            label: 'Nume',
                            value: displayUser.lastName!,
                          ),
                        if (displayUser?.lastName != null && displayUser!.lastName!.isNotEmpty)
                          const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.email_outlined,
                          iconColor: const Color(0xFF2D72D2),
                          label: 'Email',
                          value: displayUser?.email ?? '—',
                        ),
                        if (displayUser?.gender != null && displayUser!.gender!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.wc_rounded,
                            iconColor: const Color(0xFFEA2233),
                            label: 'Gen',
                            value: _getGenderLabel(displayUser.gender!),
                          ),
                        ],
                        if (displayUser?.createdAt != null) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            iconColor: const Color(0xFF2D72D2),
                            label: 'Data înregistrării',
                            value: _formatDate(displayUser!.createdAt),
                          ),
                        ],
                        if (displayUser?.role != null && displayUser!.role!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.verified_user_outlined,
                            iconColor: const Color(0xFFEA2233),
                            label: 'Rol',
                            value: _capitalizeFirst(displayUser.role!),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Tip of the Day Card
                    const _TipOfTheDayCard(),

              const SizedBox(height: 16),

              // App Settings Section
              _SettingsSection(
                title: 'Aspect',
                children: [
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, themeMode) {
                      final isDark = themeMode == ThemeMode.dark;
                      return _SettingsTile(
                        icon: Icons.dark_mode_outlined,
                        iconColor: const Color(0xFF2D72D2),
                        title: 'Mod întunecat',
                        trailing: Switch(
                          value: isDark,
                          onChanged: (value) {
                            context.read<ThemeCubit>().set(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                          },
                          activeThumbColor: const Color(0xFFEA2233),
                          activeTrackColor: const Color(0xFFEA2233).withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Legal & Information Section (Collapsible, collapsed by default)
              _CollapsibleSettingsSection(
                title: 'Informații și Legal',
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFF2D72D2),
                initiallyExpanded: false,
                children: [
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF2D72D2),
                    title: 'Termeni și condiții',
                    onTap: () => _showTermsAndConditions(context),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF2D72D2),
                    title: 'Despre aplicație',
                    onTap: () => _showAbout(context),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF2D72D2),
                    title: 'Întrebări frecvente (FAQ)',
                    onTap: () => _showFAQ(context),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_outlined,
                    iconColor: const Color(0xFF2D72D2),
                    title: 'Ajutor',
                    onTap: () => _showHelp(context),
                  ),
                  _SettingsTile(
                    icon: Icons.cookie_outlined,
                    iconColor: const Color(0xFFEA2233),
                    title: 'Cookie-uri',
                    onTap: () => _showCookies(context),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: const Color(0xFFEA2233),
                    title: 'Declarație de confidențialitate',
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, st) {
                    return Container(
                      child: OutlinedButton(
                        onPressed: st.loading
                            ? null
                            : () => _deleteAccount(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                            const SizedBox(width: 8),
                            Text(
                              'Șterge contul',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: cs.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, st) {
                    return FilledButton(
                      onPressed: st.loading
                          ? null
                          : () => context.read<AuthCubit>().logout(),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          st.loading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                                  ),
                                )
                              : Icon(Icons.logout_rounded, size: 18, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            st.loading ? 'Se deconectează...' : 'Deconectează-te',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                },
              ),
              const SizedBox(height: 16),
              // App Version in bottom-right corner
              Align(
                alignment: Alignment.centerRight,
                child: AppVersion(
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
              );
            },
          ),
        ),
      );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Step 1: Show initial confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Șterge cont',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF17406B),
          ),
        ),
        content: const Text(
          'Sigur vrei să ștergi contul? Vei primi un cod de verificare pe email pentru a confirma ștergerea. Toate datele tale vor fi șterse permanent. Această acțiune nu poate fi anulată.',
          style: TextStyle(color: Color(0xFF17406B)),
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
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continuă'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Step 2: Request OTP - use repository directly to avoid state changes
    final repo = GetIt.I<AuthRepository>();
    final sessionInfo = await SessionInfo.fromStorage();
    final email = sessionInfo?.email;
    
    if (email == null || email.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Nu s-a putut obține email-ul contului.');
      }
      return;
    }
    
    try {
      await repo.requestDeleteAccountOtp(email);
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Nu s-a putut trimite codul de verificare: $e');
      }
      return;
    }
    
    if (!context.mounted) return;
    
    // Show info that OTP was sent
    SnackBarUtils.showSuccess(context, 'Codul de verificare a fost trimis pe email.');

    // Step 3: Show OTP input dialog
    final otp = await _showOtpInputDialog(context);
    
    if (otp == null || otp.isEmpty || !context.mounted) return;

    // Step 4: Confirm deletion with OTP
    try {
      await repo.confirmDeleteAccount(email: email, otp: otp);
      
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Cont șters cu succes');
        // Clear onboarding status
        await GetIt.I<SecureStore>().deleteKey('onboarding_completed');
        // Trigger logout to update UI state
        context.read<AuthCubit>().logout();
        }
      } catch (e) {
        if (context.mounted) {
        // Extract error message from exception
        String errorMsg = 'Eroare la ștergerea contului';
        if (e.toString().contains('Cod invalid')) {
          errorMsg = 'Cod invalid. Te rog verifică și încearcă din nou.';
        } else if (e.toString().contains('expirat')) {
          errorMsg = 'Codul a expirat. Te rog solicită un cod nou.';
        } else if (e.toString().contains('Prea multe încercări')) {
          errorMsg = 'Prea multe încercări. Te rog așteaptă și încearcă din nou.';
        }
        SnackBarUtils.showError(context, errorMsg);
      }
    }
  }

  Future<String?> _showOtpInputDialog(BuildContext context) async {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verificare cod',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17406B),
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Am trimis un cod de 6 cifre pe adresa ta de email. Introdu codul pentru a confirma ștergerea contului.',
                  style: TextStyle(
                    color: Color(0xFF17406B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Introdu codul de verificare';
                    }
                    if (value.length != 6) {
                      return 'Codul trebuie să aibă 6 cifre';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Codul trebuie să conțină doar cifre';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Această acțiune este ireversibilă!',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Anulează'),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, otpController.text);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Șterge contul'),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper to map SessionInfo to UserResponseDto-like structure for fallback
  UserResponseDto? _mapSessionToUser(SessionInfo? info) {
    if (info == null) return null;
    return UserResponseDto(
      id: info.userId?.toString() ?? '',
      firstName: info.firstName,
      lastName: info.lastName,
      email: info.email ?? '',
      gender: info.gender,
      isPremium: info.isPremium,
    );
  }

  String _getDisplayName(UserResponseDto? user) {
    if (user?.firstName != null && user?.lastName != null) {
      return '${user!.firstName} ${user.lastName}';
    } else if (user?.firstName != null) {
      return user!.firstName!;
    } else if (user?.lastName != null) {
      return user!.lastName!;
    } else if (user?.email != null && user!.email.isNotEmpty) {
      return user.email.split('@').first;
  }
  return 'Utilizator';
}

  String _getInitials(UserResponseDto? user) {
    if (user?.firstName != null && user?.lastName != null) {
      return '${user!.firstName![0]}${user.lastName![0]}'.toUpperCase();
    } else if (user?.firstName != null && user!.firstName!.isNotEmpty) {
      return user.firstName![0].toUpperCase();
    } else if (user?.lastName != null && user!.lastName!.isNotEmpty) {
      return user.lastName![0].toUpperCase();
    } else if (user?.email != null && user!.email.isNotEmpty) {
      return user.email[0].toUpperCase();
    }
    return 'A';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    try {
      final dateFormat = DateFormat('dd MMMM yyyy', 'ro_RO');
      return dateFormat.format(date);
    } catch (e) {
      final dateFormat = DateFormat('dd MMMM yyyy');
      return dateFormat.format(date);
    }
  }

String _getGenderLabel(String gender) {
  final lowerGender = gender.toLowerCase();
  if (lowerGender == 'male' || lowerGender == 'm' || lowerGender == 'masculin') {
    return 'Masculin';
  } else if (lowerGender == 'female' || lowerGender == 'f' || lowerGender == 'feminin') {
    return 'Feminin';
  } else if (lowerGender == 'other' || lowerGender == 'o' || lowerGender == 'altul') {
    return 'Altul';
  }
  return gender;
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _showTermsAndConditions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Termeni și condiții',
        content: _termsAndConditionsContent,
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Despre aplicație',
        content: _aboutContent,
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FAQBottomSheet(),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Ajutor',
        content: _helpContent,
      ),
    );
  }

  void _showCookies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Politica Cookie-uri',
        content: _cookiesContent,
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Declarație de confidențialitate',
        content: _privacyContent,
      ),
    );
  }

  static const String _termsAndConditionsContent = '''
TERMENI ȘI CONDIȚII DE UTILIZARE

1. ACCEPTAREA TERMENILOR
Prin accesarea și utilizarea aplicației Logopedy, acceptați acești termeni și condiții în totalitate. Dacă nu sunteți de acord cu oricare dintre acești termeni, vă rugăm să nu utilizați aplicația.

2. DESCRIEREA SERVICIULUI
Aplicația Logopedy oferă servicii de terapie logopedică prin intermediul unor exerciții interactive și conținut educațional adaptat pentru utilizatori.

3. CONTUL UTILIZATORULUI
Sunteți responsabil pentru menținerea confidențialității contului dvs. și pentru toate activitățile care au loc sub contul dvs.

4. UTILIZAREA APLICAȚIEI
Aplicația este destinată utilizării personale și educaționale. Nu puteți:
- Copia sau distribui conținutul aplicației
- Utiliza aplicația în scopuri comerciale fără autorizație
- Încerca să accesați zone restricționate ale aplicației

5. PROPRETATEA INTELECTUALĂ
Toate drepturile de proprietate intelectuală asupra aplicației și conținutului acesteia aparțin Logopedy.

6. LIMITAREA RĂSPUNDERII
Aplicația este furnizată "așa cum este" fără garanții. Nu ne asumăm răspundere pentru eventualele daune rezultate din utilizarea aplicației.

7. MODIFICĂRI
Ne rezervăm dreptul de a modifica acești termeni în orice moment. Continuarea utilizării aplicației după modificări constituie acceptarea noilor termeni.
''';

  static const String _aboutContent = '''
DESPRE APLICAȚIA LOGOPEDY

Logopedy este o aplicație modernă și intuitivă concepută pentru a sprijini terapia logopedică prin intermediul tehnologiei.

CARACTERISTICI PRINCIPALE:
• Exerciții interactive pentru dezvoltarea vorbirii
• Module personalizate pentru fiecare utilizator
• Tracking al progresului
• Interfață prietenoasă și intuitivă

MISIUNEA NOASTRĂ:
Să oferim o soluție accesibilă și eficientă pentru terapia logopedică, facilitând procesul de învățare și dezvoltare a abilităților de comunicare.

VERSIUNEA APLICAȚIEI:
Versiunea curentă include funcționalități complete pentru gestionarea profilurilor, accesarea modulelor educaționale și urmărirea progresului.

PENTRU SUPPORT:
Pentru întrebări sau suport tehnic, vă rugăm să ne contactați prin intermediul secțiunii de ajutor.
''';

  static const String _helpContent = '''
AJUTOR ȘI SUPPORT

CUM PUTEȚI OBȚINE AJUTOR:

1. CENTRU DE AJUTOR
Explorează secțiunea de întrebări frecvente (FAQ) pentru răspunsuri la cele mai comune întrebări.

2. CONTACT SUPPORT
Dacă ai nevoie de asistență suplimentară, te rugăm să ne contactezi:
• Email: support@logopedy.ro
• Telefon: [Număr de telefon]

3. GĂSIȚI RĂSPUNSURI RAPIDE:
• Probleme de conectare: Verifică conexiunea la internet
• Probleme cu contul: Verifică credențialele de autentificare
• Probleme tehnice: Încearcă să repornești aplicația

4. FEEDBACK
Valorăm feedback-ul tău! Dacă ai sugestii sau întâmpini probleme, te rugăm să ne contactezi.

PROBLEME COMUNE:

• "Nu pot accesa modulele"
  Soluție: Asigură-te că ai un profil activ selectat.

• "Aplicația se blochează"
  Soluție: Încearcă să ștergi cache-ul aplicației sau să o reinstalezi.

• "Nu primesc notificări"
  Soluție: Verifică setările de notificări în telefon.
''';

  static const String _cookiesContent = '''
POLITICA COOKIE-URI

1. CE SUNT COOKIE-URILE
Cookie-urile sunt fișiere text mici stocate pe dispozitivul dvs. când accesați aplicația sau site-ul nostru web.

2. TIPURI DE COOKIE-URI UTILIZATE

Cookie-uri esențiale:
Acestea sunt necesare pentru funcționarea aplicației și nu pot fi dezactivate.

Cookie-uri de performanță:
Acestea ne ajută să înțelegem cum utilizați aplicația pentru a îmbunătăți performanța.

Cookie-uri de funcționalitate:
Acestea permit aplicației să își amintească preferințele dvs. (de ex., limba, tema).

3. GESTIONAREA COOKIE-URILOR
Puteți gestiona preferințele cookie-urilor prin setările dispozitivului dvs. sau browser-ului.

4. COOKIE-URI TERȚE
Unele servicii terțe folosite în aplicație pot folosi propriile cookie-uri. Acestea sunt supuse politicilor de confidențialitate ale respectivilor furnizori.

5. ACTUALIZĂRI
Ne rezervăm dreptul de a actualiza această politică. Modificările vor fi publicate în această secțiune.
''';

  static String get _privacyContent => '''
DECLARAȚIE DE CONFIDENȚIALITATE

1. PRELUCRAREA DATELOR
Prelucrăm datele personale în conformitate cu Regulamentul General privind Protecția Datelor (GDPR) și legislația română aplicabilă.

2. DATELE COLECTATE
Colectăm următoarele tipuri de date:
• Informații de identificare (nume, email)
• Date de profil (varstă, gen)
• Date de utilizare (progres, activități)
• Date tehnice (adresă IP, tip de dispozitiv)

3. UTILIZAREA DATELOR
Utilizăm datele pentru:
• Furnizarea serviciilor aplicației
• Îmbunătățirea experienței utilizatorului
• Analiza utilizării și performanței
• Comunicări importante despre serviciu

4. SECURITATEA DATELOR
Implementăm măsuri de securitate tehnice și organizaționale pentru a proteja datele dvs. personale împotriva accesului neautorizat, pierderii sau distrugerii.

5. PARTAJAREA DATELOR
Nu vindem datele dvs. personale. Putem partaja date doar în următoarele situații:
• Cu servicii terțe necesare pentru funcționarea aplicației
• Când este necesar conform legii
• Cu consimțământul dvs. explicit

6. DREPTURILE DVS.
Aveți dreptul la:
• Acces la datele dvs. personale
• Rectificarea datelor incorecte
• Ștergerea datelor (dreptul de a fi uitat)
• Restricționarea prelucrării
• Portabilitatea datelor
• Opoziție față de prelucrare

7. STOCAREA DATELOR
Păstrăm datele dvs. personale doar atât timp cât este necesar pentru scopurile menționate sau conform cerințelor legale.

8. CONTACT
Pentru întrebări despre confidențialitate, contactați-ne la: privacy@logopedy.ro

Ultima actualizare: ${DateTime.now().year}
''';
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipOfTheDayCard extends StatelessWidget {
  const _TipOfTheDayCard();

  String _getTipOfTheDay() {
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    
    final tips = [
      'Practică zilnică! Exersarea regulată a exercițiilor logopedice este esențială pentru progres.',
      'Vorbește clar și lent când practici sunetele dificile. Nu te grăbi!',
      'Folosește un oglindă când exersezi pentru a vedea cum mișți buzele și limba.',
      'Ascultă-te când vorbești. Înregistrează-te pentru a observa îmbunătățirile.',
      'Fă pauze regulate între sesiunile de practică. Oboseala poate afecta performanța.',
      'Cântă! Cântatul poate ajuta la îmbunătățirea controlului respirației și a vocalelor.',
      'Citește cu voce tare zilnic. Aceasta îmbunătățește claritatea vorbirii.',
      'Folosește exerciții de respirație pentru a controla mai bine fluxul de aer.',
      'Vizualizează sunetele înainte de a le pronunța. Imaginează-ți cum ar trebui să sune.',
      'Celebrează progresul! Fiecare mic pas înainte este important.',
      'Folosește jocuri pentru a face practicarea mai distractivă.',
      'Caută feedback de la alții. Persoanele din jur te pot ajuta să identifici problemele.',
      'Practică sunetele izolate înainte de a le combina în cuvinte.',
      'Menține contactul vizual când vorbești. Ajută la claritate și încredere.',
      'Exersează în situații reale. Practica conversațională este foarte importantă.',
      'Utilizează resurse audio și video pentru a auzi pronunția corectă.',
      'Crează un program de practică zilnică și respectă-l consecvent.',
      'Documentează progresul tău. Asta te ajută să vezi cât de departe ai ajuns.',
      'Rămâi răbdător! Progresul în logopedie necesită timp și perseverență.',
      'Îmbunătățește-ți postura. O postură bună ajută la respirație și vorbire.',
      'Folosește tehnici de relaxare pentru a reduce tensiunea musculară.',
      'Practică sunetele dificile într-un mediu liniștit mai întâi.',
      'Utilizează indicații tactile - pune mâna pe piept pentru a simți vibrațiile.',
      'Învață să respiri cu diafragma pentru un control mai bun al vocii.',
      'Transformă practicarea într-un ritual zilnic pozitiv.',
      'Folosește o aplicație de înregistrare pentru a urmări progresul.',
      'Citește poezii sau texte cu rimă pentru a exersa ritmul vorbirii.',
      'Practică înainte de a dormi - memoria se consolidează în timpul somnului.',
      'Încurajează-te pe tine! Încrederea în sine este esențială pentru succes.',
      'Experimentează cu diferite tehnici până găsești ce funcționează pentru tine.',
    ];
    
    return tips[dayOfYear % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final tip = _getTipOfTheDay();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D72D2),
            Color(0xFFEA2233),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D72D2).withOpacity(0.3),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sfatul zilei',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? const Color(0xFF1B1B20)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _heightFactor = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _iconTurns,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[500],
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ...widget.children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSettingsSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _CollapsibleSettingsSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<_CollapsibleSettingsSection> createState() =>
      _CollapsibleSettingsSectionState();
}

class _CollapsibleSettingsSectionState extends State<_CollapsibleSettingsSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _heightFactor = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? const Color(0xFF1B1B20)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[500],
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null) ...[
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBottomSheet extends StatelessWidget {
  final String title;
  final String content;

  const _InfoBottomSheet({
    required this.title,
    required this.content,
  });

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
            color: cs.brightness == Brightness.dark
                ? const Color(0xFF1B1B20)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: cs.onSurface,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: cs.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FAQBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final faqs = [
      {
        'question': 'Cum creez un profil?',
        'answer':
            'Pentru a crea un profil, accesează secțiunea "Profile" din meniul de jos, apoi apasă pe butonul "+" pentru a adăuga un profil nou. Completează informațiile necesare și salvează.',
      },
      {
        'question': 'Cum accesez modulele?',
        'answer':
            'Pentru a accesa modulele, asigură-te că ai un profil activ selectat. Apoi, accesează secțiunea "Module" din meniul de jos.',
      },
      {
        'question': 'Cum schimb tema aplicației?',
        'answer':
            'Poți schimba tema aplicației accesând secțiunea "Contul meu" și activând/dezactivând modul întunecat.',
      },
      {
        'question': 'Ce trebuie să fac dacă am uitat parola?',
        'answer':
            'Pe pagina de login, apasă pe "Ai uitat parola?" și urmează instrucțiunile pentru a reseta parola.',
      },
      {
        'question': 'Cum șterg contul?',
        'answer':
            'Poți șterge contul din secțiunea "Contul meu". Găsește butonul "Șterge contul" și confirmă acțiunea.',
      },
      {
        'question': 'Aplicația este gratuită?',
        'answer':
            'Aplicația oferă atât un plan gratuit (standard) cât și un plan premium cu funcționalități suplimentare.',
      },
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark
                ? const Color(0xFF1B1B20)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Întrebări frecvente (FAQ)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: cs.onSurface,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return _FAQItem(
                      question: faq['question']!,
                      answer: faq['answer']!,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? const Color(0xFF0D0D10)
            : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        trailing: Icon(
          _isExpanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: cs.onSurface,
        ),
        children: [
          Text(
            widget.answer,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
