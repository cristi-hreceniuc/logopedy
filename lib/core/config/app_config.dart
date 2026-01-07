class AppConfig {
  static const String baseUrl = 'https://logobeapp.actiunepentrusanatate.ro';
  
  // Note: S3 assets are served via pre-signed URLs from backend
  // No need for S3 configuration in the mobile app

  // auth (le ai deja)
  static const String loginPath = '/api/v1/auth/login';
  static const String signupPath = '/api/v1/auth/register';
  static const String forgotPasswordPath = '/api/v1/auth/forgot1';
  static const String resetPasswordPath = '/api/v1/auth/reset1';
  
  // registration with OTP verification
  static const String registerRequestOtpPath = '/api/v1/auth/register/request-otp';
  static const String registerVerifyOtpPath = '/api/v1/auth/register/verify-otp';
  static const String registerResendOtpPath = '/api/v1/auth/register/resend-otp';

  // content
  static String modulesPath(int profileId) => '/api/profiles/$profileId/modules';
  static String modulePath(int profileId, int moduleId) =>
      '/api/profiles/$profileId/modules/$moduleId';
  static String submodulePath(int profileId, int submoduleId) =>
      '/api/profiles/$profileId/submodules/$submoduleId';
  static String partPath(int profileId, int partId) =>
      '/api/profiles/$profileId/parts/$partId';
  static String lessonPath(int profileId, int lessonId) =>
      '/api/profiles/$profileId/lessons/$lessonId';

  // progress
  static String progressPath(int profileId) => '/api/profiles/$profileId/progress';
  static String advancePath(int profileId) => '/api/profiles/$profileId/progress/advance';

  static const String refreshPath = '/api/v1/auth/refresh';

  // users
  static String deleteUserPath(String userId) => '/api/v1/users/$userId';
  
  // delete account with OTP
  static const String deleteAccountRequestOtpPath = '/api/v1/auth/delete-account/request-otp';
  static const String deleteAccountConfirmPath = '/api/v1/auth/delete-account/confirm';

  // notifications
  static const String registerFcmTokenPath = '/api/v1/notifications/register-token';
  static const String unregisterFcmTokenPath = '/api/v1/notifications/unregister-token';
}