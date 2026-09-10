import 'package:flutter/material.dart';

/// Paleta do app.
///
/// Personalidade (ver `docs/ds-brief-claude-designv2.md`): institucional, seria,
/// transmite seguranca e conformidade. Primaria = azul govtech no espirito do
/// gov.br; acento = teal para acoes de confirmacao. Contraste AA em ambos os
/// temas. Para trocar a identidade, altere so as constantes deste arquivo.
abstract final class AppColors {
  // -- Marca ---------------------------------------------------------------
  static const Color brandBlue = Color(0xFF1351B4);
  static const Color brandTeal = Color(0xFF0F6B5F);

  // -- ColorScheme claro -------------------------------------------------
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brandBlue,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD9E4F7),
    onPrimaryContainer: Color(0xFF0A2A5E),
    secondary: brandTeal,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCFEAE4),
    onSecondaryContainer: Color(0xFF083A33),
    tertiary: Color(0xFF4B5C92),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDBE1FF),
    onTertiaryContainer: Color(0xFF03174A),
    error: Color(0xFFBA1A2E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD9),
    onErrorContainer: Color(0xFF410009),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A2430),
    onSurfaceVariant: Color(0xFF56606E),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F9FC),
    surfaceContainer: Color(0xFFF1F4F9),
    surfaceContainerHigh: Color(0xFFEBEFF5),
    surfaceContainerHighest: Color(0xFFE5EAF1),
    surfaceDim: Color(0xFFDBDFE7),
    surfaceBright: Color(0xFFFFFFFF),
    outline: Color(0xFF79828F),
    outlineVariant: Color(0xFFC9D0DA),
    inverseSurface: Color(0xFF2F3742),
    onInverseSurface: Color(0xFFF0F2F6),
    inversePrimary: Color(0xFFAEC7FF),
    surfaceTint: brandBlue,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // -- ColorScheme escuro ---------------------------------------------------
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFAEC7FF),
    onPrimary: Color(0xFF0A2E63),
    primaryContainer: Color(0xFF1B458C),
    onPrimaryContainer: Color(0xFFD9E4F7),
    secondary: Color(0xFF8FD5C8),
    onSecondary: Color(0xFF00382F),
    secondaryContainer: Color(0xFF0B5247),
    onSecondaryContainer: Color(0xFFCFEAE4),
    tertiary: Color(0xFFB4C4FF),
    onTertiary: Color(0xFF1B2C61),
    tertiaryContainer: Color(0xFF334379),
    onTertiaryContainer: Color(0xFFDBE1FF),
    error: Color(0xFFFFB3AD),
    onError: Color(0xFF680012),
    errorContainer: Color(0xFF93000F),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF12171E),
    onSurface: Color(0xFFE2E6EC),
    onSurfaceVariant: Color(0xFFAEB7C3),
    surfaceContainerLowest: Color(0xFF0D1116),
    surfaceContainerLow: Color(0xFF161C24),
    surfaceContainer: Color(0xFF1A212A),
    surfaceContainerHigh: Color(0xFF242C36),
    surfaceContainerHighest: Color(0xFF2F3742),
    surfaceDim: Color(0xFF12171E),
    surfaceBright: Color(0xFF38414C),
    outline: Color(0xFF78828E),
    outlineVariant: Color(0xFF3D4650),
    inverseSurface: Color(0xFFE2E6EC),
    onInverseSurface: Color(0xFF2F3742),
    inversePrimary: brandBlue,
    surfaceTint: Color(0xFFAEC7FF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // -- Cores semanticas (fora do ColorScheme; `error` fica no scheme) -----
  static const AppSemanticColors lightSemantic = AppSemanticColors(
    success: Color(0xFF1F7A3D),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFC7EDD1),
    onSuccessContainer: Color(0xFF00210E),
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFDDB3),
    onWarningContainer: Color(0xFF2B1700),
    info: Color(0xFF0B5CAD),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFD6E5FB),
    onInfoContainer: Color(0xFF062A52),
  );

  static const AppSemanticColors darkSemantic = AppSemanticColors(
    success: Color(0xFF7FD394),
    onSuccess: Color(0xFF00391A),
    successContainer: Color(0xFF0C5227),
    onSuccessContainer: Color(0xFFC7EDD1),
    warning: Color(0xFFFFB870),
    onWarning: Color(0xFF472A00),
    warningContainer: Color(0xFF683E00),
    onWarningContainer: Color(0xFFFFDDB3),
    info: Color(0xFFA9C7FF),
    onInfo: Color(0xFF052E5B),
    infoContainer: Color(0xFF124379),
    onInfoContainer: Color(0xFFD6E5FB),
  );
}

/// Estados semanticos (`success` / `warning` / `info`) disponibilizados como
/// `ThemeExtension`. Leia com `Theme.of(context).extension<AppSemanticColors>()!`
/// ou pelo atalho `context.semantic`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Atalho para as cores semanticas: `context.semantic.success`.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppColors.lightSemantic;
}
