# Sessão 2026-09-11 — Debug do erro de verificação + tela preta da demo web

> Registro da sessão com Claude Code. Dois bugs encontrados e corrigidos, com
> diagnóstico completo (causa raiz) e verificação (testes + build local +
> teste visual no site publicado).

## 1. Erro "Falha ao criar a solicitação de verificação" ao simular

**Sintoma:** ao tocar em "Verificar idade" num device/simulador, a tela caía
em erro imediatamente com "Falha ao criar a solicitação de verificação" (sem
código HTTP).

**Causa raiz:** essa mensagem só aparece quando `VerifyService._send` captura
uma `DioException` de **conexão** (não uma resposta HTTP com erro — essa
mostraria "(HTTP xxx)"). O app estava rodando com `VERIFY_BASE_URL` no
default `https://verify.invalid` — um host sentinela (RFC 2606) que **nunca
resolve por design**. Isso acontece sempre que o app roda **sem**
`--dart-define-from-file=config/local.json` — por exemplo, abrindo
`ios/Runner.xcworkspace` no Xcode e apertando ▶️ direto, em vez de usar
`make run` ou os launch configs do VS Code.

Confirmado que o backend (`config/local.json` aponta hoje pro **Dataprev
HML**, `injiverify.credenciaisverificaveis-hml.dataprev.gov.br`) está no ar:
`curl` de `/v1/verify/actuator/health` respondeu 200 e `/v1/verify/vp-request`
respondeu 400 (payload de teste inválido, mas conectou normalmente).

**Correção** (commit `0755d78`):
- `AppConfig.verifyBaseUrlSentinel` — a string mágica `https://verify.invalid`
  virou constante nomeada e documentada.
- `VerifyService` (factory) agora detecta esse sentinel **antes** de tentar
  rede (só quando `dio` não foi injetado, ou seja, é o cliente real) e lança
  `VerifyConfigException` com mensagem explicando a causa e o comando certo.
- 2 testes novos em `verify_service_test.dart` (grupo "sentinel guard").
- `docs/build-ios.md` ganhou um aviso: nunca rodar via Xcode direto sem os
  `--dart-define`; e que o **simulador iOS não tem a Inji Wallet instalada**
  — mesmo com a config certa, o fluxo para em `WalletUnavailableException`
  ao tentar abrir a carteira. Simulador só valida até a criação da
  `vp-request`; o fluxo completo exige device físico.

`flutter analyze`: 0 issues · `flutter test`: 119/119.

## 2. Tela preta na demo web (`rrsmiranda.github.io/foodyvc`)

**Sintoma:** a moldura de celular aparecia (CSS ok, corrigido antes no
commit `b27c1c5`), mas a tela dentro dela ficava **completamente preta** —
o app Flutter nunca chegava a renderizar nada.

**Diagnóstico:** abri o site com o Chrome (via automação) e li o console —
`SyntaxError: Unexpected identifier 'current'` em `flutter_bootstrap.js:1`.

Investigando o arquivo publicado, ele estava com conteúdo duplicado e
corrompido. Causa: `web/flutter_bootstrap.js` (customizado desde o commit
`d73ca1e` pra montar a app dentro da `#phone`) tinha um comentário
explicativo que **citava os nomes dos placeholders por extenso**:

```js
// Template do bootstrap do Flutter web. Os tokens {{flutter_js}} e
// {{flutter_build_config}} sao substituidos por `flutter build web`.
```

O `flutter build web` faz a substituição desses tokens com um **replace de
string ingênuo** (não é JS-aware, não sabe o que é comentário) — e trocava
**todas** as ocorrências literais de `{{flutter_js}}`, inclusive a que
estava dentro do comentário. Isso injetava o JS minificado inteiro do engine
Flutter no meio da linha `// Template do bootstrap...`. Como esse JS injetado
contém *template literals* com quebras de linha reais dentro de backticks, a
linha `//` (que só comenta até o próximo `\n`) terminava cedo demais — bem no
meio de uma string tipo `` `\nThe current context is NOT secure.` `` — e o
restante ("The current context...") sobrava como código JS solto, gerando o
`SyntaxError: Unexpected identifier 'current'`. Com o script quebrado,
`_flutter.loader.load(...)` (no fim do arquivo) nunca era executado, então o
Flutter nunca inicializava.

**Esse bug existia desde o commit `d73ca1e`** — ou seja, a demo nunca
funcionou de fato desde que a moldura de celular foi introduzida.

**Correção** (commit `bff7c4b`): reescrevi o comentário do
`web/flutter_bootstrap.js` sem repetir a sintaxe exata dos placeholders, e
deixei um aviso explícito no próprio arquivo pra não reincidir.

**Verificação:**
1. `flutter build web -t lib/main_demo.dart` local — build ok.
2. `node --check build/web/flutter_bootstrap.js` — sintaxe válida.
3. Servido localmente (`python3 -m http.server`) e testado visualmente: loja
   carrega, catálogo aparece, badges "18+" ok.
4. Push pro `main` → GitHub Actions (`Deploy demo web`) rodou `build` +
   `deploy` com sucesso.
5. Reabri `https://rrsmiranda.github.io/foodyvc/` — carregou a loja
   normalmente (obs.: a primeira tentativa ainda mostrou a versão quebrada
   por **cache do navegador**; um hard reload — Cmd+Shift+R — resolveu).
6. Rodei o fluxo completo de verificação **na demo publicada**: adicionei a
   cerveja 18+ ao carrinho → "Finalizar compra" → tela "Verificação de
   idade" → "Verificar idade" → resultado "Idade confirmada" → "Concluir
   compra". Fluxo simulado (mock M4) funcionando ponta a ponta.

## O que a demo web publicada permite e o que não permite

- **Permite:** testar toda a máquina de estados e a UI da verificação
  (sucesso, menor de idade, credencial inválida, expirada, timeout) via
  mock — botão "Demo: maior de 18" no canto inferior direito troca o
  cenário. Não precisa de device, wallet ou credencial real.
- **Não permite:** a integração real via deep link `openid4vp://` com a
  Inji Wallet e o Verify Service de verdade — isso só é testável num device
  físico Android/iOS com a wallet instalada (bloqueio de Fase 0, já
  registrado em `docs/code-checkpoint.md`).

## Commits desta sessão

| Commit | Descrição |
|---|---|
| `0755d78` | Guard de config sentinela (`VERIFY_BASE_URL` não configurado) |
| `bff7c4b` | Fix da tela preta na demo web (tokens literais no comentário do bootstrap) |

Ambos com push feito pro `main` e CI verde.
