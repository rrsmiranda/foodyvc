import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum AppBannerKind { success, error, warning, info }

/// Aviso em bloco (nao um SnackBar): fundo tonal + icone + texto. Use para
/// realcar sucesso, erro, aviso ou informacao dentro do conteudo da tela.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.kind,
    required this.message,
    this.title,
  });

  final AppBannerKind kind;
  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors semantic = context.semantic;

    final (Color bg, Color fg, IconData icon) = switch (kind) {
      AppBannerKind.success => (
          semantic.successContainer,
          semantic.onSuccessContainer,
          Icons.check_circle_outline,
        ),
      AppBannerKind.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
      AppBannerKind.warning => (
          semantic.warningContainer,
          semantic.onWarningContainer,
          Icons.warning_amber_outlined,
        ),
      AppBannerKind.info => (
          semantic.infoContainer,
          semantic.onInfoContainer,
          Icons.info_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(color: fg),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
