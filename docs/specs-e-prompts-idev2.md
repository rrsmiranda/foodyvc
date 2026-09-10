# Specs & Prompts para IDE (Claude via API) — App 18+ VerificaIdade (Flutter)

Pacote para desenvolver na IDE com agente Claude via API. Cada módulo tem: **objetivo**, **critérios de aceite** e um **prompt pronto pra colar**. Ordem de execução no fim.
Contexto de base a injetar no agente: `plano-verificaidade-flutter.md` + `code-checkpoint.md`.

---

## Prompt de kickoff (cole PRIMEIRO na IDE)

> Coloque os 3 arquivos em `docs/` no repo antes de colar.

```
Você é um engenheiro Flutter sênior. Vamos construir um app iOS + Android de
verificação de idade 18+ (VerificaIdade / OID4VP), em que uma casca de simulação
de compra dispara a verificação ao finalizar.

FONTES DE VERDADE — leia os 3 arquivos antes de agir, nesta ordem:
1. docs/code-checkpoint.md   — contexto, stack, decisões, próxima tarefa.
2. docs/plano-verificaidade-flutter.md — arquitetura, contrato REST (seção 4),
   mapeamento RN→Flutter (seção 2), LGPD (seção 6).
3. docs/specs-e-prompts-ide.md — módulos M0–M5 com critérios de aceite e ordem.
Se algo na sua suposição conflitar com o checkpoint, o CHECKPOINT prevalece.

REGRAS:
- Decisões do checkpoint são definitivas; não re-pergunte o que já está decidido.
- Estrutura feature-first: lib/core, lib/features/{shop,age_check}.
- Entregue arquivos COMPLETOS, sem placeholders nem "TODO". Código pronto pra rodar.
- Não invente endpoints nem SDK: a integração é REST puro + deep link (ver plano).
- Um módulo por vez, na ordem: M0 → M-DS → M4 → M2 → M3 → M1 → M5.
- Ao terminar cada módulo: liste os arquivos criados/alterados, rode `flutter analyze`
  (e o teste relevante), diga como eu verifico, ATUALIZE docs/code-checkpoint.md
  (tarefas + arquivos + próxima tarefa) e então PARE e aguarde eu dizer "continua".

Comece agora pelo M0 (scaffold + deep link iOS/Android), seguindo os critérios de
aceite e o prompt do M0 no specs.
```

Depois, avance dizendo **"continua"** a cada módulo. Os prompts por módulo abaixo são opcionais — o kickoff já manda seguir o specs; use-os se quiser reforçar um módulo específico.

---

## Como usar

1. **Abra a sessão** na IDE injetando `code-checkpoint.md` (contexto mínimo — evita reler histórico).
2. Rode os módulos **na ordem** (M0 → M-DS → M4 → M2 → M3 → M1 → M5). M4 (mock) antes de M2/M3 permite testar sem infra; M-DS (tema) antes das telas.
3. **Roteamento de modelo:** specs/arquitetura/revisão = tier Opus; implementação/testes = tier Sonnet; configs = tier Haiku.
4. A cada 3–5 entregas, peça ao agente para **atualizar o checkpoint**.
5. iOS+Android: mesma base; só os ajustes de scheme por plataforma (ver plano seção 2) diferem.

---

## M0 — Scaffold + deep link (tier Haiku)

**Objetivo:** projeto Flutter compilando em iOS e Android, deps instaladas, scheme de deep link configurado nas duas plataformas.

**Critérios de aceite:**
- `flutter run` sobe em Android e iOS.
- `pubspec.yaml` com: `dio`, `url_launcher`, `go_router`, `flutter_riverpod`, `app_links`; dev: `integration_test`, `mockito` ou `http_mock_adapter`.
- Android `AndroidManifest.xml` com `intent-filter` do scheme `seuapp`.
- iOS `Info.plist` com `CFBundleURLTypes`(`seuapp`) **e** `LSApplicationQueriesSchemes` contendo `openid4vp`.
- Estrutura `lib/core` + `lib/features/{shop,age_check}`.

**Prompt:**
```
Crie um projeto Flutter novo (iOS + Android) chamado app_idade18.
Estrutura feature-first: lib/core, lib/features/shop, lib/features/age_check.
pubspec: dio, url_launcher, go_router, flutter_riverpod, app_links; dev_dependencies: integration_test (sdk), http_mock_adapter.
Configure deep link com scheme "app18":
- Android: intent-filter (VIEW + BROWSABLE + DEFAULT + data scheme app18) na activity principal.
- iOS Info.plist: CFBundleURLTypes com CFBundleURLSchemes=[app18] E LSApplicationQueriesSchemes contendo "openid4vp".
Configure go_router com rotas: "/" (ShopPage) e "/verify" (AgeCheckPage).
Entregue os arquivos completos alterados/criados. Sem placeholders.
```

---

## M-DS — Design System: tokens + tema Flutter (decisões de token = tier Opus; implementação = tier Sonnet)

