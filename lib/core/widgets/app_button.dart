import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

enum AppButtonVariant {
  /// Acao principal da tela (preenchido).
  primary,

  /// Acao secundaria (contorno).
  secondary,
}

/// Botao do design system. Estados: normal, desabilitado (`onPressed == null`)
/// e **loading** (mostra um spinner no lugar do rotulo e fica inerte).
///
/// Altura minima de 48px (alvo de toque WCAG). Por padrao ocupa a largura
/// disponivel; passe `expand: false` para encolher ao conteudo.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || loading;
    final VoidCallback? effectiveOnPressed = disabled ? null : onPressed;

    final Widget content = loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    // Os botoes do Material ja expoem semantica de botao acessivel a partir do
    // rotulo; durante o loading marcamos explicitamente o estado ocupado.
    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
    };

    if (!loading) return button;
    return Semantics(
      label: '$label, carregando',
      child: button,
    );
  }
}
