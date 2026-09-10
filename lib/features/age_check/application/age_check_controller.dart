import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/verify_contract.dart';
import '../data/verify_service.dart';

/// Fase da maquina de estados da verificacao de idade (specs, M3).
///
/// `idle → abrindoWallet → aguardando → verificando → success | underage |
/// expired | error`.
enum AgeCheckPhase {
  /// Nada em andamento; aguardando o usuario iniciar.
  idle,

  /// `POST /vp-request` enviado e carteira sendo aberta.
  abrindoWallet,

  /// Sessao ativa; fazendo polling de `status` (retornou `ACTIVE`).
  aguardando,

  /// `status == VP_SUBMITTED`; buscando o resultado.
  verificando,

  /// Credencial confirma 18+. Libera a compra.
  success,

  /// Credencial diz que e menor de 18. Bloqueia a compra (sem retry).
  underage,

  /// Sessao expirou antes da autorizacao. Permite retry.
  expired,

  /// Falha tratada (carteira ausente, rede, credencial invalida...). Permite
  /// retry.
  error,
}

/// Desfecho persistente da ultima verificacao concluida. Sobrevive a saida da
/// `AgeCheckPage` para o checkout (M1) consultar.
enum AgeCheckOutcome {
  /// 18+ confirmado.
  verified,

  /// Verificacao negou (menor de idade).
  blocked,
}

/// Identificadores de uma sessao de apresentacao em andamento.
@immutable
class AgeCheckSession {
  const AgeCheckSession({
    required this.transactionId,
    required this.requestId,
  });

  final String transactionId;
  final String requestId;

  @override
  bool operator ==(Object other) =>
      other is AgeCheckSession &&
      other.transactionId == transactionId &&
      other.requestId == requestId;

  @override
  int get hashCode => Object.hash(transactionId, requestId);
}

/// Estado imutavel exposto pelo [AgeCheckController].
@immutable
class AgeCheckState {
  const AgeCheckState({
    this.phase = AgeCheckPhase.idle,
    this.message,
    this.session,
    this.pollCount = 0,
  });

  final AgeCheckPhase phase;

  /// Texto para o usuario nos estados [AgeCheckPhase.expired] e
  /// [AgeCheckPhase.error]. `null` nos demais.
  final String? message;

  /// Sessao ativa (presente de [AgeCheckPhase.aguardando] em diante, ate um
  /// estado terminal ou [reset]).
  final AgeCheckSession? session;

  /// Numero de consultas de status ja feitas nesta sessao (feedback de UI).
  final int pollCount;

  bool get isBusy =>
      phase == AgeCheckPhase.abrindoWallet ||
      phase == AgeCheckPhase.aguardando ||
      phase == AgeCheckPhase.verificando;

  bool get isTerminal =>
      phase == AgeCheckPhase.success ||
      phase == AgeCheckPhase.underage ||
      phase == AgeCheckPhase.expired ||
      phase == AgeCheckPhase.error;

  /// `true` quando faz sentido oferecer "Tentar de novo".
  bool get canRetry =>
      phase == AgeCheckPhase.idle ||
      phase == AgeCheckPhase.expired ||
      phase == AgeCheckPhase.error;

  @override
  bool operator ==(Object other) =>
      other is AgeCheckState &&
      other.phase == phase &&
      other.message == message &&
      other.session == session &&
      other.pollCount == pollCount;

  @override
  int get hashCode => Object.hash(phase, message, session, pollCount);
}

/// Tempos do loop de polling. Provider proprio para os testes reduzirem o
/// intervalo a zero. Defaults iguais ao tutorial VerificaIdade
/// (`intervalMs = 2000`, `maxAttempts = 150` → ~5 min).
@immutable
class AgeCheckTiming {
  const AgeCheckTiming({
    this.pollInterval = const Duration(seconds: 2),
    this.maxPolls = 150,
  });

  /// Espera entre consultas de status enquanto o retorno e `ACTIVE`.
  final Duration pollInterval;

