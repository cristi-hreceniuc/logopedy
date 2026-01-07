part of 'auth_cubit.dart';

class AuthState extends Equatable {
  final bool loading;
  final bool authenticated;
  final bool signupOk;

  /// Pasul 1: a fost trimis codul pe email cu succes
  final bool forgotSent;

  /// Pasul 2: parola a fost resetată cu succes
  final bool resetOk;

  /// Registration OTP: OTP has been sent to email
  final bool registerOtpSent;
  
  /// Email for pending registration (used for OTP verification)
  final String? pendingRegistrationEmail;

  /// Delete account OTP: OTP has been sent to email
  final bool deleteAccountOtpSent;
  
  /// Email for pending account deletion (used for OTP verification)
  final String? pendingDeleteAccountEmail;

  final String? info;   // mesaje informative (non-eroare)
  final String? error;  // mesaje de eroare afișabile
  final String? userRole; // USER, SPECIALIST, PREMIUM, etc.
  
  /// Kid session data (for kids logged in with license key)
  final bool isKid;
  final int? kidProfileId;
  final String? kidProfileName;
  final bool? kidIsPremium;

  const AuthState({
    this.loading = false,
    this.authenticated = false,
    this.signupOk = false,
    this.forgotSent = false,
    this.resetOk = false,
    this.registerOtpSent = false,
    this.pendingRegistrationEmail,
    this.deleteAccountOtpSent = false,
    this.pendingDeleteAccountEmail,
    this.info,
    this.error,
    this.userRole,
    this.isKid = false,
    this.kidProfileId,
    this.kidProfileName,
    this.kidIsPremium,
  });

  // ---- shortcut factories ca în proiectul tău ----
  const AuthState.unauthenticated() : this();
  const AuthState.loading() : this(loading: true);
  const AuthState.authenticated({String? role}) : this(authenticated: true, userRole: role);
  const AuthState.kidAuthenticated({
    required int profileId,
    required String profileName,
    required bool isPremium,
  }) : this(
    authenticated: true,
    isKid: true,
    kidProfileId: profileId,
    kidProfileName: profileName,
    kidIsPremium: isPremium,
  );
  const AuthState.signupSuccess() : this(signupOk: true);
  const AuthState.resetSent() : this(forgotSent: true); // compat: numele vechi folosit la pasul 1
  const AuthState.resetOk() : this(resetOk: true);
  const AuthState.registerOtpSent(String email) 
      : loading = false,
        authenticated = false,
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        registerOtpSent = true,
        pendingRegistrationEmail = email,
        deleteAccountOtpSent = false,
        pendingDeleteAccountEmail = null,
        info = null,
        error = null,
        userRole = null,
        isKid = false,
        kidProfileId = null,
        kidProfileName = null,
        kidIsPremium = null;
  const AuthState.deleteAccountOtpSent(String email) 
      : loading = false,
        authenticated = true,  // Keep authenticated to stay on account page
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        registerOtpSent = false,
        pendingRegistrationEmail = null,
        deleteAccountOtpSent = true,
        pendingDeleteAccountEmail = email,
        info = null,
        error = null,
        userRole = null,
        isKid = false,
        kidProfileId = null,
        kidProfileName = null,
        kidIsPremium = null;
  const AuthState.info(this.info)
      : loading = false,
        authenticated = false,
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        registerOtpSent = false,
        pendingRegistrationEmail = null,
        deleteAccountOtpSent = false,
        pendingDeleteAccountEmail = null,
        error = null,
        userRole = null,
        isKid = false,
        kidProfileId = null,
        kidProfileName = null,
        kidIsPremium = null;
  const AuthState.error(this.error)
      : loading = false,
        authenticated = false,
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        registerOtpSent = false,
        pendingRegistrationEmail = null,
        deleteAccountOtpSent = false,
        pendingDeleteAccountEmail = null,
        info = null,
        userRole = null,
        isKid = false,
        kidProfileId = null,
        kidProfileName = null,
        kidIsPremium = null;

  @override
  List<Object?> get props =>
      [loading, authenticated, signupOk, forgotSent, resetOk, registerOtpSent, pendingRegistrationEmail, deleteAccountOtpSent, pendingDeleteAccountEmail, info, error, userRole, isKid, kidProfileId, kidProfileName, kidIsPremium];
}
