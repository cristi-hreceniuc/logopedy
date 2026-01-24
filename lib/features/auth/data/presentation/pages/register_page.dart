import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _otpForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();

  // OTP controllers - 6 individual fields
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _gender = 'male';
  bool _isSpecialist = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // Track if we're in OTP verification step
  bool _isOtpStep = false;
  String? _pendingEmail;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _first.dispose();
    _last.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _clearOtp() {
    for (var c in _otpControllers) {
      c.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, st) {
        if (st.error != null) {
          setState(() {
            _errorMessage = st.error!;
          });
        } else if (st.registerOtpSent && st.pendingRegistrationEmail != null) {
          // OTP sent successfully, move to step 2
          setState(() {
            _errorMessage = null;
            _isOtpStep = true;
            _pendingEmail = st.pendingRegistrationEmail;
          });
          SnackBarUtils.showSuccess(ctx, 'Codul a fost trimis pe email.');
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
        if (_isOtpStep) {
          return _buildOtpVerificationStep(ctx, st);
        }
        return _buildRegistrationStep(ctx, st);
      },
    );
  }

  Widget _buildRegistrationStep(BuildContext ctx, AuthState st) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      illustrationAsset: 'assets/images/signup_image.png',
      title: 'Înregistrează-te',
      subtitle: 'Creează-ți contul în platforma Logopedy',
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

            // First name
            _buildTextField(
              controller: _first,
              label: 'Prenume',
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Câmp obligatoriu' : null,
            ),
            const SizedBox(height: 14),

            // Last name
            _buildTextField(
              controller: _last,
              label: 'Nume',
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Câmp obligatoriu' : null,
            ),
            const SizedBox(height: 14),

            // Gender selector
            _buildGenderSelector(),
            const SizedBox(height: 14),

            // Email
            _buildTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email invalid' : null,
            ),
            const SizedBox(height: 14),

            // Password
            _buildTextField(
              controller: _pass,
              label: 'Parolă',
              obscure: _obscurePass,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Minim 8 caractere' : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            const SizedBox(height: 14),

            // Confirm password
            _buildTextField(
              controller: _confirmPass,
              label: 'Confirmă parola',
              obscure: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Câmp obligatoriu';
                if (v != _pass.text) return 'Parolele nu coincid';
                return null;
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            const SizedBox(height: 16),

            // Specialist checkbox
            InkWell(
              onTap: () => setState(() => _isSpecialist = !_isSpecialist),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isSpecialist,
                        onChanged: (v) =>
                            setState(() => _isSpecialist = v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sunt specialist în logopedie',
                        style: TextStyle(fontSize: 15, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            AuthPrimaryButton(
              text: 'Continuă',
              loading: st.loading,
              onPressed: () {
                if (_form.currentState!.validate()) {
                  setState(() {
                    _errorMessage = null;
                  });
                  context.read<AuthCubit>().requestRegistrationOtp(
                    SignupRequest(
                      email: _email.text.trim(),
                      password: _pass.text,
                      firstName: _first.text.trim(),
                      lastName: _last.text.trim(),
                      gender: _gender,
                      userRole: _isSpecialist ? 'SPECIALIST' : 'USER',
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fill =
        Theme.of(context).inputDecorationTheme.fillColor ??
        const Color(0xFFF2F3F6);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: autofillHints,
      validator: validator,
      style: TextStyle(fontSize: 16, color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: TextStyle(color: cs.primary, fontSize: 14),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        filled: true,
        fillColor: fill,
      ),
    );
  }

  String _getGenderLabel(String value) {
    switch (value) {
      case 'male':
        return 'Masculin';
      case 'female':
        return 'Feminin';
      default:
        return 'Selectează';
    }
  }

  Widget _buildGenderSelector() {
    final cs = Theme.of(context).colorScheme;
    final fill =
        Theme.of(context).inputDecorationTheme.fillColor ??
        const Color(0xFFF2F3F6);

    return GestureDetector(
      onTap: () => _showGenderPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gen',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getGenderLabel(_gender),
                    style: TextStyle(fontSize: 16, color: cs.onSurface),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Selectează genul',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Options
              _buildGenderOption('male', 'Masculin'),
              _buildGenderOption('female', 'Feminin'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String value, String label) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _gender == value;

    return InkWell(
      onTap: () {
        setState(() => _gender = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpVerificationStep(BuildContext ctx, AuthState st) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      illustrationAsset: 'assets/images/signup_image.png',
      title: 'Verifică email-ul',
      subtitle:
          'Am trimis un cod de verificare la\n${_pendingEmail ?? _email.text}',
      showBack: true,
      onBack: () {
        setState(() {
          _isOtpStep = false;
          _errorMessage = null;
          _clearOtp();
        });
      },
      child: Form(
        key: _otpForm,
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

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verifică inbox-ul și introdu codul din 6 cifre.',
                      style: TextStyle(color: cs.primary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // OTP input fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildOtpField(index)),
            ),
            const SizedBox(height: 24),

            AuthPrimaryButton(
              text: 'Verifică codul',
              loading: st.loading,
              onPressed: () {
                if (_otpCode.length == 6) {
                  setState(() {
                    _errorMessage = null;
                  });
                  context.read<AuthCubit>().verifyRegistrationOtp(
                    email: _pendingEmail ?? _email.text.trim(),
                    otp: _otpCode,
                  );
                } else {
                  setState(() {
                    _errorMessage = 'Te rog introdu toate cele 6 cifre.';
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Resend code button
            TextButton(
              onPressed: st.loading
                  ? null
                  : () {
                      setState(() {
                        _errorMessage = null;
                        _clearOtp();
                      });
                      context.read<AuthCubit>().resendRegistrationOtp(
                        _pendingEmail ?? _email.text.trim(),
                      );
                    },
              child: Text(
                'Nu ai primit codul? Retrimite',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    final cs = Theme.of(context).colorScheme;
    final fill =
        Theme.of(context).inputDecorationTheme.fillColor ??
        const Color(0xFFF2F3F6);

    return SizedBox(
      width: 45,
      height: 55,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          filled: true,
          fillColor: fill,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }

          // Auto-submit when all 6 digits are entered
          if (_otpCode.length == 6) {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }
}