  /// Teto de consultas antes de desistir (≈ [pollInterval] × [maxPolls]).
  final int maxPolls;
}

/// [VerifyService] compartilhado pelo app. Em teste, sobrescreva com
/// `overrideWithValue` apontando para o mock do M4.
final Provider<VerifyService> verifyServiceProvider =
    Provider<VerifyService>((Ref ref) {
  final VerifyService service = VerifyService();
  ref.onDispose(service.dispose);
  return service;
});

final Provider<AgeCheckTiming> ageCheckTimingProvider =
    Provider<AgeCheckTiming>((Ref ref) => const AgeCheckTiming());

/// Resultado da ultima verificacao concluida (para o gate de checkout do M1).
final StateProvider<AgeCheckOutcome?> ageCheckOutcomeProvider =
    StateProvider<AgeCheckOutcome?>((Ref ref) => null);

/// Maquina de estados da verificacao de idade.
///
/// `autoDispose`: sair da `AgeCheckPage` zera tudo; a proxima entrada comeca
/// limpa. Enquanto a verificacao corre, a pagina permanece montada (a carteira
/// e outro app), entao o estado sobrevive ao ir/voltar do foreground.
final AutoDisposeNotifierProvider<AgeCheckController, AgeCheckState>
    ageCheckControllerProvider =
    NotifierProvider.autoDispose<AgeCheckController, AgeCheckState>(
  AgeCheckController.new,
);

