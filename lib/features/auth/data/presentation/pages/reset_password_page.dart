import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../presentation/widgets/auth_ui.dart';
import '../cubit/auth_cubit.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.email});
  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _o1 = true;
  bool _o2 = true;

  @override
  void dispose() { _token.dispose(); _pass1.dispose(); _pass2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(st.error!)));
        } else if (st.resetOk == true) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Parola a fost resetată.')),
          );
          Navigator.of(context).popUntil((r) => r.isFirst); // înapoi la login
        }
      },
      builder: (ctx, st) {
        return AuthScaffold(
          illustrationAsset: 'assets/images/reset_password.png',
          title: 'Resetează parola',
          subtitle: 'Introdu codul primit și noua parolă.',
          showBack: true,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _token,
                  label: 'Cod/Token',
                  keyboardType: TextInputType.text,
                  validator: (v) => (v == null || v.isEmpty) ? 'Obligatoriu' : null,
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _pass1,
                  label: 'Parolă nouă',
                  obscure: _o1,
                  validator: (v) => (v == null || v.length < 6) ? 'Minim 6 caractere' : null,
                  suffix: IconButton(
                    icon: Icon(_o1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _o1 = !_o1),
                  ),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _pass2,
                  label: 'Confirmă parola',
                  obscure: _o2,
                  validator: (v) => (v != _pass1.text) ? 'Parolele nu coincid' : null,
                  suffix: IconButton(
                    icon: Icon(_o2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _o2 = !_o2),
                  ),
                ),
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  text: 'Resetează parola',
                  loading: st.loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      context.read<AuthCubit>().resetPassword(
                        email: widget.email, // trimitem “pe ascuns” emailul din ecranul anterior
                        token: _token.text.trim(),
                        password: _pass1.text,
                        confirmNewPassword: _pass2.text,
                      ); // POST (Bearer)
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
