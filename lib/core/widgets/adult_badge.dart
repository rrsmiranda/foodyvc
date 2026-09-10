import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Selo "18+" — marca o item que dispara a verificacao de idade no checkout.
class AdultBadge extends StatelessWidget {
  const AdultBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Item para maiores de 18 anos',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          '18+',
          style: TextStyle(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            height: 1,
          ),
        ),
      ),
    );
  }
}
