import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../auth/data/presentation/cubit/auth_cubit.dart';
import '../auth/data/domain/auth_repository.dart';
import '../auth/data/models/user_response_dto.dart';
import '../profiles/data/profiles_repository.dart';
import '../profiles/models/profile_model.dart';
import '../profiles/selected_profile_cubit.dart';
import '../session/session_info.dart';
import '../../core/state/active_profile.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';
import 'tabs/account_tab.dart';
import 'tabs/profiles_tab.dart';
import 'tabs/modules_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.profileId, this.shouldOpenCreateDialog = false});
  final int? profileId;
  final bool shouldOpenCreateDialog;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _hasAutoSelected = false;

  @override
  void initState() {
    super.initState();
    // If no active profile, navigate to profiles tab and auto-select first profile
    if (widget.profileId == null) {
      _index = 0; // Profiles tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelectFirstProfile();
      });
    }
  }

  Future<void> _autoSelectFirstProfile() async {
    if (_hasAutoSelected) return;
    
    try {
      final profilesRepo = ProfilesRepository(GetIt.I<DioClient>());
      final profiles = await profilesRepo.listProfiles();
      
      if (profiles.isNotEmpty && mounted) {
        _hasAutoSelected = true;
        final firstProfile = profiles.first;
        
        // Set as active profile
        context.read<SelectedProfileCubit>().set(firstProfile.id);
        await GetIt.I<SecureStore>().saveActiveProfileId(firstProfile.id);
        GetIt.I<DioClient>().setActiveProfile(firstProfile.id);
        await GetIt.I<ActiveProfileService>().set(firstProfile.id);
      } else if (profiles.isEmpty && mounted && widget.profileId == null) {
        // No profiles exist and no active profile - this will trigger the create dialog
        // The ProfilesTab will handle opening the dialog automatically
        _hasAutoSelected = true; // Prevent retrying
      }
    } catch (e) {
      debugPrint('Error auto-selecting first profile: $e');
    }
  }

  Widget _buildInitialsAvatar(String initials, bool isSelected, {double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.grey[300],
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    Widget? customIcon,
  ) {
    final isSelected = _index == index;
    final currentProfileId = GetIt.I<ActiveProfileService>().id;
    
    // Prevent navigation to modules tab if no active profile
    final canNavigateToModules = index != 1 || currentProfileId != null;
    
    return GestureDetector(
      onTap: () {
        if (canNavigateToModules) {
          setState(() => _index = index);
        } else {
          // Show message when trying to access modules without profile
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Te rugăm să creezi un profil pentru a accesa modulele'),
              backgroundColor: Color(0xFFEA2233),
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate to profiles tab instead
          setState(() => _index = 0);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEA2233).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ??
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.grey[600],
                  size: 26,
                ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = GetIt.I<AuthRepository>();

    return ListenableBuilder(
      listenable: GetIt.I<ActiveProfileService>(),
      builder: (context, _) {
        final currentProfileId = GetIt.I<ActiveProfileService>().id;
        
        // Update tabs when profile changes
        final updatedTabs = [
          ProfilesTab(shouldOpenCreateDialog: widget.shouldOpenCreateDialog),
          currentProfileId != null 
            ? ModulesTab(profileId: currentProfileId)
            : const _PlaceholderModulesTab(),
          const AccountTab(),
        ];
        
        return BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, curr) => prev.authenticated && !curr.authenticated,
          listener: (context, state) {
            // Log out -> LogopedyApp te duce automat la LoginPage
          },
          child: Scaffold(
            body: IndexedStack(index: _index, children: updatedTabs),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Profile tab with icon
                      _buildNavItem(0, Icons.group_outlined, Icons.group, 'Profile', null),
                      // Modules tab
                      _buildNavItem(1, Icons.menu_book_outlined, Icons.menu_book, 'Module', null),
                      // Account tab with initials
                      FutureBuilder<UserResponseDto?>(
                        future: authRepo.getCurrentUser().catchError((_) => null),
                        builder: (context, userSnapshot) {
                          return FutureBuilder<SessionInfo?>(
                            future: SessionInfo.fromStorage(),
                            builder: (context, sessionSnapshot) {
                              final user = userSnapshot.data;
                              final session = sessionSnapshot.data;
                              String accountInitials = 'A';
                              
                              // Try user data first
                              if (user?.firstName != null && user?.lastName != null) {
                                accountInitials = '${user!.firstName![0]}${user.lastName![0]}';
                              } else if (user?.firstName != null) {
                                accountInitials = user!.firstName![0];
                              } else if (user?.lastName != null) {
                                accountInitials = user!.lastName![0];
                              } else if (user?.email != null && user!.email.isNotEmpty) {
                                accountInitials = user.email[0].toUpperCase();
                              }
                              // Fallback to session info
                              else if (session?.firstName != null && session?.lastName != null) {
                                accountInitials = '${session!.firstName![0]}${session.lastName![0]}';
                              } else if (session?.firstName != null) {
                                accountInitials = session!.firstName![0];
                              } else if (session?.lastName != null) {
                                accountInitials = session!.lastName![0];
                              } else if (session?.email != null && session!.email!.isNotEmpty) {
                                accountInitials = session.email![0].toUpperCase();
                              }
                              
                              final isSelected = _index == 2;
                              return _buildNavItem(
                                2,
                                Icons.person_outline,
                                Icons.person,
                                'Contul meu',
                                _buildInitialsAvatar(accountInitials, isSelected),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0] : 'P';
    }
    return '${parts[0][0]}${parts[1][0]}';
  }
}

// Placeholder widget for modules tab when no profile is selected
class _PlaceholderModulesTab extends StatelessWidget {
  const _PlaceholderModulesTab();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Color(0xFFEA2233)),
            SizedBox(height: 16),
            Text(
              'Selectează un profil pentru a accesa modulele',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF17406B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
