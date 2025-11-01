import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/utils/snackbar_utils.dart';
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

  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          SnackBarUtils.showError(ctx, st.error!);
        }
      },
      builder: (ctx, st) {
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: UniqueKey(), // previne coliziuni cu GlobalKey-ul intern Ink
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text('Ai uitat parola?'),
                  ),
                ),
                const SizedBox(height: 8),
                AuthPrimaryButton(
                  text: 'Login',
                  loading: st.loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
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
