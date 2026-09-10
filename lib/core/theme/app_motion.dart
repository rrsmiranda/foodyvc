import 'package:flutter/widgets.dart';

/// Duracoes e curvas de animacao. Respeita "reduzir movimento" das
/// configuracoes de acessibilidade do sistema.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;

  /// Retorna [duration], ou `Duration.zero` se o usuario pediu para reduzir
  /// animacoes (`MediaQuery.disableAnimations`).
  static Duration adaptive(BuildContext context, Duration duration) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduce ? Duration.zero : duration;
  }
}
