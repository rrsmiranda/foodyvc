import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/age_check/presentation/age_check_page.dart';
import '../../features/diagnostics/diagnostics_page.dart';
import '../../features/shop/presentation/shop_page.dart';

/// Rotas da aplicacao: casca de compra, modulo de verificacao de idade
/// (o produto) e a tela de diagnostico para QA.
class AppRoutes {
  const AppRoutes._();

  static const String shop = '/';
  static const String shopName = 'shop';

  static const String verify = '/verify';
  static const String verifyName = 'verify';

  static const String diagnostics = '/diag';
  static const String diagnosticsName = 'diag';
}

/// Router exposto via Riverpod para que qualquer camada possa navegar sem
/// depender de um singleton global.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.shop,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.shop,
        name: AppRoutes.shopName,
        builder: (BuildContext context, GoRouterState state) =>
            const ShopPage(),
      ),
      GoRoute(
        path: AppRoutes.verify,
        name: AppRoutes.verifyName,
        builder: (BuildContext context, GoRouterState state) =>
            const AgeCheckPage(),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        name: AppRoutes.diagnosticsName,
        builder: (BuildContext context, GoRouterState state) =>
            const DiagnosticsPage(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Rota nao encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'Nao existe rota para "${state.uri}".',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.shop),
                child: const Text('Voltar para a loja'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
