# Code Checkpoint — App 18+ VerificaIdade (Flutter)
> Última atualização: 2026-09-11 · v12 (guarda de config sentinela + config apontando p/ Dataprev HML)
> Fase: MVP pronto p/ ligar num INJI Verify Service real. Falta = infra (Fase 0) + Android SDK p/ device.
> **Contrato REST = fonte de verdade: https://verificaidade.dev (quickstart + integra-web + api-reference).**
> Modelo ativo: Sonnet (implementação)
> Fontes de verdade agora são os docs **v2**: `specs-e-prompts-idev2.md` (insere M-DS), `code-checkpointv2.md` (decisão DS-em-Dart + nota backend BFF). Plano: `plano-verificaidade-flutter.md`.

## Stack
- Lang: Dart 3.5.4 | Framework: Flutter 3.24.5 (`~/development/flutter`, fora do PATH) | DB: — (catálogo mock no MVP)
- HTTP: dio ^5.11.1 | Estado: flutter_riverpod ^2.6.1 (CONFIRMADO) | Rotas: go_router ^15.1.2
- Deep link: url_launcher ^6.3.1 | Lifecycle: WidgetsBindingObserver (`app_links` **removido** — não era usado e quebrava o build Android, exige AGP 8.6; re-adicionar só quando/se for capturar o retorno por deep link)
- Testes: flutter_test + integration_test (sdk) + http_mock_adapter ^0.6.1
- UI: Material 3, design system em Dart (`lib/core/theme` + `lib/core/widgets`), tipografia `google_fonts` ^6.3.0 (Inter)
- Estrutura: feature-first (lib/features/{shop,age_check} + lib/core)
- Projeto Flutter na RAIZ do repo `foody`; `name: app_idade18`; org `br.com.verificaidade`; plataformas: **android + ios + web** (web adicionado p/ rodar a demo sem toolchain nativa)
- **Git**: `github.com/rrsmiranda/foodyvc` (branch `main`, **público**). CI: Codemagic (`codemagic.yaml` → APK debug) + GitHub Actions (`.github/workflows/deploy-web.yml` → demo web no Pages).
- **Demo web publicada**: https://rrsmiranda.github.io/foodyvc/ (build `lib/main_demo.dart` + mock M4; republica a cada push na `main` fora de `docs/`).

## Arquitetura Atual
PRODUTO = verificação de idade. iFood = só CASCA de simulação de compra.
Casca: lista de produtos mock (>=1 item is18Plus) + botão FINALIZAR.
Ao finalizar com item 18+ → dispara Módulo de Verificação; senão compra concluída.
Verificação = relying party OID4VP, REST puro + deep link openid4vp://.
Fluxo: POST /vp-request → abre Inji Wallet → poll /status → GET /vp-result → isOver18.
Retomada do polling via AppLifecycleState.resumed.
(Clone iFood fiel das 7 telas = opcional/depois — ver plano seção 2.1.)

## Plano de Tarefas
- [ ] Fase 0 — Pré-requisitos externos (VERIFY_BASE_URL, onboarding, wallet, credencial teste) ← BLOQUEANTE p/ teste real
- [x] Fase 1 — Casca de simulação de compra (M0 scaffold+deep link+rotas; M1 catálogo/carrinho/gate)
- [x] Fase 2 — Módulo verificação (M4 mock → M2 verify_service → M3 AgeCheckPage)
- [x] Fase 3 — Harness de testes de credencial (M4 mock + M5 matriz)
- [ ] Fase 4 — Segurança/LGPD final + build assinado stores