**Objetivo:** o sistema visual como **código Dart**, sem depender do Claude Design. Tokens → `ThemeData` (claro/escuro) → componentes-núcleo.

**Critérios de aceite:**
- `lib/core/theme/`: `app_colors.dart` (light+dark, com semânticos success/warning/error/info), `app_typography.dart` (TextTheme via `google_fonts`), `app_spacing.dart` (grid 8px), `app_radius.dart`, `app_motion.dart`.
- `app_theme.dart` expõe `ThemeData` light e dark; `MaterialApp` usa ambos + `themeMode.system`.
- `lib/core/widgets/`: `AppButton` (primary/secondary/disabled/**loading**), `ProductCard` (com selo "18+"), `StatusView` (título+ícone+descrição+ação — usado nos 8 estados da verificação), `AppBanner` (success/error/warning).
- WCAG AA; alvo de toque ≥48px. Adicionar `google_fonts` ao `pubspec`.

**Prompt:**
```
No app_idade18, crie o design system em Dart (sem Claude Design):
- Adicione google_fonts ao pubspec.
- lib/core/theme/: app_colors (light+dark, com success/warning/error/info),
  app_typography (TextTheme via google_fonts), app_spacing (grid 8px),
  app_radius, app_motion. app_theme.dart expõe ThemeData light e dark.
- Ligue no MaterialApp com themeMode.system.
- lib/core/widgets/: AppButton (primary/secondary/disabled/loading),
  ProductCard (com selo "18+"), StatusView (título+ícone+descrição+ação, usado
  nos 8 estados da verificação), AppBanner (success/error/warning).
- WCAG AA, alvo de toque >=48px.
Paleta/tipografia: [cole a decisão do ds-checkpoint.md OU peça 2 opções de
cor primária adequadas a govtech/confiança e escolha antes de gerar].
Arquivos completos.
```

---

## M1 — Casca de simulação de compra (tier Sonnet)

**Objetivo:** uma tela com lista de produtos mock (≥1 com `is18Plus: true`), adicionar ao pedido e botão **Finalizar compra** que roteia para `/verify` só quando há item 18+.

**Critérios de aceite:**
- Model `Product { id, nome, preco, is18Plus }`; lista mock em memória/asset.
- Estado do pedido via Riverpod.
- Botão "Finalizar": se pedido contém item 18+ → `context.go('/verify')`; senão → diálogo "Compra concluída".
- Sem lógica de pagamento — é só simulação.

**Prompt:**
```
No projeto app_idade18, crie a feature "shop":
- Product { String id; String nome; double preco; bool is18Plus }.
- Repositório mock com ~5 produtos, ao menos 1 com is18Plus=true (ex.: uma bebida alcoólica).
- CartController (Riverpod) com add/remove e getter hasAdultItem.
- ShopPage: lista de produtos com botão "+"; rodapé com total e botão "Finalizar compra".
  Ao finalizar: se hasAdultItem -> context.go('/verify'); senão -> AlertDialog "Compra concluída".
Entregue os arquivos completos. Siga as decisões do checkpoint.
```

---

## M4 — Mock server do INJI Verify Service (tier Sonnet)

**Objetivo:** stub das 3 rotas do Verify Service, para exercitar todos os estados da verificação **sem** VM/wallet/credencial. Implementar como `http_mock_adapter` no `dio` (ou `shelf` local), com cenários selecionáveis.

**Contrato a simular (ver plano seção 4):**
- `POST /v1/verify/vp-request` → `{ transactionId, requestId, authorizationDetails{ responseUri, ... }, expiresAt }`.
- `GET /v1/verify/vp-request/{requestId}/status` → `ACTIVE` nas primeiras N chamadas, depois `VP_SUBMITTED` (ou `EXPIRED` no cenário de timeout).
- `GET /v1/verify/vp-result/{transactionId}` → `{ vpResultStatus:"SUCCESS", vcResults:[{ vc:{ credentialSubject:{ isOver18 }}, vcStatus }] }`.

**Critérios de aceite:**
- Cenários chaveáveis: `over18`, `underage`, `invalid`, `expired`, `timeout`.
- Permite testar M3 e os testes M5 sem rede real.

**Prompt:**
```
Crie um mock do INJI Verify Service para o app_idade18 usando http_mock_adapter sobre o dio.
Rotas e payloads conforme o contrato REST do plano (seção 4).
Exponha um enum VerifyScenario { over18, underage, invalid, expired, timeout } que controla:
- status: retorna ACTIVE 2x e depois VP_SUBMITTED (ou EXPIRED no cenário timeout).
- vp-result: isOver18 e vcStatus conforme o cenário (over18->true/SUCCESS; underage->false/SUCCESS; invalid->INVALID; expired->EXPIRED).
Deixe o mock injetável no VerifyService via um dio configurável. Arquivos completos.
```

---

## M2 — verify_service.dart (tier Sonnet)

**Objetivo:** as 3 chamadas REST + montagem do deep link `openid4vp://` + parsing defensivo de `isOver18`.

**Critérios de aceite:**
- `createVpRequestAndOpenWallet()` → POST vp-request, monta `openid4vp://authorize?client_id=&request_uri=&origin=app18://`, abre via `launchUrl(externalApplication)`; retorna `{transactionId, requestId}`.
- `pollStatus(requestId)` → `ACTIVE|VP_SUBMITTED|EXPIRED`.
- `getResult(transactionId)` → `{verified, underage}`; trata `vc` como String OU Map e `credentialSubject` em `vc.credential.credentialSubject` OU `vc.credentialSubject`; mapeia `vcStatus` `INVALID`/`EXPIRED` para erro tratado.
- Base URL configurável (troca mock ↔ real sem mudar chamadas).

**Prompt:**
```
Crie lib/features/age_check/data/verify_service.dart no app_idade18.
Baseie-se no contrato REST do plano (seção 4) e no mapeamento RN->Flutter (seção 2).
Métodos:
- Future<({String transactionId, String requestId})> createVpRequestAndOpenWallet()
- Future<String> pollStatus(String requestId)  // ACTIVE|VP_SUBMITTED|EXPIRED
- Future<({bool verified, bool underage})> getResult(String transactionId)
Detalhes:
- BASE_URL, CLIENT_ID e ORIGIN (app18://) configuráveis.
- Deep link: openid4vp://authorize?client_id=&request_uri=&origin=  via url_launcher (LaunchMode.externalApplication); se falhar, lançar erro "instale a Inji Wallet".
- getResult: parsing defensivo (vc String ou Map; credentialSubject em dois caminhos possíveis); vcStatus INVALID/EXPIRED viram exceção tipada.
- Receba um Dio injetável (para plugar o mock M4).
Arquivos completos, sem placeholders.
```

---

## M3 — AgeCheckPage + máquina de estados + lifecycle (tier Sonnet; debugging do lifecycle = tier Opus)

**Objetivo:** tela que orquestra o fluxo e **retoma o polling quando o app volta ao foreground** (`AppLifecycleState.resumed`).

**Estados:** `idle → abrindoWallet → aguardando(polling) → verificando → success | underage | expired | error`.

**Critérios de aceite:**
- `WidgetsBindingObserver.didChangeAppLifecycleState`: em `resumed`, reinicia o polling da sessão ativa (sem duplicar loops).
- `success` → libera a compra (volta para shop com pedido concluído). `underage` → bloqueia. `expired`/`error` → permite retry.
- Loop de polling protegido por flag (não acumula timers).

**Prompt:**
```
Crie lib/features/age_check/presentation/age_check_page.dart no app_idade18.
Use o VerifyService (M2). Implemente a máquina de estados:
idle, abrindoWallet, aguardando, verificando, success, underage, expired, error.
Fluxo: handleVerify -> createVpRequestAndOpenWallet -> guarda sessão -> inicia polling.
Polling: loop chamando pollStatus; em VP_SUBMITTED -> getResult -> success/underage;
EXPIRED -> estado expired. Proteja com flag para não duplicar loops.
Lifecycle: com WidgetsBindingObserver, em AppLifecycleState.resumed reinicie o polling da sessão ativa.
UI: mostra o estado atual, erros e botão "Verificar idade"/"Tentar de novo".
success -> conclui a compra; underage -> bloqueia. Arquivos completos.
```

---

## M5 — Testes (tier Sonnet)

**Objetivo:** cobrir o parser e os estados, e o fluxo ponta a ponta contra o mock (M4). Matriz de casos = plano seção 5.

**Critérios de aceite:**
- **Unit:** parser `isOver18` (vc String, vc Map, campo ausente, INVALID, EXPIRED).
- **Widget:** AgeCheckPage renderiza cada estado (success/underage/expired/error).
- **Integration:** golden path (over18) + underage + timeout(expired) usando o mock.

**Prompt:**
```
Crie testes para o app_idade18:
- test/verify_service_test.dart: parser de getResult com vc como String e como Map, credentialSubject nos dois caminhos, campo ausente, vcStatus INVALID e EXPIRED (usando o mock M4/dio injetável).
- test/age_check_page_test.dart (widget): renderização de cada estado.
- integration_test/flow_test.dart: cenários over18 (sucesso->compra liberada), underage (bloqueio), timeout (expired->retry) via VerifyScenario do mock.
Arquivos completos.
```

---

## Ordem de execução

`M0 (scaffold) → M-DS (tema+componentes) → M4 (mock) → M2 (verify_service) → M3 (AgeCheckPage+lifecycle) → M1 (casca compra) → M5 (testes)`

> M1 pode vir logo após M0 se quiser ver a navegação antes; mas M4 antes de M2/M3 é o que te deixa **testar tudo sem infra**. Quando `VERIFY_BASE_URL` + credencial de teste existirem (plano Fase 0), troque a base URL e rode a matriz real em device físico.
