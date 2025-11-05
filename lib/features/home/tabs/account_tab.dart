import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../auth/data/domain/auth_repository.dart';
import '../../auth/data/models/user_response_dto.dart';
import '../../session/session_info.dart';
import '../../../widgets/app_version.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = GetIt.I<AuthRepository>();

    return SafeArea(
      child: Container(
        color: const Color(0xFFF3F5F8),
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
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    // Header Section with Avatar
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
                                child: Center(
                                  child: Text(
                                    _getInitials(displayUser),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFEA2233),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Name
                          Text(
                            _getDisplayName(displayUser),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF17406B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Email
                          if (displayUser?.email != null && displayUser!.email.isNotEmpty)
                            Text(
                              displayUser.email,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (displayUser?.isPremium == true) ...[
                            const SizedBox(height: 12),
                            Container(
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
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Status Card
                    Container(
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
                              color: (displayUser?.isPremium ?? false)
                                  ? const Color(0xFFEA2233).withOpacity(0.1)
                                  : const Color(0xFF2D72D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              (displayUser?.isPremium ?? false) ? Icons.star_rounded : Icons.person_outline_rounded,
                              size: 28,
                              color: (displayUser?.isPremium ?? false) ? const Color(0xFFEA2233) : const Color(0xFF2D72D2),
                            ),
                          ),
                          const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                                  'Status cont',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(height: 4),
                                Text(
                                  (displayUser?.isPremium ?? false) ? 'Premium' : 'Standard',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: (displayUser?.isPremium ?? false) ? const Color(0xFFEA2233) : const Color(0xFF2D72D2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (displayUser?.isPremium == true)
                            Container(
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
                                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Activ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                          ),
                      ],
                    ),
                  ),
                ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Account Details Card
                    Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: const Color(0xFF2D72D2), size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Detalii cont',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF17406B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (displayUser?.firstName != null && displayUser!.firstName!.isNotEmpty)
                            _DetailRow(
                              icon: Icons.person_outline_rounded,
                              iconColor: const Color(0xFF2D72D2),
                              label: 'Prenume',
                              value: displayUser.firstName!,
                            ),
                          if (displayUser?.firstName != null && displayUser!.firstName!.isNotEmpty)
                            const SizedBox(height: 16),
                          if (displayUser?.lastName != null && displayUser!.lastName!.isNotEmpty)
                            _DetailRow(
                              icon: Icons.person_outline_rounded,
                              iconColor: const Color(0xFF2D72D2),
                              label: 'Nume',
                              value: displayUser.lastName!,
                            ),
                          if (displayUser?.lastName != null && displayUser!.lastName!.isNotEmpty)
                            const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.email_outlined,
                            iconColor: const Color(0xFF2D72D2),
                            label: 'Email',
                            value: displayUser?.email ?? '—',
                          ),
                          if (displayUser?.gender != null && displayUser!.gender!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.wc_rounded,
                              iconColor: const Color(0xFFEA2233),
                              label: 'Gen',
                              value: _getGenderLabel(displayUser.gender!),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFFEA2233),
                            label: 'ID Utilizator',
                            value: displayUser?.id ?? '—',
                          ),
                          if (displayUser?.createdAt != null) ...[
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.calendar_today_outlined,
                              iconColor: const Color(0xFF2D72D2),
                              label: 'Data înregistrării',
                              value: _formatDate(displayUser!.createdAt),
                            ),
                          ],
                          if (displayUser?.role != null && displayUser!.role!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFFEA2233),
                              label: 'Rol',
                              value: displayUser!.role!,
                            ),
                          ],
                          if (displayUser?.status != null && displayUser!.status!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.info_outline_rounded,
                              iconColor: const Color(0xFF2D72D2),
                          label: 'Status',
                              value: displayUser!.status!,
                            ),
                          ],
                    ],
                  ),
                ),

                    const SizedBox(height: 16),

                    // Tip of the Day Card
                    _TipOfTheDayCard(),

              const SizedBox(height: 16),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, st) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: st.loading
                            ? null
                            : () => _deleteAccount(context),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Șterge contul'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, st) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA2233).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: st.loading
                            ? null
                            : () => context.read<AuthCubit>().logout(),
                        icon: st.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.logout_rounded),
                        label: Text(st.loading ? 'Se deconectează...' : 'Deconectează-te'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEA2233),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // App Version in bottom-right corner
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: AppVersion(
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
          'Sigur vrei să ștergi contul? Toate datele tale vor fi șterse permanent. Această acțiune nu poate fi anulată.',
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
              child: const Text('Șterge'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<AuthCubit>().deleteAccount();
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Cont șters cu succes');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Eroare la ștergere: $e');
        }
      }
    }
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D72D2),
            Color(0xFFEA2233),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D72D2).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sfatul zilei',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
