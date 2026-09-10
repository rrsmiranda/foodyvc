/// Contrato REST do INJI Verify Service (relying party OID4VP).
///
/// Fonte de verdade: o tutorial oficial do VerificaIdade
/// (https://verificaidade.dev/quickstart.html + integra-web.html +
/// api-reference.html). Este arquivo concentra caminhos, nomes de campos,
/// valores de status e a *presentation definition* — [VerifyService] (M2) e o
/// mock (M4) importam daqui.
///
/// Context path fixo: `/v1/verify`. Sem cabecalhos de autenticacao — a
/// identidade do verificador vai no corpo (`clientId`).
///
/// 1. `POST {BASE}/v1/verify/vp-request`
///    body:     `{ clientId, presentationDefinition }` (PD = objeto completo)
///    resposta: `{ transactionId, requestId, requestUri, authorizationDetails,
///                 expiresAt }`
///    `authorizationDetails`: `{ clientId, nonce, responseUri, responseType,
///                 responseMode, issuedAt }` · `expiresAt`/`issuedAt` = epoch ms.
/// 2. `GET {BASE}/v1/verify/vp-request/{requestId}/status`
///    resposta: `{ status: ACTIVE | VP_SUBMITTED | EXPIRED }`
/// 3. `GET {BASE}/v1/verify/vp-result/{transactionId}`
///    resposta: `{ vpResultStatus, vcResults: [ { vc, vcStatus } ] }`
///    `vc.credentialSubject.isOver18` (bool) · `vcStatus`: SUCCESS|INVALID|EXPIRED
/// 4. `GET {BASE}/v1/verify/actuator/health` → `{ status: "UP" }` (health check)
///
/// Deep link (same-device): `openid4vp://authorize?client_id=<clientId>
/// &request_uri=<requestUri>`. A carteira submete a apresentacao em
/// `authorizationDetails.responseUri` (`.../vp-submission/direct-post`); o app
/// **nao** recebe callback — descobre o desfecho por polling do status.
library;

/// Caminhos do Verify Service, relativos ao `baseUrl` do Dio.
class VerifyEndpoints {
  const VerifyEndpoints._();

  /// Context path do servico.
  static const String context = '/v1/verify';

  /// `POST` — cria a VP Request.
  static const String vpRequest = '$context/vp-request';

  /// `GET` — status da sessao de apresentacao.
  static String status(String requestId) =>
      '$context/vp-request/$requestId/status';

  /// `GET` — resultado final da verificacao.
  static String result(String transactionId) =>
      '$context/vp-result/$transactionId';

  /// `GET` — health check (`{ "status": "UP" }`).
  static const String health = '$context/actuator/health';

  /// Onde a wallet submete a apresentacao (a wallet chama, nao o app).
  static const String vpSubmission = '$context/vp-submission/direct-post';

  // --- Padroes para casar o caminho recebido, independentemente de o Dio
  // --- incluir ou nao o host / um prefixo de gateway no `uri.path`. Sem
  // --- ancora inicial de proposito; a ancora final evita casar caminhos mais
  // --- profundos (ex.: `.../vp-request` vs `.../vp-request/{id}/status`).

  /// Casa `POST /v1/verify/vp-request`.
  static final RegExp vpRequestPattern = RegExp(r'/v1/verify/vp-request/?$');

  /// Casa `GET /v1/verify/vp-request/{requestId}/status` — grupo 1 = requestId.
  static final RegExp statusPattern =
      RegExp(r'/v1/verify/vp-request/([^/]+)/status/?$');

  /// Casa `GET /v1/verify/vp-result/{transactionId}` — grupo 1 = transactionId.
  static final RegExp resultPattern =
      RegExp(r'/v1/verify/vp-result/([^/]+)/?$');

  /// Casa `GET /v1/verify/actuator/health`.
  static final RegExp healthPattern = RegExp(r'/v1/verify/actuator/health/?$');
}

