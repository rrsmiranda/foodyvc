# Plano de Desenvolvimento — App 18+ com VerificaIdade (Flutter)

> App mobile (iOS + Android) estilo delivery/loja, cujo checkout de produtos **18+** é liberado por **verificação de idade via credencial verificável** (VerificaIdade / stack MOSIP INJI, protocolo OID4VP).
> Referência de UX: clone iFood (catálogo → carrinho → checkout). Referência de verificação: https://verificaidade.dev/
> Desenvolvimento assistido por IA, com roteamento de modelo por tarefa.

---

## 0. Correções conceituais (leia antes de começar)

- **Seu app é um *verificador* (relying party), não um emissor.** Ele pede uma apresentação de credencial e lê o resultado `isOver18`. A *emissão* do `ECACredential` é feita fora do app, na carteira do cidadão.
- **Não existe SDK Flutter (nem RN).** A integração é **REST puro + deep link**. Isso torna o Flutter plenamente viável — basta replicar 3 endpoints e o retorno por lifecycle.
- **"Testar emissão de credenciais"** = ter **credenciais de teste emitidas numa Inji Wallet** para rodar o fluxo. É uma dependência de ambiente (issuer/sandbox), não uma feature do app.

---

## 1. Arquitetura alvo

```
┌──────────────────────────── App Flutter (iOS/Android) ────────────────────────────┐
│  Simulação de compra (casca):  Lista de produtos  →  [+] item 18+  →  FINALIZAR     │
│                                     │                                               │
│                        [pedido tem item 18+?] ── não ──▶ compra concluída          │
│                                     │ sim                                            │
│                                     ▼                                               │
│                        Módulo de Verificação de Idade (★ PRODUTO)                    │
│                        AgeCheckScreen + verify_service.dart                         │
└──────────────┬───────────────────────────────────────────────┬────────────────────┘
               │ 1) POST /vp-request                            │ deep link openid4vp://
               ▼                                                ▼
        INJI Verify Service  ◀── 3) POST /vp-submission ──  Inji Wallet (device)
        (VM + Docker)              (a wallet chama, não você)  guarda o ECACredential
               ▲
               │ 2) GET /status (polling)  4) GET /vp-result → isOver18
```

**Componentes externos (não são seu código, mas bloqueiam os testes):**
- `INJI Verify Service` acessível em `VERIFY_BASE_URL` (VM+Docker) — health: `GET /v1/verify/actuator/health`.
- Credenciais de gateway (Onboarding).
- Inji Wallet instalada no device + `ECACredential` de teste emitido nela.

---

## 2. Mapeamento React Native/Expo → Flutter (a peça que falta na doc)

| Conceito na doc (RN/Expo) | Equivalente Flutter | Pacote |
|---|---|---|
| `expo-linking` abrir deep link | `launchUrl(uri, mode: LaunchMode.externalApplication)` | `url_launcher` |
| `scheme` no `app.json` | Android: `<intent-filter>` no `AndroidManifest.xml`; iOS: `CFBundleURLSchemes` no `Info.plist` | nativo |
| Retorno da wallet ao app | registro de custom scheme + observador de lifecycle | `app_links` (opcional) |
| `AppState "active"` → retoma polling | `WidgetsBindingObserver.didChangeAppLifecycleState` → `AppLifecycleState.resumed` | nativo (`WidgetsBinding`) |
| `fetch()` | client HTTP | `dio` (ou `http`) |
| Estado do componente | gerência de estado | `flutter_riverpod` (default) ou `bloc` |
| `navigation.replace(...)` | roteamento declarativo | `go_router` |

> **Ponto crítico (igual ao da doc):** o mecanismo central do fluxo *same-device* é retomar o polling quando o app volta ao foreground. Em Flutter isso é o `AppLifecycleState.resumed`. Sem ele, o app nunca sabe que o usuário autorizou na carteira.

**Deep link em Dart:**
```dart
final uri = Uri.parse('openid4vp://authorize').replace(queryParameters: {
  'client_id': clientId,
  'request_uri': requestUri,
  'origin': '$appScheme://',
});
await launchUrl(uri, mode: LaunchMode.externalApplication);
```

