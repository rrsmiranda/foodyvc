import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../../core/config/app_config.dart';
import 'verify_contract.dart';

/// Assinatura do abridor de deep link. Injetavel para teste; em producao
/// aponta para `launchUrl` do `url_launcher`.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// Cliente REST do INJI Verify Service (relying party OID4VP).
///
/// Segue o tutorial oficial VerificaIdade (quickstart + integra-web +
/// api-reference). Passos:
/// 1. [createVpRequestAndOpenWallet] — `POST /vp-request` (PD completa no corpo)
///    + abre a Inji Wallet via `openid4vp://authorize?client_id=&request_uri=`.
/// 2. [pollStatus] — `GET /vp-request/{requestId}/status`.
/// 3. [getResult] — `GET /vp-result/{transactionId}`, com parsing defensivo.
/// + [checkHealth] — `GET /actuator/health`.
///
/// Sem cabecalhos de autenticacao — a identidade vai no corpo (`clientId`).
/// LGPD (plano, secao 6): o servico devolve **apenas** o booleano de maioridade.
/// Nao retorna, nao registra e nao persiste a credencial crua nem qualquer PII.
class VerifyService {
  factory VerifyService({
    Dio? dio,
    VerifyConfig? config,
    UriLauncher? uriLauncher,
  }) {
    final VerifyConfig resolved = config ?? VerifyConfig.fromAppConfig();

    if (dio == null && resolved.baseUrl == AppConfig.verifyBaseUrlSentinel) {
      throw const VerifyConfigException(
        'VERIFY_BASE_URL nao foi configurado (rodando com o default '
        '"https://verify.invalid", que nunca resolve). Rode com '
        '--dart-define-from-file=config/local.json (ex.: "make run") em vez '
        'de iniciar direto pelo Xcode/Android Studio sem esse argumento.',
      );
    }

    if (dio == null && !resolved.allowInsecure) {
      final Uri? parsed = Uri.tryParse(resolved.baseUrl);
      final String host = parsed?.host ?? '';
      final bool isLocal = host == 'localhost' ||
          host == '127.0.0.1' ||
          host.endsWith('.local') ||
          host.endsWith('.invalid');
      if (!resolved.baseUrl.startsWith('https://') && !isLocal) {
        throw VerifyConfigException(
          'VERIFY_BASE_URL precisa usar https:// (recebido: "${resolved.baseUrl}"). '
          'Para testar em LAN sem TLS use --dart-define=VERIFY_ALLOW_INSECURE=true.',
        );
      }
    }

    return VerifyService._(
      config: resolved,
      dio: dio ?? _buildDio(resolved),
      ownsDio: dio == null,
      uriLauncher: uriLauncher ?? _launchExternal,
    );
  }

  VerifyService._({
    required VerifyConfig config,
    required Dio dio,
    required bool ownsDio,
    required UriLauncher uriLauncher,
  })  : _config = config,
        _dio = dio,
        _ownsDio = ownsDio,
        _uriLauncher = uriLauncher;

  final VerifyConfig _config;
  final Dio _dio;
  final bool _ownsDio;
  final UriLauncher _uriLauncher;

  VerifyConfig get config => _config;

  /// Janela do long-poll do `/status` no INJI Verify Service (mede ~55s;
  /// devolve na hora quando o estado muda). O timeout de recepcao da chamada
  /// de status usa esta duracao + margem.
  static const Duration kStatusLongPollWindow = Duration(seconds: 70);

