import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import 'verify_contract.dart';

/// Desfecho simulado da verificacao. Controla o que os endpoints 2 e 3 do
/// contrato (plano, secao 4) devolvem — plano, secao 5, casos 1, 2, 3, 4 e 6.
enum VerifyScenario {
  /// Maior de 18: `isOver18 = true`, `vcStatus = SUCCESS`.
  over18,

  /// Menor de 18: `isOver18 = false`, `vcStatus = SUCCESS`.
  underage,

  /// Credencial invalida: `vcStatus = INVALID`.
  invalid,

  /// Credencial expirada: `vcStatus = EXPIRED`.
  expired,

  /// Sessao expira antes da autorizacao: status vira `EXPIRED` e nunca
  /// chega a `VP_SUBMITTED`.
  timeout,
}

/// Formato do campo `vc` na resposta de resultado. Existe para exercitar o
/// parsing defensivo do [VerifyService] (M2 / plano secao 4): `vc` pode vir
/// como Map ou como String JSON, e `credentialSubject` pode estar em
/// `vc.credentialSubject` ou em `vc.credential.credentialSubject`.
enum VcShape {
  /// `vc` e um Map com `credentialSubject` na raiz.
  mapDirect,

  /// `vc` e um Map com `credential.credentialSubject` aninhado.
  mapNested,

  /// `vc` e uma String contendo JSON (com `credentialSubject` na raiz).
  jsonString,
}

/// Mock local do INJI Verify Service.
///
/// Implementa [HttpClientAdapter] diretamente (so depende do `dio`, que ja e
/// dependencia de runtime) para nao arrastar pacote de teste para dentro de
/// `lib/` e para ter controle total sobre respostas que mudam a cada chamada
/// (o `status` retorna `ACTIVE` algumas vezes antes de `VP_SUBMITTED`).
///
/// Uso tipico:
/// ```dart
/// final mock = VerifyMockServer.createDio(scenario: VerifyScenario.over18);
/// final service = VerifyService(dio: mock.dio); // M2
/// // ...
/// mock.server.scenario = VerifyScenario.underage; // troca de cenario
/// mock.server.reset();                            // zera contadores
/// ```
class VerifyMockServer implements HttpClientAdapter {
  VerifyMockServer({
    this.scenario = VerifyScenario.over18,
    this.vcShape = VcShape.mapDirect,
    int activePolls = 2,
    this.latency,
    String publicBaseUrl = 'https://verify.mock.local',
    String? clientId,
  })  : assert(activePolls >= 0),
        _activePolls = activePolls,
        _publicBaseUrl = _stripTrailingSlash(publicBaseUrl),
        _fallbackClientId = clientId ?? AppConfig.clientId;

  /// Base "publica" usada para montar `requestUri` / `responseUri` nas
  /// respostas — nao precisa ser alcancavel; e so o que a wallet receberia.
  final String _publicBaseUrl;

  /// `clientId` devolvido quando o corpo do POST nao traz um.
  final String _fallbackClientId;

  /// Quantas respostas `ACTIVE` o `status` devolve antes de avancar.
  final int _activePolls;

  /// Formato do campo `vc` no resultado.
  VcShape vcShape;

  /// Atraso opcional aplicado a toda resposta (util para testar timeouts /
  /// estados de carregamento da UI).
  Duration? latency;

  /// Cenario corrente. Trocar aqui afeta apenas sessoes criadas a partir de
  /// entao; sessoes ja abertas mantem o cenario com que nasceram.
  VerifyScenario scenario;

  int _sessionCounter = 0;
  final Map<String, _MockSession> _byRequestId = <String, _MockSession>{};
  final Map<String, _MockSession> _byTransactionId = <String, _MockSession>{};
  final Map<String, int> _pollCounts = <String, int>{};

  bool _closed = false;

  /// Liga este mock a um [dio] existente.
  void attachTo(Dio dio) => dio.httpClientAdapter = this;

  /// Zera contadores e sessoes. Nao mexe em [scenario] nem [vcShape].
  void reset() {
    _sessionCounter = 0;
    _byRequestId.clear();
    _byTransactionId.clear();
    _pollCounts.clear();
  }

