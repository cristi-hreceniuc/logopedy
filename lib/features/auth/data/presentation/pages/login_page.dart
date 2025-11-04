import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../../../core/utils/snackbar_utils.dart';
import '../../../../../../core/storage/secure_storage.dart';
import '../../../presentation/widgets/auth_ui.dart';
import '../cubit/auth_cubit.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _rememberEmail = false;
  String? _errorMessage;
  bool _isLoadingEmail = true;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final store = GetIt.I<SecureStore>();
    final rememberedEmail = await store.readRememberedEmail();
    if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
      _email.text = rememberedEmail;
      setState(() {
        _rememberEmail = true;
      });
    }
    if (mounted) {
      setState(() {
        _isLoadingEmail = false;
      });
    }
  }

  Future<void> _reloadRememberedEmail() async {
    final store = GetIt.I<SecureStore>();
    final rememberedEmail = await store.readRememberedEmail();
    if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
      _email.text = rememberedEmail;
      if (mounted) {
        setState(() {
          _rememberEmail = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _rememberEmail = false;
        });
      }
    }
  }

  Future<void> _saveEmailIfRemembered() async {
    final store = GetIt.I<SecureStore>();
    final emailToSave = _email.text.trim();
    // Always save the email when logging in successfully (regardless of checkbox)
    if (emailToSave.isNotEmpty) {
      await store.saveRememberedEmail(emailToSave);
      // Update checkbox to reflect that email is now remembered
      if (mounted) {
        setState(() {
          _rememberEmail = true;
        });
      }
    }
  }

  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null && st.error!.isNotEmpty) {
          setState(() {
            _errorMessage = st.error!;
          });
          // Also show snackbar for visibility
          SnackBarUtils.showError(ctx, st.error!);
        } else if (st.authenticated) {
          // Clear error on successful login
          setState(() {
            _errorMessage = null;
            _wasAuthenticated = true;
          });
          // Always save the email used for login
          _saveEmailIfRemembered();
        } else if (!st.authenticated && !st.loading && _wasAuthenticated) {
          // Reload remembered email when user logs out (transition from authenticated to unauthenticated)
          _reloadRememberedEmail();
          _wasAuthenticated = false;
        }
        // Don't clear error when loading or when going back to unauthenticated
        // Keep error visible until user tries again or succeeds
      },
      builder: (ctx, st) {
        if (_isLoadingEmail) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AuthScaffold(
          illustrationAsset: 'assets/images/login_image.png',
          title: 'Logopedy',
          subtitle: 'Pentru a contiua, autentifică-te',
          showBack: false,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error message display - use state directly for immediate updates
                if (st.error != null && st.error!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            st.error!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email invalid' : null,
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _pass,
                  label: 'Parolă',
                  obscure: _obscure,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => (v == null || v.length < 6) ? 'Minim 6 caractere' : null,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberEmail,
                      onChanged: (value) {
                        final newValue = value ?? false;
                        setState(() {
                          _rememberEmail = newValue;
                        });
                        // If unchecked, clear the remembered email
                        if (!newValue) {
                          final store = GetIt.I<SecureStore>();
                          store.clearRememberedEmail();
                        }
                      },
                    ),
                    const Text('Ține minte email-ul'),
                    const Spacer(),
                    TextButton(
                      key: UniqueKey(),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text('Ai uitat parola?'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AuthPrimaryButton(
                  text: 'Login',
                  loading: st.loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      setState(() {
                        _errorMessage = null; // Clear previous errors
                      });
                      context.read<AuthCubit>().login(_email.text.trim(), _pass.text);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  key: UniqueKey(), // previne coliziuni cu GlobalKey-ul intern Ink
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Nou pe platformă?', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: const Text('Înregistrează-te'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