### Módulos (ordem v2: M0 → M-DS → M4 → M2 → M3 → M1 → M5)
- [x] **M0 — Scaffold + deep link iOS/Android**
- [x] **M-DS — Design System em Dart** (tokens + ThemeData claro/escuro + AppButton/ProductCard/StatusView/AppBanner/AdultBadge)
- [x] **M4 — Mock do INJI Verify Service** (VerifyMockServer, VerifyScenario, VcShape)
- [x] **M2 — verify_service.dart** (3 chamadas REST + deep link openid4vp:// + parsing defensivo + exceções tipadas)
- [x] **M3 — AgeCheckPage** (máquina de estados + polling sem loops duplicados + lifecycle `resumed`; UI via StatusView)
- [x] **M1 — Casca de compra** (Product, CartController, ShopPage via ProductCard/AppButton, gate 18+ + gate de retorno)
- [x] **M5 — Testes** (parser completo, renderização por estado, integration 3 cenários) — `flutter test` 107/107 + `integration_test/flow_test.dart` (device)

## Decisões Tomadas
- Alvo: iOS + Android, base única Flutter (device físico p/ testar deep link same-device)
- Execução: código gerado na IDE via Claude API; este chat = planejamento/spec. Ver specs-e-prompts-ide.md
- iOS: Info.plist precisa de LSApplicationQueriesSchemes com "openid4vp" (senão launchUrl falha)
- **Android 11+: `<queries><intent><data android:scheme="openid4vp"/>` é OBRIGATÓRIO** — equivalente Android do LSApplicationQueriesSchemes; sem isso `canLaunchUrl` retorna false e a wallet não abre (não estava no plano; adicionado no M0)
- Foco = verificação de idade; iFood é só casca de simulação (NÃO reproduzir as 7 telas no MVP)
- Gatilho da verificação = botão "Finalizar compra" quando pedido tem item 18+
- Sem SDK: integração via REST + deep link (confirmado na doc/API reference)
- App não emite credencial; só verifica (recebe apenas isOver18)
- LGPD: não persistir VC crua nem PII; guardar só {bool, transactionId, timestamp}
- Presentation definition: eca-age-check filtrando type == ECACredential
- Scheme do app = `app18`; origin = `app18://`
- **Config por `--dart-define`** (`VERIFY_BASE_URL`, `VERIFY_CLIENT_ID`) em `AppConfig` — troca mock ↔ real sem tocar em código
- Docs movidos para `docs/` (os .md estavam na raiz)
- **[v2] Design system em Dart via CLI** (módulo M-DS) — sem Claude Design; tokens → `ThemeData` → componentes-núcleo. `google_fonts` (Inter).
- **[v2] Backend próprio previsto = BFF**: backend faz broker do INJI Verify Service (segredos + auditoria no servidor), app fala só com o backend; deep link segue no device. Doc `backend-integracao.md` ainda **não existe** — sem tarefa até a stack/escopo serem definidos. Hoje o app fala direto com o Verify Service (via `--dart-define`); migrar a `baseUrl` para o BFF é trivial (só muda `VerifyConfig.baseUrl`).
- **M4: mock NÃO usa `http_mock_adapter`** — implementa `HttpClientAdapter` do próprio dio. Motivo: `http_mock_adapter` é dev-dep e importá-lo de `lib/` dispara lint `depend_on_referenced_packages`; além disso o mock precisa de respostas com estado (status ACTIVE→VP_SUBMITTED por contador), e um adapter próprio dá controle total sem risco de API entre versões. O spec permite alternativa ("ou shelf local"). `http_mock_adapter` fica no pubspec para uso pontual em testes de M5 se necessário.
- **Contrato REST centralizado** em `lib/features/age_check/data/verify_contract.dart` (paths, regex de rota, nomes de campos, constantes de status). M2 e M4 importam daqui — nada de string solta.
- **Contrato = tutorial verificaidade.dev + serviço real 0.18.1 testado ao vivo** (v11): status → `{ "status": "ACTIVE|VP_SUBMITTED|EXPIRED" }`; result → `{ "vpResultStatus", "vcResults":[{ "vc":{ "credentialSubject":{ "isOver18" }}, "vcStatus" }] }`. `vp-request` body = `{ clientId, presentationDefinition (objeto completo) }`; **resposta real = só `{ transactionId, requestId, expiresAt (epoch ms), requestUri (topo) }` — SEM `authorizationDetails`** (o app já trata). Deep link mobile = `client_id` + `request_uri` + **`origin`** (`integra-mobile.html`). Sem auth headers.
- **`/status` é LONG-POLLING (~55 s/chamada)** — `pollStatus` usa `receiveTimeout` 70 s (`kStatusLongPollWindow`) e, se estourar, devolve `ACTIVE` (não erro). `getResult` antes da submissão → HTTP 400 `NO_VP_SUBMISSION` (não ocorre no fluxo normal).
- `VerifyMockServer.createDio(...)` devolve `({Dio dio, VerifyMockServer server})`; `server.scenario`/`server.vcShape` mutáveis; `server.reset()` zera contadores. Sessão criada guarda o cenário de origem (troca posterior no server só afeta sessões novas).
- `VcShape { mapDirect, mapNested, jsonString }` no mock para alimentar a matriz de parsing defensivo do M5.
- **M2 `VerifyService`** — construtor `factory` recebe `Dio? dio`, `VerifyConfig? config`, `UriLauncher? uriLauncher` (todos injetáveis p/ teste). Se `dio` não vier, cria um com `baseUrl` do config e **guard de TLS** (LGPD §6): `VERIFY_BASE_URL` sem `https://` → `VerifyConfigException`, exceto host local/`.invalid`. `dio` injetado dispensa o guard.
- **`VerifyConfig`** (`@immutable`, `fromAppConfig()`, `copyWith`): `baseUrl` (sem context path), `clientId`, `origin` (`app18://`), `presentationDefinitionId`. `baseUrl` = host puro; `/v1/verify/...` vem de `VerifyEndpoints`.
- **Deep link**: `Uri.parse('openid4vp://authorize').replace(queryParameters: {client_id, request_uri, origin})`; `request_uri`/`client_id` saem de `authorizationDetails` da resposta do vp-request. Abre via `uriLauncher` (default = `url_launcher.launchUrl` + `LaunchMode.externalApplication`). Falha ou `false` → `WalletUnavailableException`.
- **Exceções tipadas** (`sealed class VerifyException`): `VerifyConfigException`, `WalletUnavailableException`, `VerifyNetworkException` (tem `statusCode`), `VerifyResponseException`, `CredentialInvalidException` (vcStatus INVALID), `CredentialExpiredException` (vcStatus EXPIRED), `VerificationExpiredException` (vcResults vazio + vpResultStatus EXPIRED/PENDING/FAILED). M3 pode fazer `switch` exaustivo.
- **`parseResult(Map)` é `static @visibleForTesting`** (sem I/O) — M5 testa o parser direto. `vc` String→`jsonDecode`; `credentialSubject` em `vc.credentialSubject` OU `vc.credential.credentialSubject`; `isOver18` aceita `bool`, `"true"/"false"`, `num`. Retorno `({bool verified, bool underage})` — complementares aqui (invalid/expired/underage tratados antes/à parte); M3 usa `verified`→estado success, `underage`→estado underage.
- **`isTrustedReturn(Uri, {transactionId, requestId})`** (plano §6): scheme ≠ `app18` → false; retorno "nu" (`app18://` sem params) → true (equivale a foreground); se trouxer `transactionId`/`requestId`, tem de bater com a sessão. Para M3 usar ao capturar deep link de retorno via `app_links`.
- **LGPD**: `VerifyService` nunca retorna/loga/persiste a VC crua — só o booleano. Nenhum `print`/log de corpo de resposta.
- **M3 camada `application/`** (feature-first): `age_check_controller.dart` separa a máquina de estados da UI.
- **`AgeCheckPhase`**: `idle, abrindoWallet, aguardando, verificando, success, underage, expired, error`. `AgeCheckState` imutável (`phase`, `message`, `session`, `pollCount`) com `==`. `AgeCheckSession { transactionId, requestId }`.
- **`ageCheckControllerProvider`** = `NotifierProvider.autoDispose` — sair da tela zera; a tela permanece montada durante o fluxo (carteira é outro app), então o estado sobrevive ao foreground. **Em teste**: manter vivo com `container.listen(ageCheckControllerProvider, (_, __) {})`, senão o container descarta entre `read`s.
- **`verifyServiceProvider`** (`Provider`, app-wide) — em teste sobrescrever com `VerifyService(dio: mock.dio, uriLauncher: ...)`. **`ageCheckTimingProvider`** (`AgeCheckTiming { pollInterval=1s, maxPolls=8 }` — o `/status` já segura ~55s/chamada, então maxPolls é teto de *ciclos*) — testes zeram o intervalo. **`ageCheckOutcomeProvider`** (`StateProvider<AgeCheckOutcome?>`, NÃO autoDispose) — grava `verified`/`blocked` p/ o gate do M1 ler depois de sair da tela.
- **Polling sem duplicar loops**: contador de geração (`_generation`) + `_activeLoops` + `_wakeSignal` (Completer). `_pollLoop` faz `++_generation` ao entrar; um loop só continua enquanto sua geração for a corrente → loop antigo se encerra sozinho. `_sleep` corre `Future.any([delayed, wake.future])`. **`onAppResumed`**: se há loop ativo, só chama `_wake()` (pula a espera, consulta já); se não há, inicia um. Invariante testada: `maxConcurrentLoops` (`@visibleForTesting`) nunca passa de 1.
- **Mapa exceção→fase** (`_fail`, switch exaustivo sobre `sealed VerifyException`): `VerificationExpiredException`→`expired`; todas as outras (`WalletUnavailable`, `Network`, `Response`, `CredentialInvalid`, `CredentialExpired`, `Config`)→`error`. `EXPIRED` no status / `maxPolls` estourado→`expired`.
- **Lifecycle**: `AgeCheckPage` é `ConsumerStatefulWidget`; o `State with WidgetsBindingObserver` (`addObserver`/`removeObserver`), `didChangeAppLifecycleState` → em `resumed` chama `controller.onAppResumed()`. (spec pede `WidgetsBindingObserver` explicitamente; `app_links` fica p/ depois — o `resumed` cobre o caminho principal.)
- **UI por fase**: `_ViewForPhase` (switch), `_BusyLayout` (spinner + `pollCount`), `_StatusLayout` (ícone/título/corpo/botões). `success`→"Concluir compra"→volta p/ `/` (gate real no M1). `underage`→"Voltar à loja", SEM retry. `expired`/`error`→"Tentar de novo" (`controller.retry()`) + "Voltar à loja".
- Back da AgeCheckPage: `context.canPop() ? context.pop() : context.go('/')` — funciona tanto se M1 usar `go` quanto `push`.
- **M1 feature `shop`** (feature-first: domain/data/application/presentation):
  - `Product { String id; String nome; double preco; bool is18Plus }` (`domain/product.dart`, imutável, `==`).
  - `MockProductRepository` (`data/product_repository.dart`): 5 produtos, 2 com `is18Plus=true` (`cerveja`, `vinho`). `productRepositoryProvider` + `catalogProvider`.
  - `CartController` (`application/cart_controller.dart`, `Notifier`, **NÃO autoDispose** — carrinho sobrevive à ida a `/verify`): `add`/`remove`/`removeAdultItems`/`clear` + getter `hasAdultItem`. `CartState { List<CartLine> }` com `total`, `itemCount`, `hasAdultItem`, `quantityOf(id)`.
  - `ShopPage` (`ConsumerStatefulWidget`, reescreve o diagnóstico do M0): `ListView` do catálogo com `+`/`−`, `bottomNavigationBar` = `_CheckoutBar` (total + "Finalizar compra", desabilitado se vazio). Badge "18+" nos itens adultos.
- **Gate ao finalizar** (`_onFinalize`): carrinho vazio → no-op; `hasAdultItem` → `context.go('/verify')`; senão → `AlertDialog` "Compra concluida" + `clear()` no OK.
- **Gate de retorno**: `ShopPage.initState` faz `ref.listenManual(ageCheckOutcomeProvider, _onOutcome, fireImmediately: true)`. `_onOutcome` (via `addPostFrameCallback`, guardado por `mounted` + releitura + reset a `null`): `verified` → `cart.clear()` + diálogo "Compra concluida"; `blocked` → `cart.removeAdultItems()` + diálogo "Itens removidos". `fireImmediately` cobre o remount real vindo de `/verify`; mudanças seguintes cobrem telas coexistindo (push).
- `formatBrl(double)` em `lib/core/utils/currency.dart` (sem `intl`): `R$ 1.234,50`.
- **M5**: `_ViewForPhase` virou **`AgeCheckStatusView`** (público) em `age_check_page.dart` — widget só-visual (`AgeCheckState` + 3 callbacks, sem Riverpod/lifecycle) p/ testar cada fase com um pump. `age_check_page_test.dart` cobre as 8 fases (`idle, abrindoWallet, aguardando c/ pollCount, verificando, success, underage, expired, error`) + disparo de callbacks. `verify_service_test.dart` ganhou `isOver18` como `num`, `vpResultStatus FAILED`, `vc` ausente, `vc` String não-JSON, `vcResults` como Map único.
- **`integration_test/flow_test.dart`** (`IntegrationTestWidgetsFlutterBinding`): 3 cenários via `VerifyScenario` do mock (over18→compra concluída+carrinho limpo; underage→"Itens removidos"+itens 18+ fora; timeout→"Sessão expirada"+retry), dirigindo `AppIdade18` real com `verifyServiceProvider`/`ageCheckTimingProvider` sobrescritos. **Roda EM DEVICE** (`flutter test integration_test` / `flutter drive`). Headless não roda mais: o `google_fonts` 6.3.0 lança no `LiveTestWidgetsFlutterBinding` (fetch on → `path_provider` MissingPlugin; fetch off → "font não está nos assets"). Os mesmos 3 fluxos têm cobertura headless equivalente em `shop_page_test.dart` + `age_check_page_test.dart` (verdes).

### M-DS — Design System
- **Não usa Claude Design** — DS 100% em Dart (decisão do `code-checkpointv2.md`).
- **Paleta**: primária azul govtech `#1351B4` (espírito gov.br), acento teal `#0F6B5F`. Trocar identidade = editar só `lib/core/theme/app_colors.dart`.
- **`AppSemanticColors`** é `ThemeExtension` (success/warning/info × color/on/container/onContainer); `error` fica no `ColorScheme`. Ler via `context.semantic` ou `Theme.of(context).extension<AppSemanticColors>()!`.
- **Tipografia** via `google_fonts` (Inter). Runtime fetching ON em produção (baixa+cacheia no device), OFF nos testes via `test/flutter_test_config.dart` + `integration_test/flutter_test_config.dart`. Sem Inter bundlado, cai na fonte do sistema — aceitável no MVP; bundlar `.ttf` é TODO opcional (evita chamada ao Google).
- **`AppButton`** encapsula `FilledButton`/`OutlinedButton` (então `find.widgetWithText(FilledButton, ...)` ainda funciona p/ primary). `loading` troca rótulo por spinner e fica inerte.
- **`StatusView`** é o núcleo dos 8 estados da verificação: `icon` **ou** `busy:true`, `tone` (neutral/success/warning/danger/info), até 2 ações (primary=`AppButton`, secondary=`TextButton`), slot `child` (usado p/ `AppBanner`), `footnote` (usado p/ `pollCount`).
- **`ProductCard`** recebe primitivos (`name`/`priceLabel`/`is18Plus`/`quantity`/callbacks) — `lib/core` não importa modelos de feature. Stepper: `Icons.add`/`Icons.remove` (selectors de teste migrados de `Icons.add_circle`/`ListTile`).
- **Flutter 3.24.5**: usar `CardTheme`/`DialogTheme` (não `CardThemeData`/`DialogThemeData`, que são de versões posteriores).
- `AgeCheckStatusView` (M3/M5) reescrita sobre `StatusView`+`AppBanner`; `_BusyLayout`/`_StatusLayout` removidos. `ShopPage` reescrita sobre `ProductCard`/`AppButton`/`AppBanner(info)`; `_ProductTile`/`_AdultBadge`/`_CheckoutBar.FilledButton` trocados.

## Arquivos
```
docs/                                   .md v1 + v2 (v2 = fontes de verdade); teste-real-passo-a-passo.md = runbook infra+Codemagic+device
pubspec.yaml                            + google_fonts (M-DS)
codemagic.yaml                          [v10] CI Codemagic: workflow android-debug-test → APK debug com --dart-define do grupo verify_service
web/                                    plataforma web (flutter create --platforms=web) p/ a demo
android/app/src/debug/AndroidManifest.xml   [v10] libera cleartext HTTP só em debug (+ res/xml/network_security_config_debug.xml)
lib/features/diagnostics/diagnostics_page.dart  [v10] tela /diag (QA): config efetiva + dispara health/vp-request/status/result isolados
lib/main.dart                           entrypoint REAL — fala com o Verify Service via --dart-define
lib/main_demo.dart                      entrypoint DEMO — pluga o mock M4 + stub de deep link (flutter run -d chrome -t lib/main_demo.dart)
lib/demo/demo_app.dart                  DemoApp (AppIdade18 + FAB "Demo" p/ trocar VerifyScenario) + demoMockServerProvider
lib/core/config/app_config.dart         schemes, base URL, clientId, presentationDefinitionId
lib/core/router/app_router.dart         routerProvider + AppRoutes ("/" e "/verify")
lib/core/theme/app_colors.dart          [M-DS] ColorScheme light/dark (azul govtech) + AppSemanticColors (ThemeExtension) + context.semantic
lib/core/theme/app_typography.dart      [M-DS] TextThemeFor(scheme) via GoogleFonts.interTextTheme
lib/core/theme/app_spacing.dart         [M-DS] grid 8px
lib/core/theme/app_radius.dart          [M-DS] raios
lib/core/theme/app_motion.dart          [M-DS] durações/curvas + adaptive() (respeita reduzir-movimento)
lib/core/theme/app_theme.dart           [M-DS] AppTheme.light/.dark a partir dos tokens (botões min 48px)
lib/core/widgets/widgets.dart           [M-DS] barrel
lib/core/widgets/app_button.dart        [M-DS] AppButton (primary/secondary/loading/disabled)
lib/core/widgets/product_card.dart      [M-DS] ProductCard (nome/preço/selo 18+/stepper) — recebe primitivos
lib/core/widgets/adult_badge.dart       [M-DS] AdultBadge ("18+")
lib/core/widgets/status_view.dart       [M-DS] StatusView (icon ou busy, tone, 2 ações, child, footnote) — usado nos 8 estados
lib/core/widgets/app_banner.dart        [M-DS] AppBanner (success/error/warning/info)
lib/core/utils/currency.dart                           [M1] formatBrl
lib/features/shop/domain/product.dart                   [M1] Product
lib/features/shop/data/product_repository.dart          [M1] ProductRepository + MockProductRepository + catalogProvider
lib/features/shop/application/cart_controller.dart      [M1] CartController + CartState + CartLine
lib/features/shop/presentation/shop_page.dart          [M1] ShopPage (lista + carrinho + gate 18+ + gate de retorno)
lib/features/age_check/presentation/age_check_page.dart  [M3/M5] AgeCheckPage + AgeCheckStatusView (público, só-visual)
lib/features/age_check/application/age_check_controller.dart  [M3] AgeCheckPhase/State/Session/Timing/Outcome + AgeCheckController + providers
lib/features/age_check/data/verify_contract.dart       [M4/v9] paths (+ /actuator/health) + regex + campos + status + VerifyPresentation.ecaAgeCheck (PD completa)
lib/features/age_check/data/verify_mock_server.dart     [M4/v9] VerifyMockServer — shape do tutorial (requestUri no topo, epoch ms, health); VerifyScenario, VcShape
lib/features/age_check/data/verify_service.dart         [M2/v9] VerifyService (+ checkHealth) + VerifyConfig (presentationDefinition Map, sendOrigin) + sealed VerifyException
test/app_scaffold_test.dart             2 testes end-to-end (boot na loja; add 18+ → finalizar → AgeCheckPage real)
test/verify_mock_server_test.dart       [M4/v9] ~20 testes (shape do tutorial, health, progressão de status, vcShape, troca de cenário)
test/verify_service_test.dart           [M2/M5/v9] ~42 testes (deep link sem origin, PD completa no corpo, requestUri no topo, checkHealth, parser defensivo, isTrustedReturn, guard TLS)
test/age_check_controller_test.dart     [M3] 13 testes (desfechos; onAppResumed sem duplicar loop; wake; retry; reset)
test/age_check_page_test.dart           [M3/M5] 4 de fluxo + 9 de renderização por fase (AgeCheckStatusView) + callbacks
test/cart_controller_test.dart          [M1] 9 testes (add/remove/quantidade/total/hasAdultItem/removeAdultItems/clear)
test/shop_page_test.dart                [M1] 6 testes de widget (lista, total, gate 18+ → /verify, diálogo, gate de retorno verified/blocked)
test/currency_test.dart                 [M1] formatBrl
test/design_system_test.dart            [M-DS] 12 testes (AppButton/ProductCard/StatusView/AppBanner, tema claro+escuro)
test/diagnostics_page_test.dart         [v10] 3 testes (config, health, passos 1→2 encadeados)
test/flutter_test_config.dart           [M-DS] desliga google_fonts runtime fetching nos testes
integration_test/flutter_test_config.dart  [M-DS] idem p/ integration_test headless
integration_test/flow_test.dart        [M5] 3 cenários ponta a ponta (over18 / underage / timeout) — roda EM DEVICE
Total: flutter test → 116/116
android/app/src/main/AndroidManifest.xml  intent-filter app18 + queries openid4vp
ios/Runner/Info.plist                     CFBundleURLTypes app18 + LSApplicationQueriesSchemes openid4vp
```

## Bugs Conhecidos / TODOs
- [ ] Confirmar VERIFY_BASE_URL / onboarding (client_id)
- [ ] Confirmar sandbox/issuer para emitir ECACredential de teste
- [ ] **Máquina de dev incompleta:** `flutter doctor` acusa Android SDK ausente e Xcode/CocoaPods incompletos → não dá pra compilar/rodar em device nesta máquina ainda. Instalar Android Studio + SDK, Xcode completo (`xcodebuild -runFirstLaunch`) e CocoaPods antes de validar `flutter run`.
- [x] ~~Riverpod vs Bloc~~ → Riverpod
- [x] ~~Backend mock vs real~~ → mock (M4) no MVP, real via --dart-define

## Última Entrega
**Guarda de config sentinela** — o dev reportou erro "Falha ao criar a solicitação de
verificação" ao simular. Causa: rodar sem `--dart-define-from-file` (ex.: Xcode/simulador
direto) deixa `VERIFY_BASE_URL` no default `https://verify.invalid` (host que nunca
resolve por design, RFC 2606) → `DioException` de conexão, sem código HTTP. Corrigido:
- `AppConfig.verifyBaseUrlSentinel` (constante nomeada, antes string mágica repetida).
- `VerifyService` (factory) agora detecta esse sentinel **antes** de tentar rede (só
  quando `dio` não foi injetado) e lança `VerifyConfigException` com mensagem
  explicando a causa e o comando certo (`make run`). 2 testes novos em
  `verify_service_test.dart` (grupo "sentinel guard").
