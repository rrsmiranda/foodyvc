import 'package:app_idade18/core/config/app_config.dart';
import 'package:app_idade18/features/age_check/application/age_check_controller.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:app_idade18/features/age_check/data/verify_service.dart';
import 'package:app_idade18/features/diagnostics/diagnostics_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host() {
    final ({Dio dio, VerifyMockServer server}) mock =
        VerifyMockServer.createDio();
    return ProviderScope(
      overrides: <Override>[
        verifyServiceProvider.overrideWithValue(
          VerifyService(dio: mock.dio, uriLauncher: (_) async => true),
        ),
      ],
      child: const MaterialApp(home: DiagnosticsPage()),
    );
  }

  testWidgets('mostra a configuracao efetiva', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Configuracao efetiva'), findsOneWidget);
    expect(find.text('VERIFY_BASE_URL'), findsOneWidget);
    expect(find.text(AppConfig.verifyBaseUrl), findsWidgets);
    expect(find.text('clientId'), findsOneWidget);
  });

  testWidgets('health check contra o mock -> UP', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('GET /actuator/health'));
    await tester.pumpAndSettle();

    expect(find.textContaining('status: UP'), findsOneWidget);
  });

  testWidgets('passo 1 -> ids; passos 2 e 3 habilitam e respondem', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('POST /vp-request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('requestId=req-over18-1'), findsOneWidget);

    await tester.tap(find.text('GET /vp-request/{id}/status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('status: ACTIVE'), findsOneWidget);
  });
}
