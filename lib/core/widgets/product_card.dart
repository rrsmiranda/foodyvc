import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'adult_badge.dart';

/// Cartao de produto da vitrine: nome, preco, selo "18+" (opcional) e um
/// stepper de quantidade (`-` / valor / `+`). Recebe primitivos para nao
/// acoplar `lib/core` a modelos de feature.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.priceLabel,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.is18Plus = false,
  });

  final String name;
  final String priceLabel;
  final int quantity;
  final bool is18Plus;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: <Widget>[
                      Text(
                        priceLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (is18Plus) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        const AdultBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _QuantityStepper(
              quantity: quantity,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (quantity == 0) {
      return IconButton.filledTonal(
        icon: const Icon(Icons.add),
        tooltip: 'Adicionar ao pedido',
        onPressed: onAdd,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Remover uma unidade',
            onPressed: onRemove,
          ),
          Text('$quantity', style: theme.textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar uma unidade',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