- `docs/build-ios.md`: aviso de que rodar via Xcode/`Runner.xcworkspace` direto pula os
  `--dart-define` (usar sempre `flutter run .../make run` com
  `--dart-define-from-file=config/local.json`) e que o simulador iOS não tem a Inji
  Wallet instalada (fluxo para em `WalletUnavailableException`).
- `config/local.json` (fora do git) está hoje apontando pro **Dataprev HML**
  (`injiverify.credenciaisverificaveis-hml.dataprev.gov.br`, mesma instância do exemplo
  oficial pernacabeluda.online), não pra VPS própria — confirmado alcançável (health UP).
`flutter analyze` 0 issues · `flutter test` **119/119**.

## Entrega anterior
**Rodar local (Mac)** — o Android SDK **existe** (`~/Android`, SDK 34, JDK 17); faltava `flutter config --android-sdk ~/Android` (feito). Descobertas + ajustes:
- **`app_links` removido** (não era importado em lugar nenhum) — quebrava `flutter build apk` com "compileSdkVersion is not specified" (o `app_links` 6.4.1 exige AGP 8.6.1 + `flutter` ext nos subprojetos de plugin). O retorno da carteira usa `AppLifecycleState.resumed`, não `app_links`.
- `android/app/build.gradle`: `compileSdk = 34` e `ndkVersion = "25.1.8937393"` **literais** (não via `flutter.*`) — hygiene p/ os plugins resolverem no config. Scaffold segue AGP 8.1.0 / Gradle 8.3 / Kotlin 1.8.22.
- **Disco**: a máquina estava a 99% (127 MiB livres) → `flutter test` travava. Removido `build/` (~3 GB liberados). `make clean` ajuda.
- **`flutter build apk --debug` gera** `build/app/outputs/flutter-apk/app-debug.apk` (~88 MB) localmente. `flutter test` 116/116. `flutter analyze` 0 issues.
- **Config de execução**: `Makefile` (`make demo|run|apk|test|analyze|help`), `.vscode/launch.json` (Demo/App real × Chrome/device), `config/local.example.json` → `config/local.json` (gitignored) p/ `--dart-define-from-file`. `README.md` reescrito com a seção "Rodar local".
- iOS/macOS seguem bloqueados (Xcode incompleto + CocoaPods ausente).

