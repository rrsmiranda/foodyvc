import 'dart:convert';
import 'dart:typed_data';

import 'package:app_idade18/core/config/app_config.dart';
import 'package:app_idade18/features/age_check/data/verify_contract.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:app_idade18/features/age_check/data/verify_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coletor do deep link que o [VerifyService] tentaria abrir.
class _RecordingLauncher {
  Uri? lastUri;
  int calls = 0;
  bool result = true;
  bool throwsError = false;

  Future<bool> call(Uri uri) async {
    calls++;
    lastUri = uri;
    if (throwsError) {
      throw Exception('deep link falhou');
    }
    return result;
  }
}

void main() {
  group('createVpRequestAndOpenWallet', () {
    test(
        'retorna ids e abre openid4vp://authorize com client_id + request_uri '
        '+ origin (fluxo mobile same-device)', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final _RecordingLauncher launcher = _RecordingLauncher();
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: launcher.call,
      );

      final ({String requestId, String transactionId}) session =
          await service.createVpRequestAndOpenWallet();

      expect(session.requestId, 'req-over18-1');
      expect(session.transactionId, 'txn-over18-1');

      expect(launcher.calls, 1);
      final Uri uri = launcher.lastUri!;
      expect(uri.scheme, 'openid4vp');
      expect(uri.host, 'authorize');
      expect(uri.queryParameters['client_id'], AppConfig.clientId);
      expect(uri.queryParameters['request_uri'], contains('req-over18-1'));
      expect(uri.queryParameters['origin'], 'app18://');
    });

    test('sendOrigin=false tira o origin do deep link (opt-out)', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final _RecordingLauncher launcher = _RecordingLauncher();
      final VerifyService service = VerifyService(
        dio: mock.dio,
        config: VerifyConfig(
          baseUrl: 'https://verify.test',
          clientId: AppConfig.clientId,
          sendOrigin: false,
        ),
        uriLauncher: launcher.call,
      );

      await service.createVpRequestAndOpenWallet();
      expect(
        launcher.lastUri!.queryParameters.containsKey('origin'),
        isFalse,
      );
    });

    test('le requestUri do topo da resposta (shape do tutorial)', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      dio.httpClientAdapter = _InspectAdapter(
        (_) => <String, dynamic>{
          VerifyFields.transactionId: 'txn_1',
          VerifyFields.requestId: 'req_1',
          VerifyFields.requestUri:
              'https://verify.test/v1/verify/vp-request/req_1',
          VerifyFields.authorizationDetails: <String, dynamic>{
            VerifyFields.clientId: 'did:web:localhost:v1:verify',
            VerifyFields.nonce: 'abc',
            VerifyFields.responseType: 'vp_token',
            VerifyFields.responseMode: 'direct_post',
          },
          VerifyFields.expiresAt: 1784818112645,
        },
      );
      final _RecordingLauncher launcher = _RecordingLauncher();
      final VerifyService service =
          VerifyService(dio: dio, uriLauncher: launcher.call);

      final ({String requestId, String transactionId}) s =
          await service.createVpRequestAndOpenWallet();
      expect(s.transactionId, 'txn_1');
      expect(
        launcher.lastUri!.queryParameters['request_uri'],
        'https://verify.test/v1/verify/vp-request/req_1',
      );
      expect(
        launcher.lastUri!.queryParameters['client_id'],
        'did:web:localhost:v1:verify',
      );
    });

    test('launcher retornando false -> WalletUnavailableException', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final _RecordingLauncher launcher = _RecordingLauncher()..result = false;
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: launcher.call,
      );

      expect(
        () => service.createVpRequestAndOpenWallet(),
        throwsA(isA<WalletUnavailableException>()),
      );
    });

    test('launcher lancando erro -> WalletUnavailableException', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final _RecordingLauncher launcher = _RecordingLauncher()
        ..throwsError = true;
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: launcher.call,
      );

      expect(
        () => service.createVpRequestAndOpenWallet(),
        throwsA(isA<WalletUnavailableException>()),
      );
    });

    test('envia clientId e a presentation definition COMPLETA no corpo',
        () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      Map<String, dynamic>? sentBody;
      dio.httpClientAdapter = _InspectAdapter((RequestOptions o) {
        if (o.method == 'POST') {
          sentBody = o.data as Map<String, dynamic>;
        }
        return <String, dynamic>{
          VerifyFields.transactionId: 'txn-1',
          VerifyFields.requestId: 'req-1',
          VerifyFields.requestUri:
              'https://verify.test/v1/verify/vp-request/req-1',
          VerifyFields.expiresAt: 1784818112645,
        };
      });
      final VerifyService service = VerifyService(
        dio: dio,
        uriLauncher: _RecordingLauncher().call,
      );

      await service.createVpRequestAndOpenWallet();

      expect(sentBody?[VerifyFields.clientId], AppConfig.clientId);
      final Object? pd = sentBody?[VerifyFields.presentationDefinition];
      expect(pd, isA<Map<String, dynamic>>());
      expect((pd! as Map<String, dynamic>)['id'], 'eca-age-check');
      final List<dynamic> descriptors =
          (pd as Map<String, dynamic>)['input_descriptors'] as List<dynamic>;
      expect(descriptors, hasLength(1));
      expect(
          (descriptors.first as Map<String, dynamic>)['id'], 'ECACredential');
    });
  });

  group('checkHealth', () {
    test('mock responde UP', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio();
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: _RecordingLauncher().call,
      );
      expect(await service.checkHealth(), isTrue);
    });

    test('falha de rede -> false (nunca lanca)', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      dio.httpClientAdapter = _InspectAdapter(
        (_) => <String, dynamic>{},
        statusCode: 503,
      );
      final VerifyService service = VerifyService(
        dio: dio,
        uriLauncher: _RecordingLauncher().call,
      );
      expect(await service.checkHealth(), isFalse);
    });
  });

  group('pollStatus', () {
    test('over18: ACTIVE, ACTIVE, VP_SUBMITTED', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: _RecordingLauncher().call,
      );
      final ({String requestId, String transactionId}) s =
          await service.createVpRequestAndOpenWallet();

      expect(await service.pollStatus(s.requestId), VpStatus.active);
      expect(await service.pollStatus(s.requestId), VpStatus.active);
      expect(await service.pollStatus(s.requestId), VpStatus.submitted);
    });

    test('timeout: chega a EXPIRED', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(
        scenario: VerifyScenario.timeout,
        activePolls: 1,
      );
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: _RecordingLauncher().call,
      );
      final ({String requestId, String transactionId}) s =
          await service.createVpRequestAndOpenWallet();

      expect(await service.pollStatus(s.requestId), VpStatus.active);
      expect(await service.pollStatus(s.requestId), VpStatus.expired);
    });

    test('status desconhecido -> VerifyResponseException', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      dio.httpClientAdapter = _InspectAdapter(
        (_) => <String, dynamic>{VerifyFields.status: 'CONFUSO'},
      );
      final VerifyService service =
          VerifyService(dio: dio, uriLauncher: _RecordingLauncher().call);

      expect(
        () => service.pollStatus('req-1'),
        throwsA(isA<VerifyResponseException>()),
      );
    });

    test('HTTP 404 -> VerifyNetworkException', () async {
      final Dio dio = Dio(BaseOptions(
        baseUrl: 'https://verify.test',
        validateStatus: (int? c) => c != null && c < 500,
      ));
      dio.httpClientAdapter =
          _InspectAdapter((_) => <String, dynamic>{}, statusCode: 404);
      final VerifyService service =
          VerifyService(dio: dio, uriLauncher: _RecordingLauncher().call);

      expect(
        () => service.pollStatus('req-1'),
        throwsA(isA<VerifyNetworkException>()),
      );
    });

    test('receiveTimeout do long-poll -> devolve ACTIVE (nao e erro)', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      dio.httpClientAdapter = _ThrowingAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final VerifyService service =
          VerifyService(dio: dio, uriLauncher: _RecordingLauncher().call);

      expect(await service.pollStatus('req-1'), VpStatus.active);
    });

    test('erro de conexao real do long-poll -> VerifyNetworkException',
        () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://verify.test'));
      dio.httpClientAdapter = _ThrowingAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final VerifyService service =
          VerifyService(dio: dio, uriLauncher: _RecordingLauncher().call);

      expect(
        () => service.pollStatus('req-1'),
        throwsA(isA<VerifyNetworkException>()),
      );
    });
  });

  group('getResult (via mock)', () {
    Future<({bool underage, bool verified})> resultFor(
      VerifyScenario scenario, {
      VcShape vcShape = VcShape.mapDirect,
    }) async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: scenario, vcShape: vcShape);
      final VerifyService service = VerifyService(
        dio: mock.dio,
        uriLauncher: _RecordingLauncher().call,
      );
      final ({String requestId, String transactionId}) s =
          await service.createVpRequestAndOpenWallet();
      return service.getResult(s.transactionId);
    }

    test('over18 -> verified, nao underage', () async {
      final ({bool underage, bool verified}) r =
          await resultFor(VerifyScenario.over18);
      expect(r.verified, isTrue);
      expect(r.underage, isFalse);
    });

    test('underage -> nao verified, underage', () async {
      final ({bool underage, bool verified}) r =
          await resultFor(VerifyScenario.underage);
      expect(r.verified, isFalse);
      expect(r.underage, isTrue);
    });

    test('invalid -> CredentialInvalidException', () {
      expect(
        () => resultFor(VerifyScenario.invalid),
        throwsA(isA<CredentialInvalidException>()),
      );
    });

    test('expired -> CredentialExpiredException', () {
      expect(
        () => resultFor(VerifyScenario.expired),
        throwsA(isA<CredentialExpiredException>()),
      );
    });

    test('timeout -> VerificationExpiredException', () {
      expect(
        () => resultFor(VerifyScenario.timeout),
        throwsA(isA<VerificationExpiredException>()),
      );
    });

    test('vc aninhado (vc.credential.credentialSubject) -> verified', () async {
      final ({bool underage, bool verified}) r = await resultFor(
        VerifyScenario.over18,
        vcShape: VcShape.mapNested,
      );
      expect(r.verified, isTrue);
    });

    test('vc como String JSON -> verified', () async {
      final ({bool underage, bool verified}) r = await resultFor(
        VerifyScenario.over18,
        vcShape: VcShape.jsonString,
      );
      expect(r.verified, isTrue);
    });
  });

  group('parseResult (parser defensivo, sem I/O)', () {
    Map<String, dynamic> resultBody(Object vc, {String vcStatus = 'SUCCESS'}) =>
        <String, dynamic>{
          VerifyFields.vpResultStatus: 'SUCCESS',
          VerifyFields.vcResults: <dynamic>[
            <String, dynamic>{
              VerifyFields.vc: vc,
              VerifyFields.vcStatus: vcStatus,
            },
          ],
        };

    test('vc Map com credentialSubject na raiz', () {
      final ({bool underage, bool verified}) r = VerifyService.parseResult(
        resultBody(<String, dynamic>{
          VerifyFields.credentialSubject: <String, dynamic>{
            VerifyFields.isOver18: true,
          },
        }),
      );
      expect(r.verified, isTrue);
    });

    test('vc Map com credential.credentialSubject aninhado', () {
      final ({bool underage, bool verified}) r = VerifyService.parseResult(
        resultBody(<String, dynamic>{
          VerifyFields.credential: <String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: false,
            },
          },
        }),
      );
      expect(r.verified, isFalse);
      expect(r.underage, isTrue);
    });

    test('vc como String JSON', () {
      final ({bool underage, bool verified}) r = VerifyService.parseResult(
        resultBody(jsonEncode(<String, dynamic>{
          VerifyFields.credentialSubject: <String, dynamic>{
            VerifyFields.isOver18: true,
          },
        })),
      );
      expect(r.verified, isTrue);
    });

    test('isOver18 como string "true"/"false"', () {
      expect(
        VerifyService.parseResult(
          resultBody(<String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: 'true',
            },
          }),
        ).verified,
        isTrue,
      );
      expect(
        VerifyService.parseResult(
          resultBody(<String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: 'false',
            },
          }),
        ).underage,
        isTrue,
      );
    });

    test('campo isOver18 ausente -> VerifyResponseException', () {
      expect(
        () => VerifyService.parseResult(
          resultBody(<String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{'id': 'x'},
          }),
        ),
        throwsA(isA<VerifyResponseException>()),
      );
    });

    test('vcStatus ausente e tratado como SUCCESS', () {
      final Map<String, dynamic> body = <String, dynamic>{
        VerifyFields.vpResultStatus: 'SUCCESS',
        VerifyFields.vcResults: <dynamic>[
          <String, dynamic>{
            VerifyFields.vc: <String, dynamic>{
              VerifyFields.credentialSubject: <String, dynamic>{
                VerifyFields.isOver18: true,
              },
            },
          },
        ],
      };
      expect(VerifyService.parseResult(body).verified, isTrue);
    });

    test('vcStatus INVALID -> CredentialInvalidException', () {
      expect(
        () => VerifyService.parseResult(
          resultBody(
            <String, dynamic>{
              VerifyFields.credentialSubject: <String, dynamic>{
                VerifyFields.isOver18: true,
              },
            },
            vcStatus: 'INVALID',
          ),
        ),
        throwsA(isA<CredentialInvalidException>()),
      );
    });

    test('vcStatus EXPIRED -> CredentialExpiredException', () {
      expect(
        () => VerifyService.parseResult(
          resultBody(
            <String, dynamic>{
              VerifyFields.credentialSubject: <String, dynamic>{
                VerifyFields.isOver18: true,
              },
            },
            vcStatus: 'EXPIRED',
          ),
        ),
        throwsA(isA<CredentialExpiredException>()),
      );
    });

    test('vcResults vazio + vpResultStatus EXPIRED -> VerificationExpired', () {
      expect(
        () => VerifyService.parseResult(<String, dynamic>{
          VerifyFields.vpResultStatus: 'EXPIRED',
          VerifyFields.vcResults: <dynamic>[],
        }),
        throwsA(isA<VerificationExpiredException>()),
      );
    });

    test('vcResults vazio sem status util -> VerifyResponseException', () {
      expect(
        () => VerifyService.parseResult(<String, dynamic>{
          VerifyFields.vpResultStatus: 'SUCCESS',
          VerifyFields.vcResults: <dynamic>[],
        }),
        throwsA(isA<VerifyResponseException>()),
      );
    });

    test('vcResults vazio + vpResultStatus FAILED -> VerificationExpired', () {
      expect(
        () => VerifyService.parseResult(<String, dynamic>{
          VerifyFields.vpResultStatus: 'FAILED',
          VerifyFields.vcResults: <dynamic>[],
        }),
        throwsA(isA<VerificationExpiredException>()),
      );
    });

    test('isOver18 como numero (1 / 0)', () {
      expect(
        VerifyService.parseResult(
          resultBody(<String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: 1,
            },
          }),
        ).verified,
        isTrue,
      );
      expect(
        VerifyService.parseResult(
          resultBody(<String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: 0,
            },
          }),
        ).underage,
        isTrue,
      );
    });

    test('vc ausente -> VerifyResponseException', () {
      expect(
        () => VerifyService.parseResult(<String, dynamic>{
          VerifyFields.vpResultStatus: 'SUCCESS',
          VerifyFields.vcResults: <dynamic>[
            <String, dynamic>{VerifyFields.vcStatus: 'SUCCESS'},
          ],
        }),
        throwsA(isA<VerifyResponseException>()),
      );
    });

    test('vc String que nao e JSON -> VerifyResponseException', () {
      expect(
        () => VerifyService.parseResult(resultBody('nao-e-json')),
        throwsA(isA<VerifyResponseException>()),
      );
    });

    test('vcResults como Map unico (nao lista) e aceito', () {
      final ({bool underage, bool verified}) r =
          VerifyService.parseResult(<String, dynamic>{
        VerifyFields.vpResultStatus: 'SUCCESS',
        VerifyFields.vcResults: <String, dynamic>{
          VerifyFields.vc: <String, dynamic>{
            VerifyFields.credentialSubject: <String, dynamic>{
              VerifyFields.isOver18: true,
            },
          },
          VerifyFields.vcStatus: 'SUCCESS',
        },
      });
      expect(r.verified, isTrue);
    });
  });

  group('isTrustedReturn', () {
    final VerifyService service = VerifyService(
      dio: VerifyMockServer.createDio().dio,
      uriLauncher: _RecordingLauncher().call,
    );

    test('scheme errado -> false', () {
      expect(
        service.isTrustedReturn(Uri.parse('https://evil.example/cb')),
        isFalse,
      );
    });

    test('retorno nu no nosso scheme -> true', () {
      expect(service.isTrustedReturn(Uri.parse('app18://callback')), isTrue);
    });

    test('transactionId divergente -> false', () {
      expect(
        service.isTrustedReturn(
          Uri.parse('app18://cb?transactionId=outro'),
          transactionId: 'txn-1',
        ),
        isFalse,
      );
    });

    test('transactionId conferindo -> true', () {
      expect(
        service.isTrustedReturn(
          Uri.parse('app18://cb?transactionId=txn-1'),
          transactionId: 'txn-1',
        ),
        isTrue,
      );
    });
  });

  group('VerifyConfig / TLS guard', () {
    test('baseUrl sem https (host publico) -> VerifyConfigException', () {
      expect(
        () => VerifyService(
          config: VerifyConfig(
            baseUrl: 'http://verify.exemplo.gov.br',
            clientId: 'c',
          ),
        ),
        throwsA(isA<VerifyConfigException>()),
      );
    });

    test('baseUrl http em localhost -> ok', () {
      expect(
        () => VerifyService(
          config: VerifyConfig(
            baseUrl: 'http://localhost:8080',
            clientId: 'c',
          ),
        ),
        returnsNormally,
      );
    });

    test('dio injetado dispensa o guard de TLS', () {
      expect(
        () => VerifyService(
          dio: Dio(BaseOptions(baseUrl: 'http://qualquer')),
          config: VerifyConfig(
            baseUrl: 'http://qualquer',
            clientId: 'c',
          ),
        ),
        returnsNormally,
      );
    });

    test('allowInsecure=true libera http em host de LAN', () {
      expect(
        () => VerifyService(
          config: VerifyConfig(
            baseUrl: 'http://192.168.0.10:8080',
            clientId: 'did:web:192.168.0.10:v1:verify',
            allowInsecure: true,
          ),
        ),
        returnsNormally,
      );
    });
  });
}

/// Adapter minimo: responde toda requisicao com o corpo JSON produzido por
/// [build], util para testar o [VerifyService] com payloads sob medida.
class _InspectAdapter implements HttpClientAdapter {
  _InspectAdapter(this.build, {this.statusCode = 200});

  final Map<String, dynamic> Function(RequestOptions options) build;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> body = build(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter que sempre lanca a [DioException] dada — para simular timeout do
/// long-poll / erro de conexao.
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);

  final DioException error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw error;

  @override
  void close({bool force = false}) {}
}
