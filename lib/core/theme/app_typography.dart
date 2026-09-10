import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia do app: Inter (via `google_fonts`), boa legibilidade em telas
/// pequenas e disponivel para empacotar depois.
///
/// Em ambiente de teste sem rede, `google_fonts` degrada para a fonte do
/// sistema sem lancar erro.
abstract final class AppTypography {
  /// Escala de tipos aplicada sobre a base do Material, com pesos ajustados
  /// para o tom institucional (titulos mais firmes).
  static TextTheme textThemeFor(ColorScheme scheme) {
    final TextTheme base = GoogleFonts.interTextTheme();

    final TextTheme scaled = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
      headlineSmall: base.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
      titleLarge:
          base.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return scaled.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      decorationColor: scheme.onSurface,
    );
  }
}
