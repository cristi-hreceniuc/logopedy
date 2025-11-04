import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:logopedy/features/profiles/presentation/profile_picker_sheet.dart';
import 'core/state/active_profile.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';
import 'features/theme/theme_cubit.dart';
import 'features/auth/data/presentation/cubit/auth_cubit.dart';
import 'features/auth/data/presentation/pages/login_page.dart';

class LogopedyApp extends StatelessWidget {
  const LogopedyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'Logopedy',
          debugShowCheckedModeBanner: false,
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

              return ListenableBuilder(
                listenable: GetIt.I<ActiveProfileService>(),
                builder: (context, child) {
                  final active = GetIt.I<ActiveProfileService>().id;

                  // Allow HomeShell to show even without active profile for first login
                  // HomeShell will handle auto-selecting the first profile
                  return HomeShell(profileId: active);
                },
              );
            },
          ),
        );
      },
    );
  }
}
