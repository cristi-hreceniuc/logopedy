// lib/features/auth/presentation/widgets/auth_ui.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:logopedy/core/theme/app_theme.dart';

class AuthColors {
  static const red = Color(0xFFEA2233);
  static const blue = Color(0xFF2D72D2);
  static const lightBg = Color(0xFFF3F5F8);
}

class AuthIllustration extends StatelessWidget {
  const AuthIllustration(
      this.asset, {
        super.key,
        this.height = 220,
        this.rounded = true,
      });

  final String asset;
  final double height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(asset, height: height, fit: BoxFit.contain);
    return Padding(
      // puțin mai sus pe ecran
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: rounded
          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: img)
          : img,
    );
  }
}

class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Brand.titleBlueDark : Brand.titleBlue;

    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class AuthSubtitle extends StatelessWidget {
  const AuthSubtitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: cs.onSurface.withOpacity(0.7),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.autofillHints,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: autofillHints,
      validator: validator,
      scrollPadding: EdgeInsets.only(bottom: kb + 120),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      // IMPORTANT: fără UniqueKey – evităm rebuild-uri forțate
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Text(text),
    );
  }
}

/// Scaffold generic pentru ecranele de autentificare.
/// - status bar corect (light/dark)
/// - scroll stabil, inclusiv cu tastatura deschisă
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.illustrationAsset,
    required this.child,
    this.title,
    this.subtitle,
    this.maxWidth = 520,
    this.showBack = false,
  });

  final String illustrationAsset;
  final Widget child;
  final String? title;
  final String? subtitle;
  final double maxWidth;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status bar – iOS/Android
    final overlay = isDark
        ? const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    )
        : const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          toolbarHeight: showBack ? kToolbarHeight : 0,
          leading: showBack
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          )
              : null,
        ),
        body: SafeArea(
          top: !showBack,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      primary: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      // Ridicăm conținutul cu exact înălțimea tastaturii + spațiu
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthIllustration(illustrationAsset),
                                if (title != null) ...[
                                  const SizedBox(height: 4),
                                  AuthTitle(title!),
                                ],
                                if (subtitle != null) ...[
                                  const SizedBox(height: 6),
                                  AuthSubtitle(subtitle!),
                                ],
                                const SizedBox(height: 12),
                                Card(
                                  color: cs.surface,
                                  elevation: 0.5,
                                  shadowColor: cs.shadow.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: child,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Version in bottom-right corner
              Positioned(
                bottom: 8,
                right: 16,
                child: _AuthVersion(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthVersion extends StatelessWidget {
  const _AuthVersion();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final version = snapshot.data!.version;
        final buildNumber = snapshot.data!.buildNumber;
        final versionText = 'v$version${buildNumber != '1' ? '+$buildNumber' : ''}';

        return Text(
          versionText,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