**Config de scheme:**
- Android (`android/app/src/main/AndroidManifest.xml`, dentro da `<activity>`):
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <data android:scheme="seuapp"/>
</intent-filter>
```
- iOS (`ios/Runner/Info.plist`): dois pontos —
  - `CFBundleURLTypes` → `CFBundleURLSchemes` = `seuapp` (retorno da wallet ao app).
  - `LSApplicationQueriesSchemes` → incluir `openid4vp` (**sem isso, `canLaunchUrl`/`launchUrl` falha silenciosamente no iOS ao tentar abrir a wallet**).
- **Teste de deep link same-device exige device físico** (iOS e Android) — simulador/emulador não roda o fluxo de carteira de forma confiável.

### 2.1 Clone iFood (repo RenanBorba) → Flutter — REFERÊNCIA OPCIONAL

> **Escopo definido:** o visual iFood serve **apenas para simular a compra**. O MVP **não** reproduz as 7 telas — basta uma casca (lista de produtos + botão Finalizar). A tabela abaixo fica como referência caso você queira aumentar a fidelidade visual **depois** que a verificação estiver pronta.

> **Natureza do repo:** clone **de interfaces** (front-end), consome **API fake** (`json-server` + Axios). Não tem carrinho nem checkout reais.

**Telas/componentes a reproduzir (do `src/`):**

| Tela (RN `src/pages`) | Componentes (RN `src/components`) | Widget/rota Flutter |
|---|---|---|
| `Dashboard` (home) | `Suggestions`, `Offers`, `Restaurants` | `DashboardPage` + listas horizontais/verticais |
| `Search` | `Categories` | `SearchPage` + grid de categorias |
| `Item` (detalhe da oferta) | — | `ItemPage` (rota de stack) |
| `Wallet` (QR Code) | — | `WalletPage` |
| `Requests` (pedidos em andamento) | — | `RequestsPage` |
| `PreviousRequests` (pedidos anteriores) | `Purchases` | `PreviousRequestsPage` |
| `Profile` | `Header/Person` | `ProfilePage` |

**Mapeamento de stack RN → Flutter:**

| Clone iFood (RN/Expo) | Equivalente Flutter |
|---|---|
| Expo | projeto Flutter |
| `react-navigation-tabs` (abas) | `BottomNavigationBar` ou `go_router` `StatefulShellRoute` |
| `react-navigation-stack` | rotas aninhadas no `go_router` |
| `styled-components` | `ThemeData` + widgets estilizados |
| `vector-icons` MaterialIcons | `Icons.*` (Material nativo) |
| `json-server` (API fake) + `axios` | mock local (JSON em assets) **ou** `json_server` + `dio` |
| `useState` / `useEffect` | `Riverpod` (ou `StatefulWidget`) |

**Onde entra o 18+ (o repo não tem checkout):** adiciona-se uma flag `is18Plus` nas `Offers`/`Item`. O gate de verificação é acoplado no **momento de confirmar o pedido a partir do `Item`** (uma ação leve "Adicionar ao pedido / Confirmar", que o clone puro não possui) → se o item for 18+, dispara o Módulo de Verificação antes de mandar para `Requests`. É a menor adição honesta sobre o clone.

---

## 3. Roadmap por fases

### Fase 0 — Pré-requisitos externos (BLOQUEANTE, resolver antes de codar o CORE)
- [ ] `VERIFY_BASE_URL` de um INJI Verify Service no ar (ou subir via VM+Docker) — validar com health check.
- [ ] Onboarding no gateway (client_id/credenciais).
- [ ] Inji Wallet instalada num **device físico** (emulador não faz bem o deep link same-device).
- [ ] `ECACredential` de teste **emitido na wallet** (definir issuer/sandbox com a equipe VerificaIdade).

### Fase 1 — Casca de simulação de compra (mínima, só pra chegar no gatilho)
- [ ] `flutter create` + estrutura feature-first (`lib/features/{shop,age_check}` + `lib/core`).
- [ ] Uma tela com lista de produtos mock, ao menos um com flag `is18Plus`.
- [ ] Adicionar item ao pedido + botão **Finalizar compra**.
- [ ] Ao finalizar: se o pedido tem item 18+ → navega para o Módulo de Verificação; senão → "compra concluída".
- [ ] (Visual iFood mais fiel = opcional, depois — ver seção 2.1.)

### Fase 2 — Módulo de Verificação de Idade (CORE)
- [ ] `verify_service.dart`: `createVpRequestAndOpenWallet()`, `pollStatus(requestId)`, `getResult(transactionId)`.
- [ ] `AgeCheckScreen`: máquina de estados `idle → abrindo wallet → aguardando (polling) → verificando → success | underage | expired | error`.
- [ ] Observador de lifecycle para retomar polling no `resumed`.
- [ ] **Gate ao finalizar:** pedido com item 18+ ⇒ exige `success` antes de concluir a compra.

### Fase 3 — Harness de testes de credencial (SEU FOCO — ver seção 5)
- [ ] Mock server do Verify Service (para testar estados sem infra/wallet).
- [ ] Matriz de casos (maior/menor/inválida/expirada/sem wallet/timeout/cancelamento/retomada).
- [ ] Testes automatizados: unit (parser `isOver18`), widget (estados da tela), integration (fluxo com mock).

### Fase 4 — Segurança/LGPD & build de loja (ver seção 6)
- [ ] Minimização de dados; não persistir a VC crua.
- [ ] Endurecer deep link/origin/TLS.
- [ ] Build assinado iOS/Android.

---

## 4. Spec do módulo de verificação (contrato REST)

Context path: `/v1/verify`.

1. **Criar VP Request** — `POST {BASE}/v1/verify/vp-request`
   - body: `{ clientId, presentationDefinition }` (usar a *presentation definition* `eca-age-check` que filtra `type == ECACredential`).
   - resposta: `{ transactionId, requestId, authorizationDetails, expiresAt }`.
   - com `requestUri`/`client_id`/`origin`, montar `openid4vp://authorize?...` e abrir a wallet.