/// Nomes de campo de requisicoes e respostas.
class VerifyFields {
  const VerifyFields._();

  // vp-request (resposta)
  static const String transactionId = 'transactionId';
  static const String requestId = 'requestId';
  static const String requestUri = 'requestUri';
  static const String authorizationDetails = 'authorizationDetails';
  static const String expiresAt = 'expiresAt';

  // authorizationDetails
  static const String clientId = 'clientId';
  static const String nonce = 'nonce';
  static const String responseUri = 'responseUri';
  static const String responseType = 'responseType';
  static const String responseMode = 'responseMode';
  static const String issuedAt = 'issuedAt';

  // vp-request (corpo)
  static const String presentationDefinition = 'presentationDefinition';

  // status
  static const String status = 'status';

  // vp-result
  static const String vpResultStatus = 'vpResultStatus';
  static const String vcResults = 'vcResults';
  static const String vc = 'vc';
  static const String vcStatus = 'vcStatus';
  static const String credential = 'credential';
  static const String credentialSubject = 'credentialSubject';
  static const String isOver18 = 'isOver18';
  static const String type = 'type';
}

/// Estado da sessao de apresentacao (endpoint 2).
class VpStatus {
  const VpStatus._();

  static const String active = 'ACTIVE';
  static const String submitted = 'VP_SUBMITTED';
  static const String expired = 'EXPIRED';
}

/// Resultado da apresentacao como um todo (endpoint 3, `vpResultStatus`).
///
/// O tutorial so documenta `SUCCESS`; os demais entram como defensivo para o
/// parser tratar sessao nao submetida / falha.
class VpResultStatus {
  const VpResultStatus._();

  static const String success = 'SUCCESS';
  static const String pending = 'PENDING';
  static const String expired = 'EXPIRED';
  static const String failed = 'FAILED';
}

/// Estado de cada credencial apresentada (endpoint 3, `vcResults[].vcStatus`).
class VcStatus {
  const VcStatus._();

  static const String success = 'SUCCESS';
  static const String invalid = 'INVALID';
  static const String expired = 'EXPIRED';
}

/// `type` da credencial exigida pela presentation definition.
const String kEcaCredentialType = 'ECACredential';

/// `id` da presentation definition de verificacao de maioridade.
const String kEcaAgeCheckId = 'eca-age-verification';

/// Presentation definitions.
class VerifyPresentation {
  const VerifyPresentation._();

  /// PD de verificacao de maioridade — filtra `type == ECACredential`. Enviada
  /// **inteira** no corpo do `POST /vp-request`.
  ///
  /// **Cópia fiel** do exemplo oficial do piloto Dataprev
  /// (https://pernacabeluda.online/): `id: eca-age-verification`,
  /// `input_descriptor id: "eca credential"`, `filter.type: "object"`,
  /// `purpose`/`format` no topo. (A `api-reference.html` usa `eca-age-check` /
  /// `type: string`; seguimos o exemplo real que já foi testado contra a
  /// carteira do piloto.)
  static Map<String, dynamic> ecaAgeCheck() => <String, dynamic>{
        'id': kEcaAgeCheckId,
        'purpose':
            'Verificação de idade conforme o Estatuto da Criança e do Adolescente',
        'format': <String, dynamic>{
          'ldp_vc': <String, dynamic>{
            'proof_type': <String>['Ed25519Signature2020'],
          },
        },
        'input_descriptors': <dynamic>[
          <String, dynamic>{
            'id': 'eca credential',
            'format': <String, dynamic>{
              'ldp_vc': <String, dynamic>{
                'proof_type': <String>['Ed25519Signature2020'],
              },
            },
            'constraints': <String, dynamic>{
              'fields': <dynamic>[
                <String, dynamic>{
                  'path': <String>[r'$.type'],
                  'filter': <String, dynamic>{
                    'type': 'object',
                    'pattern': kEcaCredentialType,
                  },
                },
              ],
            },
          },
        ],
      };
}