  /// Cria um [Dio] ja configurado com este mock e devolve os dois, para que o
  /// teste possa trocar o cenario / resetar contadores depois.
  static ({Dio dio, VerifyMockServer server}) createDio({
    VerifyScenario scenario = VerifyScenario.over18,
    VcShape vcShape = VcShape.mapDirect,
    int activePolls = 2,
    Duration? latency,
    String? baseUrl,
    String publicBaseUrl = 'https://verify.mock.local',
    String? clientId,
  }) {
    final VerifyMockServer server = VerifyMockServer(
      scenario: scenario,
      vcShape: vcShape,
      activePolls: activePolls,
      latency: latency,
      publicBaseUrl: publicBaseUrl,
      clientId: clientId,
    );
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.verifyBaseUrl,
        // Aceita 2xx e 4xx sem lancar: a UI decide o que fazer com o corpo.
        validateStatus: (int? code) => code != null && code < 500,
      ),
    );
    server.attachTo(dio);
    return (dio: dio, server: server);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'VerifyMockServer fechado',
      );
    }

    if (latency != null) {
      await Future<void>.delayed(latency!);
    }

    final String path = options.uri.path;
    final String method = options.method.toUpperCase();

    if (method == 'GET' && VerifyEndpoints.healthPattern.hasMatch(path)) {
      return _ok(_handleHealth());
    }

    if (method == 'POST' && VerifyEndpoints.vpRequestPattern.hasMatch(path)) {
      return _ok(_handleVpRequest(options));
    }

    final RegExpMatch? statusMatch =
        VerifyEndpoints.statusPattern.firstMatch(path);
    if (method == 'GET' && statusMatch != null) {
      return _ok(_handleStatus(statusMatch.group(1)!));
    }

    final RegExpMatch? resultMatch =
        VerifyEndpoints.resultPattern.firstMatch(path);
    if (method == 'GET' && resultMatch != null) {
      return _ok(_handleResult(resultMatch.group(1)!));
    }

    return _error(404, 'Sem rota simulada para $method $path');
  }

  @override
  void close({bool force = false}) => _closed = true;

  // --- Handlers -------------------------------------------------------------

  Map<String, dynamic> _handleVpRequest(RequestOptions options) {
    final int n = ++_sessionCounter;
    final String tag = scenario.name;
    final String requestId = 'req-$tag-$n';
    final String transactionId = 'txn-$tag-$n';

    final Object? body = options.data;
    final String clientId =
        (body is Map && body[VerifyFields.clientId] is String)
            ? body[VerifyFields.clientId] as String
            : _fallbackClientId;

    final _MockSession session = _MockSession(
      scenario: scenario,
      requestId: requestId,
      transactionId: transactionId,
    );
    _byRequestId[requestId] = session;
    _byTransactionId[transactionId] = session;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // Shape do tutorial (api-reference.html): `requestUri` no topo; `expiresAt`
    // e `issuedAt` em epoch ms; authorizationDetails com responseType/Mode.
    return <String, dynamic>{
      VerifyFields.transactionId: transactionId,
      VerifyFields.requestId: requestId,
      VerifyFields.requestUri:
          '$_publicBaseUrl${VerifyEndpoints.context}/vp-request/$requestId',
      VerifyFields.authorizationDetails: <String, dynamic>{
        VerifyFields.clientId: clientId,
        VerifyFields.nonce: 'nonce-$n-${DateTime.now().microsecondsSinceEpoch}',
        VerifyFields.responseUri:
            '$_publicBaseUrl${VerifyEndpoints.vpSubmission}',
        VerifyFields.responseType: 'vp_token',
        VerifyFields.responseMode: 'direct_post',
        VerifyFields.issuedAt: nowMs,
      },
      VerifyFields.expiresAt: nowMs + 300000,
    };
  }

  Map<String, dynamic> _handleHealth() => <String, dynamic>{
        VerifyFields.status: 'UP',
      };

  Map<String, dynamic> _handleStatus(String requestId) {
    final _MockSession? session = _byRequestId[requestId];
    final VerifyScenario sessionScenario = session?.scenario ?? scenario;
    final int polls = _pollCounts.update(
      requestId,
      (int v) => v + 1,
      ifAbsent: () => 1,
    );

    final String status;
    if (polls <= _activePolls) {
      status = VpStatus.active;
    } else if (sessionScenario == VerifyScenario.timeout) {
      status = VpStatus.expired;
    } else {
      status = VpStatus.submitted;
    }

    return <String, dynamic>{
      VerifyFields.requestId: requestId,
      VerifyFields.status: status,
    };
  }

  Map<String, dynamic> _handleResult(String transactionId) {
    final _MockSession? session = _byTransactionId[transactionId];
    final VerifyScenario sessionScenario = session?.scenario ?? scenario;

    switch (sessionScenario) {
      case VerifyScenario.over18:
        return _resultBody(
          transactionId: transactionId,
          vpResultStatus: VpResultStatus.success,
          vcStatus: VcStatus.success,
          isOver18: true,
        );
      case VerifyScenario.underage:
        return _resultBody(
          transactionId: transactionId,
          vpResultStatus: VpResultStatus.success,
          vcStatus: VcStatus.success,
          isOver18: false,
        );
      case VerifyScenario.invalid:
        return _resultBody(
          transactionId: transactionId,
          vpResultStatus: VpResultStatus.success,
          vcStatus: VcStatus.invalid,
          isOver18: null,
        );
      case VerifyScenario.expired:
        return _resultBody(
          transactionId: transactionId,
          vpResultStatus: VpResultStatus.success,
          vcStatus: VcStatus.expired,
          isOver18: null,
        );
      case VerifyScenario.timeout:
        // A sessao nunca foi submetida — nao ha credencial para avaliar.
        return <String, dynamic>{
          VerifyFields.transactionId: transactionId,
          VerifyFields.vpResultStatus: VpResultStatus.expired,
          VerifyFields.vcResults: <dynamic>[],
        };
    }
  }

  Map<String, dynamic> _resultBody({
    required String transactionId,
    required String vpResultStatus,
    required String vcStatus,
    required bool? isOver18,
  }) {
    return <String, dynamic>{
      VerifyFields.transactionId: transactionId,
      VerifyFields.vpResultStatus: vpResultStatus,
      VerifyFields.vcResults: <dynamic>[
        <String, dynamic>{
          VerifyFields.vc: _buildVc(isOver18),
          VerifyFields.vcStatus: vcStatus,
        },
      ],
    };
  }

  /// Monta o campo `vc` no formato pedido por [vcShape].
  Object _buildVc(bool? isOver18) {
    final Map<String, dynamic> subject = <String, dynamic>{
      'id': 'did:example:holder-${scenario.name}',
      if (isOver18 != null) VerifyFields.isOver18: isOver18,
    };
    final Map<String, dynamic> vcCore = <String, dynamic>{
      VerifyFields.type: <String>['VerifiableCredential', kEcaCredentialType],
      'issuer': 'did:gov:br:verificaidade:sandbox',
      'issuanceDate': '2026-01-01T00:00:00Z',
    };

    switch (vcShape) {
      case VcShape.mapDirect:
        return <String, dynamic>{
          ...vcCore,
          VerifyFields.credentialSubject: subject,
        };
      case VcShape.mapNested:
        return <String, dynamic>{
          ...vcCore,
          VerifyFields.credential: <String, dynamic>{
            ...vcCore,
            VerifyFields.credentialSubject: subject,
          },
        };
      case VcShape.jsonString:
        return jsonEncode(<String, dynamic>{
          ...vcCore,
          VerifyFields.credentialSubject: subject,
        });
    }
  }

  // --- ResponseBody helpers ----------------------------------------------

  ResponseBody _ok(Map<String, dynamic> body) => _json(200, body);

  ResponseBody _error(int status, String message) =>
      _json(status, <String, dynamic>{'error': message});

  ResponseBody _json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// Estado de uma sessao de verificacao criada por um `POST /vp-request`.
class _MockSession {
  _MockSession({
    required this.scenario,
    required this.requestId,
    required this.transactionId,
  });

  final VerifyScenario scenario;
  final String requestId;
  final String transactionId;
}