2. **Polling** — `GET {BASE}/v1/verify/vp-request/{requestId}/status` → `ACTIVE | VP_SUBMITTED | EXPIRED`.
3. **Resultado** — `GET {BASE}/v1/verify/vp-result/{transactionId}` → `vpResultStatus == SUCCESS`, `vcResults[0].vc.credentialSubject.isOver18`. `vcStatus`: `SUCCESS | INVALID | EXPIRED`.

**Parsing defensivo (Dart):** `vc` pode vir como *string* JSON ou *map*; `credentialSubject` pode estar em `vc.credential.credentialSubject` ou `vc.credentialSubject`. Tratar ambos.

---

## 5. Plano de testes de credencial (foco do projeto)

**Duas camadas — teste sem infra e teste real:**

**A) Sem infra (determinístico, roda em CI):** mock server (via `dio` interceptor ou um `shelf` local) que responde `/vp-request`, `/status`, `/vp-result` com payloads controlados. Permite exercitar TODOS os estados da UI sem wallet nem VM.

**B) Real (device físico + Inji Wallet + credencial emitida):** valida o fluxo ponta a ponta.

**Matriz de casos:**

| # | Caso | Setup | Resultado esperado |
|---|---|---|---|
| 1 | Maior de 18 | credencial válida, `isOver18=true` | `success` → libera compra |
| 2 | Menor de 18 | credencial `isOver18=false` | `underage` → bloqueia checkout |
| 3 | Credencial inválida | assinatura/emissor incorretos | `vcStatus INVALID` → erro tratado |
| 4 | Credencial expirada | VC vencida | `vcStatus EXPIRED` → erro tratado |
| 5 | Sem wallet | device sem Inji Wallet | erro "instale a carteira" |
| 6 | Sessão expira | não autoriza a tempo | status `EXPIRED` → oferecer retry |
| 7 | Cancelamento | volta ao app sem autorizar | lifecycle `resumed`, status `ACTIVE` → segue aguardando/timeout |
| 8 | Retomada foreground | autoriza e volta | `resumed` → polling retoma → resultado |

**Testes automatizados:**
- **Unit:** parser de `isOver18` (vc string, vc map, campo ausente, `INVALID`, `EXPIRED`).
- **Widget:** `AgeCheckScreen` renderiza cada estado corretamente.
- **Integration:** golden path + caso 2 + caso 6 contra o mock server.

> Dependência a confirmar com a equipe VerificaIdade: **como emitir `ECACredential` de teste** na Inji Wallet (sandbox/issuer). Isso destrava os casos 1–4 no ambiente real.