  static Dio _buildDio(VerifyConfig config) => Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          contentType: Headers.jsonContentType,
          headers: const <String, dynamic>{'Accept': Headers.jsonContentType},
          // A camada de UI decide o que fazer com respostas 4xx.
          validateStatus: (int? code) => code != null && code < 500,
        ),
      );

  static Future<bool> _launchExternal(Uri uri) => url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );

  // -----------------------------------------------------------------------
  // 1. Criar VP Request + abrir a carteira
  // -----------------------------------------------------------------------

  /// `POST /vp-request`, monta `openid4vp://authorize?...` a partir do
  /// `authorizationDetails` e abre a Inji Wallet.
  ///
  /// Lanca:
  /// - [WalletUnavailableException] se a carteira nao puder ser aberta.
  /// - [VerifyNetworkException] em falha de rede / HTTP >= 300.
  /// - [VerifyResponseException] se a resposta nao trouxer os campos minimos.
  Future<({String transactionId, String requestId})>
      createVpRequestAndOpenWallet() async {
    final Response<dynamic> res = await _send(
      () => _dio.post<dynamic>(
        VerifyEndpoints.vpRequest,
        data: <String, dynamic>{
          VerifyFields.clientId: _config.clientId,
          VerifyFields.presentationDefinition: _config.presentationDefinition,
        },
      ),
      action: 'criar a solicitacao de verificacao',
    );

    final Map<String, dynamic> body = _asMap(res.data, context: 'vp-request');
    final String? transactionId = _asNonEmptyString(
      body[VerifyFields.transactionId],
    );
    final String? requestId = _asNonEmptyString(body[VerifyFields.requestId]);

    final Map<String, dynamic> auth =
        body[VerifyFields.authorizationDetails] is Map
            ? _asMap(body[VerifyFields.authorizationDetails],
                context: 'authDetails')
            : const <String, dynamic>{};

    // `requestUri` vem no topo da resposta (integra-web.html); alguns
    // deployments repetem em authorizationDetails — aceitamos os dois.
    final String? requestUri = _asNonEmptyString(
      body[VerifyFields.requestUri] ??
          auth[VerifyFields.requestUri] ??
          auth['request_uri'],
    );
    final String clientId = _asNonEmptyString(
          auth[VerifyFields.clientId] ?? auth['client_id'],
        ) ??
        _config.clientId;

    if (transactionId == null || requestId == null || requestUri == null) {
      throw const VerifyResponseException(
        'Resposta de vp-request sem transactionId, requestId ou requestUri.',
      );
    }

    // Deep link do tutorial: apenas client_id + request_uri. `origin` e uma
    // extensao para o retorno same-device — enviado so se configurado.
    final Map<String, String> query = <String, String>{
      'client_id': clientId,
      'request_uri': requestUri,
      if (_config.sendOrigin) 'origin': _config.origin,
    };
    final Uri walletUri = Uri.parse(AppConfig.walletAuthorizeUrl).replace(
      queryParameters: query,
    );

    bool launched;
    try {
      launched = await _uriLauncher(walletUri);
    } catch (_) {
      throw const WalletUnavailableException();
    }
    if (!launched) {
      throw const WalletUnavailableException();
    }

    return (transactionId: transactionId, requestId: requestId);
  }

  // -----------------------------------------------------------------------
  // 2. Polling de status
  // -----------------------------------------------------------------------

  /// `GET /vp-request/{requestId}/status` → `ACTIVE | VP_SUBMITTED | EXPIRED`
  /// (sempre em maiusculas).
  ///
  /// O INJI Verify Service faz **long-polling**: segura a conexao ~55s e so
  /// responde na hora quando o estado muda. Por isso a chamada usa um
  /// `receiveTimeout` maior ([kStatusLongPollWindow]); se ainda assim estourar,
  /// tratamos como "sem mudanca" (`ACTIVE`) e o loop chama de novo — nao e erro.
  Future<String> pollStatus(String requestId) async {
    final Response<dynamic> res;
    try {
      res = await _dio.get<dynamic>(
        VerifyEndpoints.status(requestId),
        options: Options(receiveTimeout: kStatusLongPollWindow),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return VpStatus.active; // janela do long-poll fechou sem mudanca
      }
      throw VerifyNetworkException(
        'Falha ao consultar o status da verificacao.',
        statusCode: e.response?.statusCode,
      );
    }

    final int? code = res.statusCode;
    if (code == null || code >= 300) {
      throw VerifyNetworkException(
        'Falha ao consultar o status da verificacao (HTTP $code).',
        statusCode: code,
      );
    }

    final Map<String, dynamic> body = _asMap(res.data, context: 'status');
    final String? raw = _asNonEmptyString(
      body[VerifyFields.status] ?? body['state'],
    );
    if (raw == null) {
      throw const VerifyResponseException(
        'Resposta de status sem o campo "status".',
      );
    }

    final String status = raw.toUpperCase();
    const Set<String> known = <String>{
      VpStatus.active,
      VpStatus.submitted,
      VpStatus.expired,
    };
    if (!known.contains(status)) {
      throw VerifyResponseException(
          'Status de verificacao desconhecido: "$raw".');
    }
    return status;
  }

  // -----------------------------------------------------------------------
  // 3. Resultado
  // -----------------------------------------------------------------------

  /// `GET /vp-result/{transactionId}`.
  ///
  /// Retorna `(verified, underage)`:
  /// - `verified == true`  → credencial confirma 18+ (libera a compra).
  /// - `underage == true`  → credencial diz que e menor (bloqueia).
  ///
  /// Lanca:
  /// - [CredentialInvalidException]  quando `vcStatus == INVALID`.
  /// - [CredentialExpiredException]  quando `vcStatus == EXPIRED`.
  /// - [VerificationExpiredException] quando a sessao expirou sem apresentacao.
  /// - [VerifyResponseException] para payload malformado / `isOver18` ausente.
  Future<({bool verified, bool underage})> getResult(
    String transactionId,
  ) async {
    final Response<dynamic> res = await _send(
      () => _dio.get<dynamic>(VerifyEndpoints.result(transactionId)),
      action: 'obter o resultado da verificacao',
    );
    return parseResult(_asMap(res.data, context: 'vp-result'));
  }

  // -----------------------------------------------------------------------
  // Health check
  // -----------------------------------------------------------------------

  /// `GET /v1/verify/actuator/health` → `true` se o servico responde
  /// `{ "status": "UP" }`. Nunca lanca: erro de rede/HTTP vira `false`.
  Future<bool> checkHealth() async {
    try {
      final Response<dynamic> res =
          await _dio.get<dynamic>(VerifyEndpoints.health);
      if (res.statusCode != 200) return false;
      final Map<String, dynamic> body = _asMap(res.data, context: 'health');
      return _asNonEmptyString(body[VerifyFields.status])?.toUpperCase() ==
          'UP';
    } on DioException {
      return false;
    } on VerifyResponseException {
      return false;
    }
  }

  /// Parser defensivo do corpo de `/vp-result`. Exposto para teste unitario
  /// (M5) — nao faz I/O.
  ///
  /// Defensivo porque, conforme o plano (secao 4):
  /// - `vc` pode vir como `Map` **ou** como `String` contendo JSON;
  /// - `credentialSubject` pode estar em `vc.credentialSubject` **ou** em
  ///   `vc.credential.credentialSubject`;
  /// - `isOver18` pode vir como `bool` ou como `"true"/"false"`.
  @visibleForTesting
  static ({bool verified, bool underage}) parseResult(
    Map<String, dynamic> body,
  ) {
    final String? vpResultStatus =
        _asNonEmptyString(body[VerifyFields.vpResultStatus])?.toUpperCase();

    final Object? rawResults = body[VerifyFields.vcResults];
    final List<dynamic> vcResults = switch (rawResults) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map => <dynamic>[map],
      final Map<dynamic, dynamic> map => <dynamic>[map],
      _ => const <dynamic>[],
    };

    if (vcResults.isEmpty) {
      if (vpResultStatus == VpResultStatus.expired ||
          vpResultStatus == VpResultStatus.pending ||
          vpResultStatus == VpResultStatus.failed) {
        throw const VerificationExpiredException();
      }
      throw const VerifyResponseException('vp-result sem "vcResults".');
    }

    final Map<String, dynamic> firstResult = _asMap(
      vcResults.first,
      context: 'vcResults[0]',
    );
    final String vcStatus = (_asNonEmptyString(
              firstResult[VerifyFields.vcStatus],
            ) ??
            VcStatus.success)
        .toUpperCase();

    switch (vcStatus) {
      case VcStatus.invalid:
        throw const CredentialInvalidException();
      case VcStatus.expired:
        throw const CredentialExpiredException();
    }

    final Map<String, dynamic> subject = _extractCredentialSubject(
      firstResult[VerifyFields.vc],
    );
    final bool? isOver18 = _asBool(subject[VerifyFields.isOver18]);
    if (isOver18 == null) {
      throw const VerifyResponseException(
        'credentialSubject nao traz "isOver18".',
      );
    }

    return (verified: isOver18, underage: !isOver18);
  }

  // -----------------------------------------------------------------------
  // Retorno da carteira (plano, secao 6)
  // -----------------------------------------------------------------------

  /// `true` se [uri] e um retorno plausivel da carteira para este app.
  ///
  /// - Retornos em outro scheme sao ignorados.
  /// - Um retorno "nu" (`app18://` sem parametros) e aceito: equivale ao app
  ///   voltar ao foreground e o polling assume dali.
  /// - Se o retorno trouxer `transactionId`/`requestId`, eles precisam bater
  ///   com a sessao ativa.
  bool isTrustedReturn(
    Uri uri, {
    String? transactionId,
    String? requestId,
  }) {
    if (uri.scheme.toLowerCase() != AppConfig.appScheme) return false;

    final Map<String, String> q = uri.queryParameters;
    final String? txn = q['transactionId'] ?? q['transaction_id'];
    final String? req = q['requestId'] ?? q['request_id'];

    if (txn == null && req == null) return true;
    if (txn != null && transactionId != null && txn != transactionId) {
      return false;
    }
    if (req != null && requestId != null && req != requestId) return false;
    return true;
  }

  /// Fecha o [Dio] interno (somente se foi criado por este servico).
  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() call, {
    required String action,
  }) async {
    final Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      throw VerifyNetworkException(
        'Falha ao $action.',
        statusCode: e.response?.statusCode,
      );
    }
    final int? code = res.statusCode;
    if (code == null || code >= 300) {
      throw VerifyNetworkException(
        'Falha ao $action (HTTP $code).',
        statusCode: code,
      );
    }
    return res;
  }

  static Map<String, dynamic> _extractCredentialSubject(Object? vc) {
    final Map<String, dynamic> vcMap = _asMap(vc, context: 'vc');

    final Object? direct = vcMap[VerifyFields.credentialSubject];
    if (direct != null) {
      return _asMap(direct, context: 'credentialSubject');
    }

    final Object? credential = vcMap[VerifyFields.credential];
    if (credential != null) {
      final Map<String, dynamic> credentialMap = _asMap(
        credential,
        context: 'vc.credential',
      );
      final Object? nested = credentialMap[VerifyFields.credentialSubject];
      if (nested != null) {
        return _asMap(nested, context: 'vc.credential.credentialSubject');
      }
    }

    throw const VerifyResponseException(
      'Nao encontrei "credentialSubject" em "vc" nem em "vc.credential".',
    );
  }

  /// Converte [value] em `Map<String, dynamic>`, aceitando um `Map` ja tipado,
  /// um `Map` dinamico ou uma `String` contendo um objeto JSON.
  static Map<String, dynamic> _asMap(
    Object? value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String && value.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } on FormatException {
        // cai no throw abaixo
      }
    }
    throw VerifyResponseException('Esperava um objeto JSON em "$context".');
  }

  static String? _asNonEmptyString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
    }
    return null;
  }
}

