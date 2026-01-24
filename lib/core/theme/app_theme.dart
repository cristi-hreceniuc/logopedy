import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

/// Paletă de brand (roșu premium + accente reci).
class Brand {
  static const Color red = Color(0xFFEA2233);
  static const Color redDark = Color(0xFFD21828);

  static const Color darkBgSoft = Color(0xFF1B1B21); // fundal (scaffold)
  static const Color darkSurfaceSoft = Color(
    0xFF232329,
  ); // suprafețe (carduri, sheet-uri)

  static const Color lightBg = Color(0xFFF3F5F8);
  static const Color lightSurface = Colors.white;

  static const Color blue = Color(0xFF2D72D2);
  static const Color blueSoft = Color(0xFF7BA7EF);

  /// pentru titluri (light)
  static const Color titleBlue = Color(0xFF17406B);
  static const Color titleBlueDark = Color(
    0xFF2A6BB0,
  ); // pentru dark (mai vizibil)
}

/// Extensie pentru artefacte de brand (ex: gradient, raze).
class AppBrand extends ThemeExtension<AppBrand> {
  final Gradient heroGradient;
  final BorderRadiusGeometry radiusLg;
  final BorderRadiusGeometry radiusMd;

  const AppBrand({
    required this.heroGradient,
    required this.radiusLg,
    required this.radiusMd,
  });

  @override
  AppBrand copyWith({
    Gradient? heroGradient,
    BorderRadiusGeometry? radiusLg,
    BorderRadiusGeometry? radiusMd,
  }) {
    return AppBrand(
      heroGradient: heroGradient ?? this.heroGradient,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusMd: radiusMd ?? this.radiusMd,
    );
  }

  @override
  AppBrand lerp(ThemeExtension<AppBrand>? other, double t) {
    if (other is! AppBrand) return this;
    return AppBrand(
      heroGradient:
          LinearGradient.lerp(
            heroGradient as LinearGradient,
            other.heroGradient as LinearGradient,
            t,
          ) ??
          heroGradient,
      radiusLg:
          BorderRadius.lerp(
            radiusLg as BorderRadius,
            other.radiusLg as BorderRadius,
            t,
          ) ??
          radiusLg,
      radiusMd:
          BorderRadius.lerp(
            radiusMd as BorderRadius,
            other.radiusMd as BorderRadius,
            t,
          ) ??
          radiusMd,
    );
  }
}

class AppTheme {
  /// TextTheme: Poppins pentru titluri, Manrope pentru body.
  static TextTheme _textTheme(TextTheme base) {
    final body = GoogleFonts.manropeTextTheme(base);
    final headline = GoogleFonts.poppinsTextTheme(base);

    return body.copyWith(
      headlineLarge: headline.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: headline.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        fontSize: 30,
      ),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.25),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.25),
    );
  }

  // ---------- LIGHT ----------
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.red,
      brightness: Brightness.light,
      primary: Brand.red,
      secondary: Brand.blue,
      surface: Brand.lightSurface,
      background: Brand.lightBg,
    );

    final text = _textTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: Brand.lightBg,
      // Remove Material3 "tonal tint" (often pinkish with a red seed) from dialogs & navigation bars.
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.12),
        labelTextStyle: MaterialStatePropertyAll(
          GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Brand.lightBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(10),
          visualDensity: VisualDensity.compact,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F3F6),
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),

      // Butoane — aceleași în light & dark
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: scheme.onSurface,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: Brand.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(color: scheme.onSurface),
        backgroundColor: const Color(0xFFF2F3F6),
        selectedColor: Brand.red.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFFE3E6EC)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: Brand.red, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withOpacity(0.7),
        ),
      ),
      extensions: const [
        AppBrand(
          heroGradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFF0D0D10), Color(0xFF1B1B20)],
            stops: [0.0, 1.0],
          ),
          radiusLg: BorderRadius.all(Radius.circular(24)),
          radiusMd: BorderRadius.all(Radius.circular(16)),
        ),
      ],
    );
  }

  // ---------- DARK ----------
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.red,
      brightness: Brightness.dark,
      primary: Brand.red,
      secondary: Brand.blue,
      // ridicăm și suprafețele un pic mai deschise
      surface: Brand.darkSurfaceSoft,
      background: Brand.darkBgSoft,
    );

    final text = _textTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,

      // fundal general – mai deschis
      scaffoldBackgroundColor: Brand.darkBgSoft,

      // Remove Material3 tonal tint from dialogs & navigation bars (can look colored/washed).
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.18),
        labelTextStyle: MaterialStatePropertyAll(
          GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),

      // carduri/sheet-uri – cu o treaptă mai deschise
      cardTheme: CardThemeData(
        color: Brand.darkSurfaceSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Brand.darkSurfaceSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // câmpurile au fill un pic mai luminos ca să iasă din fundal
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        // ~ mai vizibil pe bg mai deschis
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.85)),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark, // iOS
          statusBarIconBrightness: Brightness.light, // Android
        ),
      ),

      // Butoane – identice cu light
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: scheme.onSurface,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurface.withOpacity(0.7),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),

      extensions: const [
        AppBrand(
          heroGradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFF141418), Color(0xFF22222A)],
            // și gradientul ușor mai deschis
            stops: [0.0, 1.0],
          ),
          radiusLg: BorderRadius.all(Radius.circular(24)),
          radiusMd: BorderRadius.all(Radius.circular(16)),
        ),
      ],
    );
  }
}
