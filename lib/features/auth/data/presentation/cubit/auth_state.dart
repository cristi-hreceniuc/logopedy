part of 'auth_cubit.dart';

class AuthState extends Equatable {
  final bool loading;
  final bool authenticated;
  final bool signupOk;

  /// Pasul 1: a fost trimis codul pe email cu succes
  final bool forgotSent;

  /// Pasul 2: parola a fost resetată cu succes
  final bool resetOk;

  final String? info;   // mesaje informative (non-eroare)
  final String? error;  // mesaje de eroare afișabile
  final String? userRole; // USER, SPECIALIST, PREMIUM, etc.

  const AuthState({
    this.loading = false,
    this.authenticated = false,
    this.signupOk = false,
    this.forgotSent = false,
    this.resetOk = false,
    this.info,
    this.error,
    this.userRole,
  });

  // ---- shortcut factories ca în proiectul tău ----
  const AuthState.unauthenticated() : this();
  const AuthState.loading() : this(loading: true);
  const AuthState.authenticated({String? role}) : this(authenticated: true, userRole: role);
  const AuthState.signupSuccess() : this(signupOk: true);
  const AuthState.resetSent() : this(forgotSent: true); // compat: numele vechi folosit la pasul 1
  const AuthState.resetOk() : this(resetOk: true);
  const AuthState.info(this.info)
      : loading = false,
        authenticated = false,
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        error = null,
        userRole = null;
  const AuthState.error(this.error)
      : loading = false,
        authenticated = false,
        signupOk = false,
        forgotSent = false,
        resetOk = false,
        info = null,
        userRole = null;

  @override
  List<Object?> get props =>
      [loading, authenticated, signupOk, forgotSent, resetOk, info, error, userRole];
}
