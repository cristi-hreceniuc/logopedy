import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/utils/snackbar_utils.dart';
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
  String _userRole = 'USER';
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() { _email.dispose(); _pass.dispose(); _first.dispose(); _last.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          setState(() {
            _errorMessage = st.error!;
          });
          // Don't show snackbar - error is displayed in the UI
        } else if (st.signupOk) {
          setState(() {
            _errorMessage = null;
          });
          SnackBarUtils.showSuccess(ctx, 'Cont creat. Te poți loga.');
          Navigator.of(ctx).pop();
        } else {
          setState(() {
            _errorMessage = null;
          });
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
                // Error message display
                if (_errorMessage != null) ...[
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
                            _errorMessage!,
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
                DropdownButtonFormField<String>(
                  value: _userRole,
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('Utilizator')),
                    DropdownMenuItem(value: 'SPECIALIST', child: Text('Specialist')),
                    DropdownMenuItem(value: 'PREMIUM', child: Text('Premium')),
                  ],
                  onChanged: (v) => setState(() => _userRole = v ?? 'USER'),
                  decoration: const InputDecoration(labelText: 'Tip cont'),
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
                      setState(() {
                        _errorMessage = null; // Clear previous errors
                      });
                      context.read<AuthCubit>().signup(
                        SignupRequest(
                          email: _email.text.trim(),
                          password: _pass.text,
                          firstName: _first.text.trim(),
                          lastName: _last.text.trim(),
                          gender: _gender,
                          userRole: _userRole,
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