/// Parametros configuraveis do [VerifyService]. Defaults vem de [AppConfig]
/// (que por sua vez le `--dart-define`), o que permite trocar mock <-> servico
/// real sem alterar as chamadas.
@immutable
class VerifyConfig {
  VerifyConfig({
    required this.baseUrl,
    required this.clientId,
    this.origin = AppConfig.appOrigin,
    this.sendOrigin = false,
    this.allowInsecure = false,
    Map<String, dynamic>? presentationDefinition,
  }) : presentationDefinition =
            presentationDefinition ?? VerifyPresentation.ecaAgeCheck();

  factory VerifyConfig.fromAppConfig() => VerifyConfig(
        baseUrl: AppConfig.verifyBaseUrl,
        clientId: AppConfig.clientId,
        sendOrigin: AppConfig.sendOrigin,
        allowInsecure: AppConfig.allowInsecure,
      );

  /// Host do Verify Service, **sem** o context path (`/v1/verify` ja vem dos
  /// caminhos em [VerifyEndpoints]).
  final String baseUrl;

  /// Identificador do verificador: `clientId` no corpo do vp-request e
  /// `client_id` no deep link. DID `did:web:...` ou URL publica.
  final String clientId;

  /// `origin` do deep link (`app18://`). Só entra na URL se [sendOrigin].
  final String origin;

