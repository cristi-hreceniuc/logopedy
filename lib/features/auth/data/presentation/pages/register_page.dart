import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/signup_request.dart';
import '../../../presentation/widgets/auth_ui.dart';
import '../cubit/auth_cubit.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  String _gender = 'male';
  bool _obscure = true;

  @override
  void dispose() { _email.dispose(); _pass.dispose(); _first.dispose(); _last.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(st.error!)));
        } else if (st.signupOk) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cont creat. Te poți loga.')));
          Navigator.of(ctx).pop();
        }
      },
      builder: (ctx, st) {
        return AuthScaffold(
          illustrationAsset: 'assets/images/signup_image.png',
          title: 'Înregistrează-te',
          subtitle: 'Creează-ți contul în platforma Logopedy',
          showBack: true,
          child: Form(
            key: _form,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AuthTextField(
                        controller: _first,
                        label: 'Prenume',
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatoriu' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthTextField(
                        controller: _last,
                        label: 'Nume',
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatoriu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Masculin')),
                    DropdownMenuItem(value: 'female', child: Text('Feminin')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'male'),
                  decoration: const InputDecoration(labelText: 'Gen'),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email invalid' : null,
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _pass,
                  label: 'Parolă',
                  obscure: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => (v == null || v.length < 6) ? 'Minim 6 caractere' : null,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  text: 'Creează cont',
                  loading: st.loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      context.read<AuthCubit>().signup(
                        SignupRequest(
                          email: _email.text.trim(),
                          password: _pass.text,
                          firstName: _first.text.trim(),
                          lastName: _last.text.trim(),
                          gender: _gender,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
