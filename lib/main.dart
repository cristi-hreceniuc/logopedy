import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/network/dio_client.dart';
import 'core/services/audio_cache_service.dart';
import 'core/services/feedback_service.dart';
import 'core/services/part_asset_cache_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/s3_service.dart';
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
  
  // Initialize audio cache service
  final audioCache = AudioCacheService(sl<DioClient>().dio);
  await audioCache.initialize();
  sl.registerLazySingleton<AudioCacheService>(() => audioCache);
  
  // Initialize feedback service (haptics + sounds)
  final feedbackService = FeedbackService();
  await feedbackService.initialize();
  sl.registerLazySingleton<FeedbackService>(() => feedbackService);
  
  sl.registerLazySingleton<S3Service>(() => S3Service(sl<DioClient>()));
  sl.registerLazySingleton<PartAssetCacheService>(() => PartAssetCacheService(sl<DioClient>().dio));
  sl.registerLazySingleton<AuthApi>(() => AuthApi(sl<DioClient>().dio));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(sl<AuthApi>(), sl<SecureStore>()));
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
  sl.registerLazySingleton<ActiveProfileService>(() => ActiveProfileService(sl<SecureStore>()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Romanian locale for date formatting
  await initializeDateFormatting('ro_RO');
  
  // Initialize Firebase first (required)
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }
  
  // Initialize Push Notifications (non-blocking - app should work without it)
  PushNotificationService? pushService;
  try {
    pushService = PushNotificationService();
    await pushService.initialize();
    debugPrint('✅ Push notifications initialized');
  } catch (e) {
    debugPrint('❌ Push notification initialization error: $e');
    // Continue without push notifications
  }
  
  late final AuthCubit authCubit;
  late final SelectedProfileCubit selectedProfileCubit;
  
  try {
    await _setupDI();
    debugPrint('✅ DI setup complete');
    
    // Register push notification service in DI (only if initialized)
    if (pushService != null) {
      sl.registerLazySingleton<PushNotificationService>(() => pushService!);
    }

    // creează o singură instanță de AuthCubit din DI
    authCubit = sl<AuthCubit>();
    await authCubit.checkSession(); // rulează o singură dată la boot
    debugPrint('✅ Auth session checked');

    selectedProfileCubit = SelectedProfileCubit();
    final savedProfileId = await sl<SecureStore>().readActiveProfileId();
    
    if (savedProfileId != null) {
      selectedProfileCubit.set(savedProfileId);
    }
    
    final active = sl<ActiveProfileService>();
    await active.load();
    debugPrint('✅ All initialization complete');
  } catch (e, stackTrace) {
    // Log error for debugging but don't crash the app
    debugPrint('❌ Error in main(): $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Create fallback cubits if initialization failed
    try {
      if (!sl.isRegistered<AuthCubit>()) {
        authCubit = AuthCubit(sl<AuthRepository>());
      } else {
        authCubit = sl<AuthCubit>();
      }
      selectedProfileCubit = SelectedProfileCubit();
    } catch (fallbackError) {
      debugPrint('❌ Fallback initialization also failed: $fallbackError');
      rethrow;
    }
  }

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
