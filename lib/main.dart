import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'core/network/dio_client.dart';
import 'core/state/active_profile.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/domain/auth_repository.dart';
import 'features/profiles/selected_profile_cubit.dart';
import 'features/theme/theme_cubit.dart';
import 'features/auth/data/presentation/cubit/auth_cubit.dart';
import 'app.dart';

// ai deja sl = GetIt.instance în proiectul tău
final sl = GetIt.instance;

Future<void> _setupDI() async {
  sl.registerLazySingleton<SecureStore>(() => SecureStore());
  sl.registerLazySingleton<DioClient>(() => DioClient(sl<SecureStore>()));
  sl.registerLazySingleton<AuthApi>(() => AuthApi(sl<DioClient>().dio));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(sl<AuthApi>(), sl<SecureStore>()));
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
  sl.registerLazySingleton<ActiveProfileService>(() => ActiveProfileService(sl<SecureStore>()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupDI();

  // creează o singură instanță de AuthCubit din DI
  final authCubit = sl<AuthCubit>();
  await authCubit.checkSession(); // rulează o singură dată la boot

  final selectedProfileCubit = SelectedProfileCubit();
  final savedProfileId = await sl<SecureStore>().readActiveProfileId();
  selectedProfileCubit.set(savedProfileId!);
  final active = sl<ActiveProfileService>();
  await active.load();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<SelectedProfileCubit>.value(value: selectedProfileCubit),
      ],
      child: const LogopedyApp(),
    ),
  );
}
