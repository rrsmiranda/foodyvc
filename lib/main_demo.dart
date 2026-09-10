import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo/demo_app.dart';
import 'features/age_check/application/age_check_controller.dart';
import 'features/age_check/data/verify_mock_server.dart';
import 'features/age_check/data/verify_service.dart';

/// Entrypoint de DEMO — roda o app inteiro sem INJI Verify Service nem carteira.
///
/// O `verifyServiceProvider` aponta para o mock do M4 (3 endpoints simulados) e
/// o abridor de deep link e um stub que apenas registra a URL. Use o botao
/// flutuante "Demo" para trocar o cenario (maior/menor de 18, credencial
/// invalida/expirada, timeout).
///
/// ```sh
/// flutter run -d chrome -t lib/main_demo.dart
/// # ou: flutter build web -t lib/main_demo.dart  (saida em build/web)
/// ```
///
/// O `main.dart` normal continua sendo o entrypoint real (fala com o Verify
/// Service via --dart-define).
void main() {
  final ({Dio dio, VerifyMockServer server}) mock = VerifyMockServer.createDio(
    scenario: VerifyScenario.over18,
    activePolls: 2,
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        demoMockServerProvider.overrideWithValue(mock.server),
        verifyServiceProvider.overrideWithValue(
          VerifyService(
            dio: mock.dio,
            uriLauncher: (Uri uri) async {
              debugPrint('DEMO: abriria a carteira -> $uri');
              return true;
            },
          ),
        ),
        ageCheckTimingProvider.overrideWithValue(
          const AgeCheckTiming(
            pollInterval: Duration(milliseconds: 600),
            maxPolls: 6,
          ),
        ),
      ],
      child: const DemoApp(),
    ),
  );
}
