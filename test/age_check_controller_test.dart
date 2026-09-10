import 'dart:async';

import 'package:app_idade18/features/age_check/application/age_check_controller.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:app_idade18/features/age_check/data/verify_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um container com o [VerifyService] apontando para o mock do M4 e o
/// intervalo de polling zerado, para os testes rodarem sem espera real.
ProviderContainer _container({
  required VerifyScenario scenario,
  int activePolls = 2,
  bool walletOpens = true,
  Duration pollInterval = Duration.zero,
  int maxPolls = 30,
}) {
  final ({Dio dio, VerifyMockServer server}) mock = VerifyMockServer.createDio(
    scenario: scenario,
    activePolls: activePolls,
  );
  final VerifyService service = VerifyService(
    dio: mock.dio,
    uriLauncher: (_) async => walletOpens,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      verifyServiceProvider.overrideWithValue(service),
      ageCheckTimingProvider.overrideWithValue(
        AgeCheckTiming(pollInterval: pollInterval, maxPolls: maxPolls),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Mantem o provider autoDispose vivo entre os `read` do teste (numa tela
  // real quem faz isso e o `ref.watch` da AgeCheckPage).
  container.listen(ageCheckControllerProvider, (_, __) {});
  return container;
}

void main() {
  group('startVerification — desfechos', () {
    test('over18: chega a success e grava outcome verified', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 2,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.success);
      expect(c.read(ageCheckOutcomeProvider), AgeCheckOutcome.verified);
    });

    test('underage: chega a underage e grava outcome blocked', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.underage,
        activePolls: 1,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.underage);
      expect(c.read(ageCheckOutcomeProvider), AgeCheckOutcome.blocked);
    });

    test('invalid: cai em error com mensagem', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.invalid,
        activePolls: 1,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      final AgeCheckState s = c.read(ageCheckControllerProvider);
      expect(s.phase, AgeCheckPhase.error);
      expect(s.message, isNotNull);
      expect(c.read(ageCheckOutcomeProvider), isNull);
    });

    test('timeout (status EXPIRED): cai em expired', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.timeout,
        activePolls: 1,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.expired);
    });

    test('maxPolls atingido sem VP_SUBMITTED: expired', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 1000,
        maxPolls: 3,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.expired);
    });

    test('carteira nao abre: error', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        walletOpens: false,
      );

      await c.read(ageCheckControllerProvider.notifier).startVerification();

      final AgeCheckState s = c.read(ageCheckControllerProvider);
      expect(s.phase, AgeCheckPhase.error);
      expect(s.message, contains('carteira'));
    });

    test('nao reentra se ja estiver ocupado', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 1000,
        pollInterval: const Duration(milliseconds: 5),
      );
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      unawaited(ctrl.startVerification());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // segunda chamada enquanto aguardando -> ignorada
      await ctrl.startVerification();

      expect(
          c.read(ageCheckControllerProvider).phase, AgeCheckPhase.aguardando);
      expect(ctrl.maxConcurrentLoops, 1);
    });
  });

  group('onAppResumed — sem duplicar loops', () {
    test('varias chamadas durante o polling nao criam um segundo loop',
        () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 1000,
        pollInterval: const Duration(milliseconds: 10),
      );
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      unawaited(ctrl.startVerification());
      await Future<void>.delayed(const Duration(milliseconds: 25));

      for (int i = 0; i < 5; i++) {
        ctrl.onAppResumed();
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(ctrl.maxConcurrentLoops, 1);
      expect(
          c.read(ageCheckControllerProvider).phase, AgeCheckPhase.aguardando);
    });

    test(
        'acorda o loop: com wake, o polling avanca mais rapido que o intervalo',
        () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 1000,
        pollInterval: const Duration(seconds: 30),
      );
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      unawaited(ctrl.startVerification());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final int pollsBefore = c.read(ageCheckControllerProvider).pollCount;

      // Sem wake, o proximo poll so viria daqui a 30s. Com wake, vem agora.
      ctrl.onAppResumed();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        c.read(ageCheckControllerProvider).pollCount,
        greaterThan(pollsBefore),
      );
      expect(ctrl.maxConcurrentLoops, 1);
    });

    test('ignora quando nao ha sessao ativa', () {
      final ProviderContainer c = _container(scenario: VerifyScenario.over18);
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      ctrl.onAppResumed();

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.idle);
      expect(ctrl.maxConcurrentLoops, 0);
    });
  });

  group('retry e reset', () {
    test('retry a partir de error leva a novo desfecho', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(
        scenario: VerifyScenario.invalid,
        activePolls: 1,
      );
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: (_) async => true,
      );
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          verifyServiceProvider.overrideWithValue(service),
          ageCheckTimingProvider.overrideWithValue(
            const AgeCheckTiming(pollInterval: Duration.zero, maxPolls: 30),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(ageCheckControllerProvider, (_, __) {});
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      await ctrl.startVerification();
      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.error);

      mock.server.scenario = VerifyScenario.over18;
      mock.server.reset();

      ctrl.retry();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.success);
    });

    test('reset volta para idle', () async {
      final ProviderContainer c = _container(
        scenario: VerifyScenario.over18,
        activePolls: 1,
      );
      final AgeCheckController ctrl =
          c.read(ageCheckControllerProvider.notifier);

      await ctrl.startVerification();
      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.success);

      ctrl.reset();
      expect(c.read(ageCheckControllerProvider).phase, AgeCheckPhase.idle);
      expect(c.read(ageCheckControllerProvider).session, isNull);
    });
  });
}