---

## 6. Segurança & LGPD

- **Minimização (LGPD art. 6, III):** o app recebe apenas o booleano `isOver18`. **Não** solicitar nem armazenar data de nascimento, CPF ou nome.
- **Persistência:** guardar no máximo `{ resultado: bool, transactionId, timestamp }` como trilha de auditoria da compra. **Nunca** persistir a VC crua nem logá-la.
- **Transporte:** `VERIFY_BASE_URL` só sobre TLS. Validar o `origin` do deep link de retorno. O `nonce` por sessão já é gerado pelo Verify Service — não reaproveitar.
- **Superfície de deep link:** registrar o scheme de forma restrita; ignorar retornos sem `transactionId`/`requestId` de sessão ativa.

---

## 7. Roteamento de IA por tarefa (dev assistido)

| Tarefa | Modelo | Motivo |
|---|---|---|
| Spec do módulo de verificação, plano de testes, decisões de arquitetura, revisão de segurança/LGPD | **Opus** | Trade-offs, visão sistêmica, precisa ser completo e testável |
| Implementação: `verify_service.dart`, `AgeCheckScreen`, catálogo, carrinho, checkout | **Sonnet** | Código seguindo padrão definido |
| Testes unit/widget/integration | **Sonnet** | Cobertura sem excesso |
| Debugging do lifecycle/polling (assíncrono, corrida) | **Opus** | Raciocínio sobre fluxo assíncrono |
| `AndroidManifest.xml`, `Info.plist`, `pubspec.yaml`, configs | **Haiku** | Mecânico, menor custo |

---

## 8. Decisões em aberto (confirmar — defaults sugeridos)

1. **`VERIFY_BASE_URL`** já existe / onboarding feito? *(bloqueia testes reais)*
2. **Emissão de credencial de teste** — qual sandbox/issuer para o `ECACredential`?
3. **Backend da loja 18+** — mock local (default sugerido p/ MVP) ou API real?
4. **Gerência de estado** — Riverpod (default) ou Bloc?
5. ~~Escopo iFood~~ — **DECIDIDO:** casca mínima de compra; verificação é o produto.

---

## 9. Stack proposta (resumo)

- **Framework:** Flutter (Dart) | **HTTP:** dio | **Estado:** Riverpod | **Rotas:** go_router
- **Deep link:** url_launcher (+ app_links se precisar capturar retorno) | **Lifecycle:** WidgetsBindingObserver
- **Testes:** flutter_test (unit/widget) + integration_test + mock server (shelf/dio interceptor)
- **Estrutura:** feature-first

---

## 10. Ambiente de desenvolvimento & modelo de execução

**Alvo:** iOS **e** Android com a **mesma** base de código Flutter. O que é específico por plataforma:
- Registro de scheme (Android `intent-filter` / iOS `CFBundleURLTypes`) + iOS `LSApplicationQueriesSchemes` p/ `openid4vp` — ver seção 2.
- **Device físico** de cada plataforma p/ testar o fluxo same-device com a Inji Wallet.
- Build/assinatura por loja (Android keystore; iOS signing/provisioning).

**Setup da máquina de dev:**
- Flutter SDK (`flutter doctor` sem erros) + Dart.
- Android: Android Studio / Android SDK + device ou emulador (emulador só p/ UI, não p/ wallet).
- iOS: **macOS + Xcode + CocoaPods** (obrigatório para buildar iOS) + device.

**Modelo de execução — IDE + Claude via API:**
- O **código é gerado na IDE** (agente Claude via API). Este documento + o `code-checkpoint.md` são o **contexto** que você injeta no agente.
- **Economia de contexto:** ao abrir sessão nova na IDE, forneça o checkpoint em vez de rolar histórico. O checkpoint carrega stack, arquitetura, decisões e próxima tarefa.
- **Roteamento de modelo** (ver seção 7): specs/arquitetura/revisão → tier Opus; implementação/testes → tier Sonnet; configs → tier Haiku. Use o pacote de specs/prompts (`specs-e-prompts-ide.md`) como entrada por módulo.
- IDs de modelo e preços atuais da API mudam com o tempo — confirme em docs.claude.com antes de fixar no seu setup.
