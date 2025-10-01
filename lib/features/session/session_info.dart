import 'dart:convert';
import 'package:get_it/get_it.dart';
import '../../core/storage/secure_storage.dart';

/// Info extrasă din JWT (fără request la server).
class SessionInfo {
  final String? email;
  final bool isPremium;
  final int? userId;
  final DateTime? expiresAt;

  const SessionInfo({this.email, required this.isPremium, this.userId, this.expiresAt});

  static Future<SessionInfo?> fromStorage() async {
    final store = GetIt.I<SecureStore>();
    final token = await store.readToken();
    if (token == null || token.isEmpty) return null;

    Map<String, dynamic> payload;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      payload = json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    String? email =
    (payload['email'] ?? payload['sub'] ?? payload['username'])?.toString();
    // premium poate fi "is_premium", "premium" sau în "roles"
    final roles = (payload['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final premiumByRole = roles.any((r) => r.toLowerCase().contains('premium'));
    final isPremium = (payload['is_premium'] == true) ||
        (payload['premium'] == true) ||
        premiumByRole;

    final uidRaw = payload['uid'] ?? payload['user_id'] ?? payload['id'];
    final userId = uidRaw is int ? uidRaw : (uidRaw is String ? int.tryParse(uidRaw) : null);

    final exp = payload['exp'];
    final expiresAt = exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
        : null;

    return SessionInfo(email: email, isPremium: isPremium, userId: userId, expiresAt: expiresAt);
  }
}
