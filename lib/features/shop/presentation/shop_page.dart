import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/widgets.dart';
import '../../age_check/application/age_check_controller.dart';
import '../application/cart_controller.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

/// Casca de simulacao de compra.
///
/// Lista de produtos mock + carrinho. "Finalizar compra":
/// - pedido com item 18+  -> vai para `/verify` (modulo de verificacao, M3);
/// - senao                -> dialogo "Compra concluida".
///
/// Ao voltar de `/verify`, consome o [ageCheckOutcomeProvider]: `verified`
/// conclui a compra; `blocked` remove os itens 18+ do pedido.
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  ProviderSubscription<AgeCheckOutcome?>? _outcomeSub;

  @override
  void initState() {
    super.initState();
    // `fireImmediately` cobre o caso real (voltamos de /verify com o resultado
    // ja definido e a ShopPage recem-montada); as mudancas seguintes cobrem o
    // caso em que ambas as telas coexistem.
    _outcomeSub = ref.listenManual<AgeCheckOutcome?>(
      ageCheckOutcomeProvider,
      (AgeCheckOutcome? _, AgeCheckOutcome? next) => _onOutcome(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _outcomeSub?.close();
    super.dispose();
  }

  void _onOutcome(AgeCheckOutcome? outcome) {
    if (outcome == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AgeCheckOutcome? current = ref.read(ageCheckOutcomeProvider);
      if (current == null) return;
      ref.read(ageCheckOutcomeProvider.notifier).state = null;

      switch (current) {
        case AgeCheckOutcome.verified:
          ref.read(cartControllerProvider.notifier).clear();
          _showInfoDialog(
            title: 'Compra concluida',
            message: 'Idade verificada. Seu pedido foi finalizado.',
          );
        case AgeCheckOutcome.blocked:
          ref.read(cartControllerProvider.notifier).removeAdultItems();
          _showInfoDialog(
            title: 'Itens removidos',
            message: 'A verificacao de idade nao foi concluida. Os itens 18+ '
                'foram removidos do seu pedido.',
          );
      }
    });
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    VoidCallback? onDismissed,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    onDismissed?.call();
  }

  void _onFinalize() {
    final CartState cart = ref.read(cartControllerProvider);
    if (cart.isEmpty) return;

    if (cart.hasAdultItem) {
      context.go(AppRoutes.verify);
      return;
    }
    _showInfoDialog(
      title: 'Compra concluida',
      message: 'Seu pedido foi finalizado.',
      onDismissed: () {
        if (mounted) ref.read(cartControllerProvider.notifier).clear();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> catalog = ref.watch(catalogProvider);
    final CartState cart = ref.watch(cartControllerProvider);
    final CartController controller = ref.read(cartControllerProvider.notifier);

    final bool showAdultBanner = cart.hasAdultItem;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja'),
        actions: <Widget>[
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet),
              tooltip: 'Diagnostico',
              onPressed: () => context.push(AppRoutes.diagnostics),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          itemCount: catalog.length + (showAdultBanner ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) {
            if (showAdultBanner && index == 0) {
              return const AppBanner(
                kind: AppBannerKind.info,
                message: 'Seu pedido tem item 18+. Ao finalizar, sera pedida a '
                    'verificacao de idade.',
              );
            }
            final Product product =
                catalog[showAdultBanner ? index - 1 : index];
            return ProductCard(
              name: product.nome,
              priceLabel: formatBrl(product.preco),
              is18Plus: product.is18Plus,
              quantity: cart.quantityOf(product.id),
              onAdd: () => controller.add(product),
              onRemove: () => controller.remove(product),
            );
          },
        ),
      ),
      bottomNavigationBar: _CheckoutBar(
        total: cart.total,
        itemCount: cart.itemCount,
        onFinalize: cart.isEmpty ? null : _onFinalize,
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.itemCount,
    required this.onFinalize,
  });

  final double total;
  final int itemCount;
  final VoidCallback? onFinalize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    itemCount == 1 ? '1 item' : '$itemCount itens',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatBrl(total),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Finalizar compra',
                  onPressed: onFinalize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
