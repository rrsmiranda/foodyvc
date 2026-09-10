import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/age_check/application/age_check_controller.dart';
import '../features/age_check/data/verify_mock_server.dart';
import '../features/shop/application/cart_controller.dart';

/// Instancia do mock do M4 usada pela demo. Sobrescrito em `main_demo.dart`.
final Provider<VerifyMockServer> demoMockServerProvider =
    Provider<VerifyMockServer>(
  (Ref ref) => throw UnimplementedError('override em main_demo.dart'),
);

/// Cenario selecionado no painel da demo (so para a UI refletir a escolha).
final StateProvider<VerifyScenario> demoScenarioProvider =
    StateProvider<VerifyScenario>((Ref ref) => VerifyScenario.over18);

/// App da demo: o `AppIdade18` real, mais um painel flutuante para escolher o
/// cenario do mock (maior/menor de 18, credencial invalida/expirada, timeout).
class DemoApp extends ConsumerWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Idade 18+ (demo)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            if (child != null) child,
            const Positioned(
              right: 16,
              bottom: 96,
              child: SafeArea(child: _DemoFab()),
            ),
          ],
        );
      },
    );
  }
}

class _DemoFab extends ConsumerWidget {
  const _DemoFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VerifyScenario current = ref.watch(demoScenarioProvider);
    return FloatingActionButton.extended(
      heroTag: 'demo-fab',
      icon: const Icon(Icons.science_outlined),
      label: Text('Demo: ${_label(current)}'),
      onPressed: () => _openSheet(context, ref),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Cenario da verificacao',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha antes de tocar em "Verificar idade". O mock do M4 '
                'responde os 3 endpoints conforme o cenario.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final VerifyScenario current =
                      ref.watch(demoScenarioProvider);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final VerifyScenario s in VerifyScenario.values)
                        ChoiceChip(
                          label: Text(_label(s)),
                          selected: current == s,
                          onSelected: (_) {
                            final VerifyMockServer server =
                                ref.read(demoMockServerProvider);
                            server.scenario = s;
                            server.reset();
                            ref.read(demoScenarioProvider.notifier).state = s;
                            ref
                                .read(ageCheckControllerProvider.notifier)
                                .reset();
                            ref.read(ageCheckOutcomeProvider.notifier).state =
                                null;
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Zerar carrinho e verificacao'),
                  onPressed: () {
                    ref.read(cartControllerProvider.notifier).clear();
                    ref.read(ageCheckControllerProvider.notifier).reset();
                    ref.read(ageCheckOutcomeProvider.notifier).state = null;
                    ref.read(demoMockServerProvider).reset();
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _label(VerifyScenario s) => switch (s) {
        VerifyScenario.over18 => 'maior de 18',
        VerifyScenario.underage => 'menor de 18',
        VerifyScenario.invalid => 'credencial invalida',
        VerifyScenario.expired => 'credencial expirada',
        VerifyScenario.timeout => 'sessao expira (timeout)',
      };
}