## Entrega anterior
**Prontidão para o teste real** — 3 ajustes pedidos:
1. **`--dart-define=VERIFY_ALLOW_INSECURE=true`** (`AppConfig.allowInsecure` → `VerifyConfig.allowInsecure`): libera `http://` no guard de TLS para testar contra um Verify Service em LAN sem ngrok. Complemento no Android: `android/app/src/debug/AndroidManifest.xml` + `src/debug/res/xml/network_security_config_debug.xml` liberam cleartext **só em builds debug**; release segue exigindo HTTPS nas duas camadas.
2. **`origin` no deep link** (`AppConfig.sendOrigin` → `VerifyConfig.sendOrigin`): **default `true`** — o guia mobile do VerificaIdade (`integra-mobile.html`) exige `origin=app18://` no fluxo same-device (é por ele que a wallet volta pro app). `--dart-define=VERIFY_SEND_ORIGIN=false` só p/ experimentar. (O guia web/QR omite `origin` por ser cross-device — não é o nosso caso.)
3. **Tela de diagnóstico** `lib/features/diagnostics/diagnostics_page.dart`, rota `/diag`, acessível pela AppBar da `ShopPage` **só em `kDebugMode`** (ícone `settings_ethernet`). Mostra a config efetiva (`VERIFY_BASE_URL`, `clientId`, flags…) e dispara cada chamada isolada: health, `POST /vp-request` (+abre carteira), `GET status`, `GET vp-result` — com output cru e a exceção tipada em `AppBanner`.

