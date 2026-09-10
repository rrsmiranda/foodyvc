# Code Checkpoint — App 18+ VerificaIdade (Flutter)
> Última atualização: 2026-09-09 · v0 (pré-código)
> Fase: setup / planejamento
> Modelo ativo: Opus (arquitetura)
> Plano: plano-verificaidade-flutter.md · Specs IDE: specs-e-prompts-ide.md · Backend: backend-integracao.md

## Stack
- Lang: Dart | Framework: Flutter | DB: — (catálogo mock no MVP)
- HTTP: dio | Estado: Riverpod (a confirmar) | Rotas: go_router
- Deep link: url_launcher (+ app_links) | Lifecycle: WidgetsBindingObserver
- Testes: flutter_test + integration_test + mock server (shelf/dio interceptor)
- Estrutura: feature-first (lib/features/{shop,age_check} + lib/core)

## Arquitetura Atual
PRODUTO = verificação de idade. iFood = só CASCA de simulação de compra.
Casca: lista de produtos mock (>=1 item is18Plus) + botão FINALIZAR.
Ao finalizar com item 18+ → dispara Módulo de Verificação; senão compra concluída.
Verificação = relying party OID4VP, REST puro + deep link openid4vp://.
Fluxo: POST /vp-request → abre Inji Wallet → poll /status → GET /vp-result → isOver18.
Retomada do polling via AppLifecycleState.resumed.
(Clone iFood fiel das 7 telas = opcional/depois — ver plano seção 2.1.)

## Plano de Tarefas
- [ ] Fase 0 — Pré-requisitos externos (VERIFY_BASE_URL, onboarding, wallet, credencial teste) ← BLOQUEANTE
- [ ] Fase 1 — Casca de simulação de compra (lista mock + item 18+ + botão Finalizar → dispara verificação)
- [ ] Fase 2 — Módulo verificação (verify_service.dart, AgeCheckScreen, lifecycle, gate no checkout) ← CORE
- [ ] Fase 3 — Harness de testes de credencial (mock server + matriz 8 casos + automatizados)
- [ ] Fase 4 — Segurança/LGPD + build stores

## Decisões Tomadas
- Alvo: iOS + Android, base única Flutter (device físico p/ testar deep link same-device)
- Execução: código gerado na IDE via Claude API/CLI (Claude Code); este chat = planejamento/spec. Ver specs-e-prompts-ide.md
- Backend próprio em desenvolvimento; padrão recomendado = BFF: backend faz broker do Verify Service (segredos+auditoria no servidor), app fala só com o backend. Deep link segue no device. Ver backend-integracao.md (stack/escopo a confirmar)
- Design system: construído direto em Dart via CLI (M-DS) — ThemeData claro/escuro + componentes-núcleo. Claude Design é opcional.
- iOS: Info.plist precisa de LSApplicationQueriesSchemes com "openid4vp" (senão launchUrl falha)
- Foco = verificação de idade; iFood é só casca de simulação (NÃO reproduzir as 7 telas no MVP)
- Gatilho da verificação = botão "Finalizar compra" quando pedido tem item 18+
- Sem SDK: integração via REST + deep link (confirmado na doc/API reference)
- App não emite credencial; só verifica (recebe apenas isOver18)
- LGPD: não persistir VC crua nem PII; guardar só {bool, transactionId, timestamp}
- Presentation definition: eca-age-check filtrando type == ECACredential

## Bugs Conhecidos / TODOs
- [ ] Confirmar VERIFY_BASE_URL / onboarding
- [ ] Confirmar sandbox/issuer para emitir ECACredential de teste
- [ ] Decidir: backend mock vs real; Riverpod vs Bloc; escopo do catálogo

## Última Entrega
Plano + checkpoint + pacote de specs/prompts para IDE (M0–M5)

## Próxima Tarefa
Na IDE: M0 (scaffold+deep link) → M-DS (tema+componentes) → M4 (mock) → M2 (verify_service) → M3 (AgeCheckPage) → M1 (casca) → M5 (testes)

## Fuel Gauge
- Msgs trabalho: 1 · Entregas código: 0 · Zona: 🟢 Verde
- Próximo checkpoint em: 5 entregas · Capacidade restante estimada: ~95%
