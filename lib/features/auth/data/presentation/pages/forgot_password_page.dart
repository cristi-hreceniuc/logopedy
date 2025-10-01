import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../presentation/widgets/auth_ui.dart';
import '../cubit/auth_cubit.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(st.error!)));
        } else if (st.forgotSent == true) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Dacă adresa utilizată este asociată unui cont, un email a fost trimis.',
              ),
            ),
          );
          // mergem la reset, pasăm email-ul
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(email: _email.text.trim()),
            ),
          );
        }
      },
      builder: (ctx, st) {
        return AuthScaffold(
          illustrationAsset: 'assets/images/forgot_password.png',
          title: 'Ai uitat parola?',
          subtitle: 'Introdu adresa ta de email și îți trimitem un cod.',
          showBack: true,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Email invalid' : null,
                ),
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  text: 'Trimite cod',
                  loading: st.loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      context.read<AuthCubit>().sendResetCode(
                        _email.text.trim(),
                      ); // POST /forgot1 (Bearer)
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
