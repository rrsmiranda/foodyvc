import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Executado automaticamente antes de cada arquivo de teste em `test/`.
///
/// Desliga o download de fontes em runtime: nos testes o `google_fonts` cai
/// para a fonte do sistema (deterministico, sem chamadas de plugin/rede).
/// Em producao o download + cache no device continua ativo.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
