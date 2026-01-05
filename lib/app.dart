import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'core/services/s3_service.dart';
import 'core/state/active_profile.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/network/dio_client.dart';
import 'features/home/home_shell.dart';
import 'features/theme/theme_cubit.dart';
import 'features/auth/data/presentation/cubit/auth_cubit.dart';
import 'features/auth/data/presentation/pages/login_page.dart';
import 'features/onboarding/welcome_page.dart';
import 'features/profiles/data/profiles_repository.dart';

class LogopedyApp extends StatelessWidget {
  const LogopedyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'Logopedy',
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: BlocBuilder<AuthCubit, AuthState>(
            builder: (ctx, st) {
              if (st.loading) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!st.authenticated) {
                return const LoginPage();
              }

              return _OnboardingWrapper();
            },
          ),
        );
      },
    );
  }
}

class _OnboardingWrapper extends StatefulWidget {
  @override
  State<_OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<_OnboardingWrapper> {
  bool _isCheckingOnboarding = true;
  bool _hasCompletedOnboarding = false;
  bool _justCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      // Check if user has any profiles - new users won't have profiles
      final profilesRepo = ProfilesRepository(GetIt.I<DioClient>());
      final profiles = await profilesRepo.listProfiles();
      
      // If user has no profiles, they're new and should see welcome page
      if (profiles.isEmpty) {
        if (mounted) {
          setState(() {
            _hasCompletedOnboarding = false;
            _isCheckingOnboarding = false;
          });
        }
        return;
      }
      
      // If user has profiles, they've already been using the app
      // Skip welcome page (they've completed onboarding)
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = true;
          _isCheckingOnboarding = false;
        });
      }
    } catch (e) {
      // If there's an error checking profiles, fall back to onboarding flag
      debugPrint('Error checking profiles for onboarding: $e');
      final completed = await GetIt.I<SecureStore>().readKey('onboarding_completed');
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = completed == 'true';
          _isCheckingOnboarding = false;
        });
      }
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _hasCompletedOnboarding = true;
      _justCompletedOnboarding = true;
    });
    // Reset the flag after a delay to ensure ProfilesTab has time to read it
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _justCompletedOnboarding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingOnboarding) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasCompletedOnboarding) {
      return WelcomePage(onComplete: _onOnboardingComplete);
    }

    return ListenableBuilder(
      listenable: GetIt.I<ActiveProfileService>(),
      builder: (context, child) {
        final active = GetIt.I<ActiveProfileService>().id;

        // Allow HomeShell to show even without active profile for first login
        // HomeShell will handle auto-selecting the first profile
        return HomeShell(
          profileId: active,
          shouldOpenCreateDialog: _justCompletedOnboarding,
        );
      },
    );
  }
}
