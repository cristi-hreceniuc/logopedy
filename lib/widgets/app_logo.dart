import 'package:flutter/material.dart';

/// Convenție clară (recomandat să denumești așa fișierele):
/// - logo_on_light.png  = logo închis la culoare (pentru fundaluri deschise)
/// - logo_on_dark.png   = logo deschis/alb (pentru fundaluri închise)
///
/// Dacă ai deja `logo_light.png` / `logo_dark.png` dar sunt invers, setezi `invert: true`.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 64,
    this.invert = false,
    this.forceMode, // ex: ThemeMode.light ca să forțezi varianta
  });

  final double height;
  final bool invert;
  final ThemeMode? forceMode;

  @override
  Widget build(BuildContext context) {
    // 1) determină tema efectivă pentru acest context
    final Brightness effectiveBrightness = switch (forceMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark  => Brightness.dark,
      _               => Theme.of(context).colorScheme.brightness,
    };

    // 2) alege asset-ul potrivit
    // În mod NORMAL: dark -> logo_on_dark (logo alb), light -> logo_on_light (logo închis)
    final bool useDarkAsset = (effectiveBrightness == Brightness.dark);

    final bool pickDark = invert ? !useDarkAsset : useDarkAsset;
    final String path = pickDark
        ? 'assets/images/logo_dark.png'
        : 'assets/images/logo_light.png';

    return Image.asset(path, height: height);
  }
}