class AgeCheckController extends AutoDisposeNotifier<AgeCheckState> {
  @override
  AgeCheckState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _wake();
    });
    return const AgeCheckState();
  }

  bool _disposed = false;

  /// Cada início/reinício de loop incrementa este contador. Um loop so continua
  /// enquanto a geracao que capturou ainda for a corrente — assim um loop
  /// antigo se encerra sozinho e nunca ha dois consultando em paralelo.
  int _generation = 0;

  int _activeLoops = 0;

  /// Sinal para o loop pular a espera restante e consultar o status agora
  /// (usado quando o app volta ao foreground).
  Completer<void>? _wakeSignal;

  /// Pico de loops simultaneos observado. Deve permanecer <= 1.
  @visibleForTesting
  int maxConcurrentLoops = 0;

  AgeCheckTiming get _timing => ref.read(ageCheckTimingProvider);

  VerifyService get _service => ref.read(verifyServiceProvider);

  // -----------------------------------------------------------------------
  // API publica
  // -----------------------------------------------------------------------

  /// Inicia o fluxo: `POST /vp-request` → abre a carteira → polling.
  Future<void> startVerification() async {
    if (_disposed || state.isBusy) return;

    ref.read(ageCheckOutcomeProvider.notifier).state = null;
    state = const AgeCheckState(phase: AgeCheckPhase.abrindoWallet);

    final AgeCheckSession session;
    try {
      final ({String requestId, String transactionId}) ids =
          await _service.createVpRequestAndOpenWallet();
      session = AgeCheckSession(
        transactionId: ids.transactionId,
        requestId: ids.requestId,
      );
    } on VerifyException catch (e) {
      _fail(e);
      return;
    }
    if (_disposed) return;

    state = AgeCheckState(
      phase: AgeCheckPhase.aguardando,
      session: session,
    );
    await _pollLoop();
  }

  /// "Tentar de novo" — so a partir de um estado nao ocupado.
  void retry() {
    if (_disposed || state.isBusy) return;
    unawaited(startVerification());
  }

  /// Volta ao estado inicial e encerra qualquer loop em curso.
  void reset() {
    if (_disposed) return;
    _generation++;
    _wake();
    state = const AgeCheckState();
  }

  /// Chamado pela `AgeCheckPage` quando o app volta ao foreground
  /// (`AppLifecycleState.resumed`).
  ///
  /// - Sem sessao ativa ou fora de [AgeCheckPhase.aguardando]: ignora.
  /// - Loop ja rodando: apenas o acorda para consultar imediatamente (nao cria
  ///   um segundo loop).
  /// - Nenhum loop rodando (ex.: isolate foi suspenso e o loop morreu):
  ///   inicia um novo.
  void onAppResumed() {
    if (_disposed) return;
    if (state.session == null || state.phase != AgeCheckPhase.aguardando) {
      return;
    }
    if (_activeLoops > 0) {
      _wake();
      return;
    }
    unawaited(_pollLoop());
  }

  // -----------------------------------------------------------------------
  // Loop de polling
  // -----------------------------------------------------------------------

  Future<void> _pollLoop() async {
    final int generation = ++_generation;
    _activeLoops++;
    if (_activeLoops > maxConcurrentLoops) maxConcurrentLoops = _activeLoops;

    try {
      var polls = state.pollCount;
      while (!_disposed && generation == _generation) {
        final AgeCheckSession? session = state.session;
        if (session == null) return;

        polls++;
        state = AgeCheckState(
          phase: AgeCheckPhase.aguardando,
          session: session,
          pollCount: polls,
        );

        final String status;
        try {
          status = await _service.pollStatus(session.requestId);
        } on VerifyException catch (e) {
          if (!_disposed && generation == _generation) _fail(e);
          return;
        }
        if (_disposed || generation != _generation) return;

        if (status == VpStatus.submitted) {
          await _fetchResult(session, generation);
          return;
        }
        if (status == VpStatus.expired) {
          _setExpired(
            'A sessao de verificacao expirou antes da autorizacao na carteira.',
          );
          return;
        }
        // status == ACTIVE
        if (polls >= _timing.maxPolls) {
          _setExpired(
            'Tempo esgotado aguardando a autorizacao na carteira.',
          );
          return;
        }
        await _sleep(_timing.pollInterval);
      }
    } finally {
      _activeLoops--;
    }
  }

  Future<void> _fetchResult(AgeCheckSession session, int generation) async {
    if (_disposed || generation != _generation) return;
    state = AgeCheckState(
      phase: AgeCheckPhase.verificando,
      session: session,
      pollCount: state.pollCount,
    );

    final ({bool underage, bool verified}) result;
    try {
      result = await _service.getResult(session.transactionId);
    } on VerifyException catch (e) {
      if (!_disposed && generation == _generation) _fail(e);
      return;
    }
    if (_disposed || generation != _generation) return;

    if (result.verified) {
      ref.read(ageCheckOutcomeProvider.notifier).state =
          AgeCheckOutcome.verified;
      state = const AgeCheckState(phase: AgeCheckPhase.success);
    } else {
      ref.read(ageCheckOutcomeProvider.notifier).state =
          AgeCheckOutcome.blocked;
      state = const AgeCheckState(phase: AgeCheckPhase.underage);
    }
  }

  /// Espera [interval], mas retorna antes se [_wake] for chamado.
  Future<void> _sleep(Duration interval) async {
    final Completer<void> wake = Completer<void>();
    _wakeSignal = wake;
    try {
      await Future.any<void>(<Future<void>>[
        Future<void>.delayed(interval),
        wake.future,
      ]);
    } finally {
      if (identical(_wakeSignal, wake)) _wakeSignal = null;
    }
  }

  void _wake() {
    final Completer<void>? signal = _wakeSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  void _setExpired(String message) {
    if (_disposed) return;
    state = AgeCheckState(phase: AgeCheckPhase.expired, message: message);
  }

  void _fail(VerifyException e) {
    if (_disposed) return;
    final AgeCheckPhase phase = switch (e) {
      VerificationExpiredException() => AgeCheckPhase.expired,
      WalletUnavailableException() => AgeCheckPhase.error,
      VerifyConfigException() => AgeCheckPhase.error,
      VerifyNetworkException() => AgeCheckPhase.error,
      VerifyResponseException() => AgeCheckPhase.error,
      CredentialInvalidException() => AgeCheckPhase.error,
      CredentialExpiredException() => AgeCheckPhase.error,
    };
    state = AgeCheckState(phase: phase, message: e.message);
  }
}
