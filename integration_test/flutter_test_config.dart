import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Ver `test/flutter_test_config.dart`. Aplica-se quando os testes de
/// `integration_test/` rodam headless (`flutter test`); em device o
/// `google_fonts` funciona normalmente.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
