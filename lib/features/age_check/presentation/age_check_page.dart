import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/widgets.dart';
import '../application/age_check_controller.dart';

/// Nota fixa mostrada durante o polling: o retorno depende do foreground.
const String _kWalletHint =
    'Se a carteira nao abrir, volte a este app e aguarde — a verificacao '
    'continua automaticamente.';

/// Modulo de verificacao de idade (OID4VP).
///
/// Orquestra a maquina de estados do [AgeCheckController] e retoma o polling
/// quando o app volta ao foreground (`AppLifecycleState.resumed`), que e o
/// mecanismo central do fluxo same-device (plano, secao 2).
class AgeCheckPage extends ConsumerStatefulWidget {
  const AgeCheckPage({super.key});

  @override
  ConsumerState<AgeCheckPage> createState() => _AgeCheckPageState();
}

class _AgeCheckPageState extends ConsumerState<AgeCheckPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(ageCheckControllerProvider.notifier).onAppResumed();
    }
  }

  void _goToShop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.shop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AgeCheckState state = ref.watch(ageCheckControllerProvider);
    final AgeCheckController controller =
        ref.read(ageCheckControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificacao de idade'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToShop,
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.adaptive(context, AppMotion.normal),
          child: AgeCheckStatusView(
            key: ValueKey<AgeCheckPhase>(state.phase),
            state: state,
            onVerify: controller.startVerification,
            onRetry: controller.retry,
            onDone: _goToShop,
          ),
        ),
      ),
    );
  }
}

/// Parte puramente visual da verificacao: recebe um [AgeCheckState] e tres
/// callbacks e renderiza a tela do estado corrente com o [StatusView] do design
/// system. Sem Riverpod nem lifecycle — cada estado e testavel isoladamente.
class AgeCheckStatusView extends StatelessWidget {
  const AgeCheckStatusView({
    super.key,
    required this.state,
    required this.onVerify,
    required this.onRetry,
    required this.onDone,
  });

  final AgeCheckState state;
  final VoidCallback onVerify;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return switch (state.phase) {
      AgeCheckPhase.idle => StatusView(
          icon: Icons.verified_user_outlined,
          tone: StatusTone.info,
          title: 'Verificacao de idade',
          description:
              'Este item exige comprovacao de maioridade. Voce sera levado a '
              'sua carteira digital para autorizar a apresentacao da '
              'credencial. O app recebe apenas se voce tem 18 anos ou mais — '
              'nenhum outro dado pessoal.',
          primaryLabel: 'Verificar idade',
          onPrimary: onVerify,
        ),
      AgeCheckPhase.abrindoWallet => const StatusView(
          busy: true,
          title: 'Abrindo a carteira digital',
          description: 'Autorize a apresentacao da credencial na carteira.',
          footnote: _kWalletHint,
        ),
      AgeCheckPhase.aguardando => StatusView(
          busy: true,
          title: 'Aguardando autorizacao',
          description: 'Confirme a apresentacao na sua carteira digital.',
          footnote: state.pollCount > 0
              ? 'Verificando... (consulta ${state.pollCount})'
              : _kWalletHint,
        ),
      AgeCheckPhase.verificando => const StatusView(
          busy: true,
          title: 'Confirmando o resultado...',
        ),
      AgeCheckPhase.success => StatusView(
          icon: Icons.check_circle,
          tone: StatusTone.success,
          title: 'Idade confirmada',
          description: 'Voce tem 18 anos ou mais. A compra esta liberada.',
          primaryLabel: 'Concluir compra',
          onPrimary: onDone,
        ),
      AgeCheckPhase.underage => StatusView(
          icon: Icons.block,
          tone: StatusTone.danger,
          title: 'Compra nao autorizada',
          description: 'A verificacao indicou que voce e menor de 18 anos. '
              'Este item nao pode ser adquirido.',
          primaryLabel: 'Voltar a loja',
          onPrimary: onDone,
        ),
      AgeCheckPhase.expired => StatusView(
          icon: Icons.timer_off_outlined,
          tone: StatusTone.warning,
          title: 'Sessao expirada',
          description: 'A autorizacao na carteira demorou demais.',
          primaryLabel: 'Tentar de novo',
          onPrimary: onRetry,
          secondaryLabel: 'Voltar a loja',
          onSecondary: onDone,
          child: AppBanner(
            kind: AppBannerKind.warning,
            message: state.message ??
                'A sessao de verificacao expirou. Tente novamente.',
          ),
        ),
      AgeCheckPhase.error => StatusView(
          icon: Icons.error_outline,
          tone: StatusTone.danger,
          title: 'Nao foi possivel verificar',
          description: 'Revise a mensagem abaixo e tente novamente.',
          primaryLabel: 'Tentar de novo',
          onPrimary: onRetry,
          secondaryLabel: 'Voltar a loja',
          onSecondary: onDone,
          child: AppBanner(
            kind: AppBannerKind.error,
            message: state.message ??
                'Algo deu errado durante a verificacao. Tente novamente.',
          ),
        ),
    };
  }
}
