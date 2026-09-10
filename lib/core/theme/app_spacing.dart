import 'package:flutter/widgets.dart';

/// Grid base de 8px. Use estes tokens em vez de numeros soltos.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Padding horizontal padrao de uma tela.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: md);

  /// Padding completo padrao de uma tela.
  static const EdgeInsets page = EdgeInsets.all(md);

  /// Espaco vertical entre secoes.
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
}
