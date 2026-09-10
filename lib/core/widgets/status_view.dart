import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Tom visual de um [StatusView] — define a cor do icone/realce.
enum StatusTone { neutral, success, warning, danger, info }

/// Bloco de estado em tela cheia: icone (ou spinner), titulo, descricao e ate
/// duas acoes. E o componente-nucleo da verificacao de idade — renderiza os 8
/// estados do fluxo.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    this.icon,
    this.busy = false,
    required this.title,
    this.description,
    this.tone = StatusTone.neutral,
    this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.child,
    this.footnote,
  }) : assert(
          icon != null || busy,
          'StatusView precisa de um icone ou de busy=true',
        );

  /// Icone do estado. Ignorado quando [busy] e `true`.
  final IconData? icon;

  /// Mostra um `CircularProgressIndicator` no lugar do icone.
  final bool busy;

  final String title;
  final String? description;
  final StatusTone tone;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Conteudo extra entre a descricao e as acoes (ex.: um [AppBanner]).
  final Widget? child;

  /// Texto pequeno de apoio, ao pe do bloco.
  final String? footnote;

  Color _toneColor(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semantic;
    return switch (tone) {
      StatusTone.neutral => scheme.onSurface,
      StatusTone.success => semantic.success,
      StatusTone.warning => semantic.warning,
      StatusTone.danger => scheme.error,
      StatusTone.info => semantic.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPrimary = primaryLabel != null && onPrimary != null;
    final bool hasSecondary = secondaryLabel != null && onSecondary != null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Center(
            child: busy
                ? const SizedBox(
                    height: 56,
                    width: 56,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(icon, size: 72, color: _toneColor(context)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (child != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            child!,
          ],
          const Spacer(),
          if (footnote != null) ...<Widget>[
            Text(
              footnote!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (hasPrimary)
            AppButton(
              label: primaryLabel!,
              onPressed: onPrimary,
              loading: primaryLoading,
            ),
          if (hasSecondary) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