`flutter analyze` 0 issues · `flutter test` **116/116** (+ `verify_service_test` allowInsecure, + `diagnostics_page_test` 3) · web (demo) compila.

## Entrega anterior
**Alinhamento ao tutorial oficial VerificaIdade** (o dev apontou https://verificaidade.dev/quickstart.html como guia de implementação). Deltas aplicados vs. o que estava no plano §4:

| Item | Antes | Agora (tutorial) |
|---|---|---|
| `presentationDefinition` no corpo do vp-request | string `"eca-age-check"` | **objeto completo** (`input_descriptors`/`constraints`/`format`) — `VerifyPresentation.ecaAgeCheck()` em `verify_contract.dart`, cópia fiel do api-reference |
| `requestUri` na resposta | lido de `authorizationDetails.requestUri` | lido do **topo** da resposta (fallback p/ authorizationDetails) |
| Deep link | `origin` sempre | mobile same-device (`integra-mobile.html`) manda `client_id` + `request_uri` + **`origin`**; `VerifyConfig.sendOrigin` **default `true`**, opt-out via `--dart-define=VERIFY_SEND_ORIGIN=false` |
| `authorizationDetails` | `{clientId, requestUri, responseUri, nonce, presentationDefinition}` | `{clientId, nonce, responseUri, responseType:"vp_token", responseMode:"direct_post", issuedAt}` |
| `expiresAt` / `issuedAt` | ISO8601 string | **epoch ms** (int) |
| `responseUri` path | `/v1/verify/vp-submission` | `/v1/verify/vp-submission/direct-post` |
| Health check | — | `checkHealth()` → `GET /v1/verify/actuator/health` → `{status:"UP"}`; mock responde |
| `VERIFY_CLIENT_ID` default | `app-idade18-dev` | `did:web:localhost:v1:verify` (forma DID do tutorial) |
| `AgeCheckTiming` default | `maxPolls: 90` | `maxPolls: 150` (tutorial: `maxAttempts=150, intervalMs=2000` → ~5 min) |
| Auth headers | — | confirmado: **nenhum** (identidade vai no `clientId` do corpo) |

Já batiam com o tutorial (sem mudança): base `/v1/verify`, os 3 caminhos, `{status: ACTIVE|VP_SUBMITTED|EXPIRED}`, `{vpResultStatus, vcResults:[{vc:{credentialSubject:{isOver18}}, vcStatus}]}`, `vcStatus SUCCESS|INVALID|EXPIRED`, polling → VP_SUBMITTED → getResult / EXPIRED → parar.
`VerifyConfig`: `presentationDefinitionId` (String) → `presentationDefinition` (Map, default `ecaAgeCheck`) + getter `presentationDefinitionId` + `sendOrigin`.
`flutter analyze` 0 issues · `flutter test` **112/112** · web (demo) compila.

## Entrega anterior
**Demo web rodável** (sem Android SDK/Xcode).
- `flutter create --platforms=web .` → pasta `web/`.
- `lib/main_demo.dart` + `lib/demo/demo_app.dart`: rodam o `AppIdade18` real com `verifyServiceProvider` → mock do M4, `uriLauncher` stub (só loga a URL `openid4vp://`), `ageCheckTimingProvider` lento o bastante p/ ver o polling. FAB "Demo" abre um bottom sheet p/ trocar o `VerifyScenario` (maior/menor de 18, inválida, expirada, timeout) e zerar carrinho+verificação.
- `main.dart` (real) intacto. `test/widget_test.dart` regenerado pelo `flutter create` foi removido de novo.
- Rodar: `flutter run -d chrome -t lib/main_demo.dart`. Build: `flutter build web -t lib/main_demo.dart` (→ `build/web`, ~25MB). Ambos os entrypoints compilam p/ web. `flutter test` 107/107. `flutter analyze` 0 issues.

## Entrega anterior
**M-DS — Design System em Dart** (módulo inserido pelos docs v2, entre M0 e M4; feito por último por o app já existir).
- Tokens: `app_colors` (ColorScheme light/dark, azul govtech `#1351B4` + teal; `AppSemanticColors` como `ThemeExtension` p/ success/warning/info; `context.semantic`), `app_typography` (Inter via `google_fonts`), `app_spacing` (8px), `app_radius`, `app_motion` (+ `adaptive()` respeita reduzir-movimento).
- `AppTheme.light/.dark` reescrito a partir dos tokens; `MaterialApp` com `themeMode: ThemeMode.system`. Alvo de toque ≥48px nos temas de botão.
- Componentes `lib/core/widgets/`: `AppButton` (primary/secondary/**loading**/disabled), `ProductCard` (selo 18+ + stepper), `AdultBadge`, `StatusView` (icon **ou** busy, `tone`, até 2 ações, slot `child`, `footnote` — cobre os 8 estados), `AppBanner` (success/error/warning/info).
- Religado: `ShopPage` usa `ProductCard`/`AppButton`/`AppBanner(info)`; `AgeCheckStatusView` usa `StatusView` + `AppBanner` (erro/expirado). `_ProductTile`/`_AdultBadge`/`_BusyLayout`/`_StatusLayout` removidos.
- `google_fonts` runtime fetching desligado em teste via `flutter_test_config.dart` (produção: baixa+cacheia Inter no device).
- 12 testes novos (`design_system_test.dart`) + selectors dos testes de shop/scaffold/flow migrados de `ListTile`/`Icons.add_circle` → `ProductCard`/`Icons.add`.
- `flutter analyze`: 0 issues. `flutter test`: **107/107**.

## Estado do MVP — o que falta para o TESTE REAL
**Código do app: pronto. INJI Verify Service: NO AR** — `https://verify.beachd.com.br` (VPS dedicada Hostinger `2.25.149.198`; Caddy + `injistack/inji-verify-service:0.18.1` + Postgres 15; TLS Let's Encrypt; `/v1/verify/actuator/health` = UP; `/v1/verify/did.json` OK). Detalhes/operação: **`docs/vps-inji.md`**. `config/local.json` já preenchido com esses valores.
Falta:
1. **Onboarding VerificaIdade (externo):** APK da **Inji Wallet** + **`ECACredential` de teste** emitida numa wallet (issuer/staging). Confirmar se `did:web:verify.beachd.com.br:v1:verify` precisa registro no gateway deles ou se o `did.json` auto-hospedado basta.
2. **Env vars no Codemagic** (grupo `verify_service`): `VERIFY_BASE_URL=https://verify.beachd.com.br`, `VERIFY_CLIENT_ID=did:web:verify.beachd.com.br:v1:verify`.
3. **Gerar APK**: `make apk` (local, Android SDK já configurado) ou workflow `android-debug-test` no Codemagic → instalar (`adb install`) no device Android que tem a Inji Wallet + a credencial.
4. **Testar**: `/diag` (ícone na AppBar, só em debug) → "GET /actuator/health" = UP → fluxo pela Loja (item 18+ → Finalizar → Verificar idade → autorizar na wallet → volta ao app).
5. **Limpar o box antigo** `147.79.82.31`: `docker stack rm injiverify` (quando responder — está sobrecarregado, load ~40, 37 serviços; SSH deu timeout).

## Depois do teste real
- **Fase 4:** revisão seg/LGPD final + build assinado (keystore Android, signing/provisioning iOS).
- **Backend BFF** (`backend-integracao.md` não existe): mover `baseUrl` p/ o BFF.
- **Opcional:** bundlar `Inter-*.ttf`; `integration_test/flow_test.dart` voltar headless; `app_links` p/ capturar o retorno; fidelidade visual iFood (plano §2.1).

## Fuel Gauge
- Msgs trabalho: 11 · Entregas código: 10 (…, demo web, contrato v9, prontidão-teste v10) · Zona: 🟢 Verde
- Próximo checkpoint: primeiro teste real em device · Capacidade restante estimada: ~45%
