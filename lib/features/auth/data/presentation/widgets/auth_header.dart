// lib/features/auth/presentation/widgets/auth_header.dart
import 'package:flutter/material.dart';

import '../../../../../widgets/app_logo.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.subtitle, this.invert = false});

  final String? subtitle;
  final bool invert; // dacă fișierele tale sunt inversate

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        children: [
          AppLogo(height: 64, invert: invert),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
