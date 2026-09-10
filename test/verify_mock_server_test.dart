import 'package:app_idade18/features/age_check/data/verify_contract.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes do M4 — cobrem os criterios de aceite do mock (cenarios chaveaveis +
/// progressao do status). O fluxo ponta a ponta contra o mock e a matriz
/// completa do plano (secao 5) ficam para o M5.
void main() {
  group('VerifyMockServer — vp-request', () {
    test('devolve os campos do contrato (plano secao 4)', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);

      final Response<dynamic> res = await mock.dio.post<dynamic>(
        VerifyEndpoints.vpRequest,
        data: <String, dynamic>{
          VerifyFields.clientId: 'app-idade18-dev',
          'presentationDefinition': 'eca-age-check',
        },
      );

      final Map<String, dynamic> body = res.data as Map<String, dynamic>;
      expect(body[VerifyFields.transactionId], 'txn-over18-1');
      expect(body[VerifyFields.requestId], 'req-over18-1');
      // shape do tutorial: requestUri no topo; expiresAt/issuedAt em epoch ms.
      expect(body[VerifyFields.requestUri], contains('req-over18-1'));
      expect(body[VerifyFields.expiresAt], isA<int>());

      final Map<String, dynamic> auth =
          body[VerifyFields.authorizationDetails] as Map<String, dynamic>;
      expect(auth[VerifyFields.clientId], 'app-idade18-dev');
      expect(auth[VerifyFields.responseUri], contains('vp-submission'));
      expect(auth[VerifyFields.responseType], 'vp_token');
      expect(auth[VerifyFields.responseMode], 'direct_post');
      expect(auth[VerifyFields.issuedAt], isA<int>());
      expect(auth[VerifyFields.nonce], isA<String>());
    });

    test('health check responde UP', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio();
      final Response<dynamic> res =
          await mock.dio.get<dynamic>(VerifyEndpoints.health);
      expect((res.data as Map<String, dynamic>)[VerifyFields.status], 'UP');
    });

    test('cada POST gera ids novos', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);

      final Response<dynamic> a =
          await mock.dio.post<dynamic>(VerifyEndpoints.vpRequest);
      final Response<dynamic> b =
          await mock.dio.post<dynamic>(VerifyEndpoints.vpRequest);

      expect((a.data as Map<String, dynamic>)[VerifyFields.requestId],
          'req-over18-1');
      expect((b.data as Map<String, dynamic>)[VerifyFields.requestId],
          'req-over18-2');
    });
  });

  group('VerifyMockServer — status (progressao)', () {
    test('ACTIVE nas 2 primeiras chamadas, depois VP_SUBMITTED', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final String requestId = await _openSession(mock.dio);

      expect(await _status(mock.dio, requestId), VpStatus.active);
      expect(await _status(mock.dio, requestId), VpStatus.active);
      expect(await _status(mock.dio, requestId), VpStatus.submitted);
      expect(await _status(mock.dio, requestId), VpStatus.submitted);
    });

    test('cenario timeout: ACTIVE 2x e depois EXPIRED, nunca VP_SUBMITTED',
        () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.timeout);
      final String requestId = await _openSession(mock.dio);

      expect(await _status(mock.dio, requestId), VpStatus.active);
      expect(await _status(mock.dio, requestId), VpStatus.active);
      expect(await _status(mock.dio, requestId), VpStatus.expired);
      expect(await _status(mock.dio, requestId), VpStatus.expired);
    });

    test('activePolls configuravel', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(
        scenario: VerifyScenario.over18,
        activePolls: 0,
      );
      final String requestId = await _openSession(mock.dio);

      expect(await _status(mock.dio, requestId), VpStatus.submitted);
    });

    test('reset() zera a contagem de polling', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final String requestId = await _openSession(mock.dio);

      await _status(mock.dio, requestId);
      await _status(mock.dio, requestId);
      await _status(mock.dio, requestId);
      expect(await _status(mock.dio, requestId), VpStatus.submitted);

      mock.server.reset();
      final String requestId2 = await _openSession(mock.dio);
      expect(await _status(mock.dio, requestId2), VpStatus.active);
    });
  });

  group('VerifyMockServer — vp-result por cenario', () {
    Future<Map<String, dynamic>> firstVc(Dio dio, String transactionId) async {
      final Response<dynamic> res = await dio.get<dynamic>(
        VerifyEndpoints.result(transactionId),
      );
      final Map<String, dynamic> body = res.data as Map<String, dynamic>;
      final List<dynamic> results =
          body[VerifyFields.vcResults] as List<dynamic>;
      return results.first as Map<String, dynamic>;
    }

    test('over18 -> isOver18 true / vcStatus SUCCESS', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Map<String, dynamic> vcResult = await firstVc(mock.dio, txn);
      expect(vcResult[VerifyFields.vcStatus], VcStatus.success);
      final Map<String, dynamic> vc =
          vcResult[VerifyFields.vc] as Map<String, dynamic>;
      final Map<String, dynamic> subject =
          vc[VerifyFields.credentialSubject] as Map<String, dynamic>;
      expect(subject[VerifyFields.isOver18], isTrue);
    });

    test('underage -> isOver18 false / vcStatus SUCCESS', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.underage);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Map<String, dynamic> vcResult = await firstVc(mock.dio, txn);
      expect(vcResult[VerifyFields.vcStatus], VcStatus.success);
      final Map<String, dynamic> vc =
          vcResult[VerifyFields.vc] as Map<String, dynamic>;
      final Map<String, dynamic> subject =
          vc[VerifyFields.credentialSubject] as Map<String, dynamic>;
      expect(subject[VerifyFields.isOver18], isFalse);
    });

    test('invalid -> vcStatus INVALID', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.invalid);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Map<String, dynamic> vcResult = await firstVc(mock.dio, txn);
      expect(vcResult[VerifyFields.vcStatus], VcStatus.invalid);
    });

    test('expired -> vcStatus EXPIRED', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.expired);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Map<String, dynamic> vcResult = await firstVc(mock.dio, txn);
      expect(vcResult[VerifyFields.vcStatus], VcStatus.expired);
    });

    test('timeout -> vpResultStatus EXPIRED e vcResults vazio', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.timeout);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Response<dynamic> res = await mock.dio.get<dynamic>(
        VerifyEndpoints.result(txn),
      );
      final Map<String, dynamic> body = res.data as Map<String, dynamic>;
      expect(body[VerifyFields.vpResultStatus], VpResultStatus.expired);
      expect(body[VerifyFields.vcResults], isEmpty);
    });
  });

  group('VerifyMockServer — vcShape (parsing defensivo do M2)', () {
    test('mapNested aninha credentialSubject em vc.credential', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(
        scenario: VerifyScenario.over18,
        vcShape: VcShape.mapNested,
      );
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Response<dynamic> res =
          await mock.dio.get<dynamic>(VerifyEndpoints.result(txn));
      final Map<String, dynamic> vc = ((res.data
              as Map<String, dynamic>)[VerifyFields.vcResults] as List<dynamic>)
          .first[VerifyFields.vc] as Map<String, dynamic>;

      expect(vc.containsKey(VerifyFields.credentialSubject), isFalse);
      final Map<String, dynamic> credential =
          vc[VerifyFields.credential] as Map<String, dynamic>;
      final Map<String, dynamic> subject =
          credential[VerifyFields.credentialSubject] as Map<String, dynamic>;
      expect(subject[VerifyFields.isOver18], isTrue);
    });

    test('jsonString entrega vc como String JSON', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(
        scenario: VerifyScenario.over18,
        vcShape: VcShape.jsonString,
      );
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      final Response<dynamic> res =
          await mock.dio.get<dynamic>(VerifyEndpoints.result(txn));
      final Object? vc = ((res.data
              as Map<String, dynamic>)[VerifyFields.vcResults] as List<dynamic>)
          .first[VerifyFields.vc];

      expect(vc, isA<String>());
      expect(vc as String, contains('"isOver18":true'));
    });
  });

  group('VerifyMockServer — trocando de cenario', () {
    test('sessao aberta mantem o cenario de origem apos troca no server',
        () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      final String txn =
          await _openSession(mock.dio, returnTransactionId: true);

      mock.server.scenario = VerifyScenario.underage;

      final Response<dynamic> res =
          await mock.dio.get<dynamic>(VerifyEndpoints.result(txn));
      final Map<String, dynamic>
          subject = (((res.data as Map<String, dynamic>)[VerifyFields.vcResults]
                          as List<dynamic>)
                      .first[VerifyFields.vc]
                  as Map<String, dynamic>)[VerifyFields.credentialSubject]
              as Map<String, dynamic>;
      // Continua over18 porque a sessao nasceu nesse cenario.
      expect(subject[VerifyFields.isOver18], isTrue);
    });

    test('nova sessao usa o cenario corrente', () async {
      final ({Dio dio, VerifyMockServer server}) mock =
          VerifyMockServer.createDio(scenario: VerifyScenario.over18);
      await _openSession(mock.dio);

      mock.server.scenario = VerifyScenario.underage;
      final String txn2 =
          await _openSession(mock.dio, returnTransactionId: true);

      final Response<dynamic> res =
          await mock.dio.get<dynamic>(VerifyEndpoints.result(txn2));
      final Map<String, dynamic>
          subject = (((res.data as Map<String, dynamic>)[VerifyFields.vcResults]
                          as List<dynamic>)
                      .first[VerifyFields.vc]
                  as Map<String, dynamic>)[VerifyFields.credentialSubject]
              as Map<String, dynamic>;
      expect(subject[VerifyFields.isOver18], isFalse);
    });
  });

  test('rota desconhecida responde 404', () async {
    final ({Dio dio, VerifyMockServer server}) mock =
        VerifyMockServer.createDio(scenario: VerifyScenario.over18);

    final Response<dynamic> res = await mock.dio.get<dynamic>('/nao/existe');
    expect(res.statusCode, 404);
  });
}

/// Abre uma sessao (`POST /vp-request`) e devolve o `requestId` — ou o
/// `transactionId` se [returnTransactionId] for `true`.
Future<String> _openSession(
  Dio dio, {
  bool returnTransactionId = false,
}) async {
  final Response<dynamic> res = await dio.post<dynamic>(
    VerifyEndpoints.vpRequest,
    data: <String, dynamic>{VerifyFields.clientId: 'app-idade18-dev'},
  );
  final Map<String, dynamic> body = res.data as Map<String, dynamic>;
  return body[returnTransactionId
      ? VerifyFields.transactionId
      : VerifyFields.requestId] as String;
}

Future<String> _status(Dio dio, String requestId) async {
  final Response<dynamic> res = await dio.get<dynamic>(
    VerifyEndpoints.status(requestId),
  );
  return (res.data as Map<String, dynamic>)[VerifyFields.status] as String;
}
