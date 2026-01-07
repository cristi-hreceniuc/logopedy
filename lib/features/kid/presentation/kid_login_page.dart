import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/presentation/widgets/auth_ui.dart';
import '../data/kid_api.dart';
import 'kid_home_shell.dart';

class KidLoginPage extends StatefulWidget {
  const KidLoginPage({super.key});

  @override
  State<KidLoginPage> createState() => _KidLoginPageState();
}

class _KidLoginPageState extends State<KidLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = GetIt.I<DioClient>();
      final kidApi = KidApi(dio);
      
      final response = await kidApi.loginWithKey(_keyController.text.trim());
      
      // Store kid tokens
      final store = GetIt.I<SecureStore>();
      final now = DateTime.now();
      await store.saveSession(
        accessToken: response.accessToken,
        accessExpiresAt: now.add(Duration(milliseconds: response.accessExpiresIn)),
        refreshToken: response.refreshToken,
        refreshExpiresAt: now.add(Duration(milliseconds: response.refreshExpiresIn)),
      );
      await store.writeKey('is_kid', 'true');
      await store.writeKey('kid_profile_id', response.profileId.toString());
      await store.writeKey('kid_profile_name', response.profileName);
      await store.writeKey('kid_is_premium', response.isPremium.toString());

      if (mounted) {
        // Navigate to kid home shell
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => KidHomeShell(
              profileId: response.profileId,
              profileName: response.profileName,
              isPremium: response.isPremium,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _parseError(dynamic error) {
    if (error.toString().contains('invalid')) {
      return 'Cheie invalidă. Verifică și încearcă din nou.';
    }
    if (error.toString().contains('activated')) {
      return 'Cheia nu este activată pentru niciun profil.';
    }
    return 'Eroare la autentificare. Încearcă din nou.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return AuthScaffold(
      illustrationAsset: 'assets/images/login_image.png',
      title: 'Intră cu cheia',
      subtitle: 'Introdu cheia primită de la specialist',
      showBack: true,
      onBack: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
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

            // Key input field
            AuthTextField(
              controller: _keyController,
              label: 'Cheia de acces',
              keyboardType: TextInputType.text,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Introdu cheia de acces';
                }
                // UUID format validation (loose)
                if (v.length < 30) {
                  return 'Cheie invalidă';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            
            Text(
              'Cheia este un cod unic primit de la specialist. '
              'O găsești în aplicația specialistului sau pe un card.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Login button
            AuthPrimaryButton(
              text: 'Intră în aplicație',
              loading: _isLoading,
              onPressed: _login,
            ),
            const SizedBox(height: 16),

            // Back to normal login
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Înapoi la autentificare normală'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