  /// O tutorial nao envia `origin` no deep link. Ligue apenas para experimentar
  /// o retorno same-device.
  final bool sendOrigin;

  /// Aceita `baseUrl` sem TLS (so p/ teste em LAN).
  final bool allowInsecure;

  /// Presentation definition **completa** enviada no corpo do vp-request
  /// (default = [VerifyPresentation.ecaAgeCheck]).
  final Map<String, dynamic> presentationDefinition;

  /// `id` da presentation definition.
  String get presentationDefinitionId =>
      (presentationDefinition['id'] as String?) ??
      AppConfig.presentationDefinitionId;

  VerifyConfig copyWith({
    String? baseUrl,
    String? clientId,
    String? origin,
    bool? sendOrigin,
    bool? allowInsecure,
    Map<String, dynamic>? presentationDefinition,
  }) =>
      VerifyConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        clientId: clientId ?? this.clientId,
        allowInsecure: allowInsecure ?? this.allowInsecure,
        origin: origin ?? this.origin,
        sendOrigin: sendOrigin ?? this.sendOrigin,
        presentationDefinition:
            presentationDefinition ?? this.presentationDefinition,
      );
}

/// Base de todas as falhas tratadas do fluxo de verificacao.
sealed class VerifyException implements Exception {
  const VerifyException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Configuracao invalida (ex.: `VERIFY_BASE_URL` sem TLS).
class VerifyConfigException extends VerifyException {
  const VerifyConfigException(super.message);
}

/// Nao foi possivel abrir a Inji Wallet (nao instalada / scheme nao resolvido).
class WalletUnavailableException extends VerifyException {
  const WalletUnavailableException([
    super.message =
        'Nao foi possivel abrir a Inji Wallet. Instale a carteira e tente de novo.',
  ]);
}

/// Falha de rede ou resposta HTTP >= 300.
class VerifyNetworkException extends VerifyException {
  const VerifyNetworkException(super.message, {this.statusCode});

  final int? statusCode;
}

/// Corpo da resposta ausente / malformado / fora do contrato.
class VerifyResponseException extends VerifyException {
  const VerifyResponseException(super.message);
}

/// `vcStatus == INVALID` — assinatura/emissor da credencial nao conferem.
class CredentialInvalidException extends VerifyException {
  const CredentialInvalidException([
    super.message = 'A credencial apresentada e invalida.',
  ]);
}

/// `vcStatus == EXPIRED` — credencial vencida.
class CredentialExpiredException extends VerifyException {
  const CredentialExpiredException([
    super.message = 'A credencial apresentada esta expirada.',
  ]);
}

/// Sessao de apresentacao expirou sem a carteira submeter a credencial.
class VerificationExpiredException extends VerifyException {
  const VerificationExpiredException([
    super.message = 'A sessao de verificacao expirou. Tente novamente.',
  ]);
}
