# app_idade18 — App 18+ VerificaIdade (Flutter)

Casca de simulação de compra cujo checkout de itens **18+** é liberado por
verificação de idade via credencial verificável (VerificaIdade / INJI, OID4VP).
Integração **REST puro + deep link `openid4vp://`**, retorno por lifecycle
(`AppLifecycleState.resumed`) + polling. Sem SDK.

Docs: `docs/code-checkpoint.md` (estado atual), `docs/plano-verificaidade-flutter.md`,
`docs/teste-real-passo-a-passo.md` (rodar contra um Verify Service de verdade).

## Rodar local (Mac)

Flutter 3.24.5 em `~/development/flutter` (já no PATH via `.zshrc`). Android SDK
em `~/Android`. iOS/macOS precisam de Xcode completo + CocoaPods (não instalados).

```sh
make setup      # flutter pub get
make demo       # DEMO no Chrome — app inteiro com o mock do M4, sem backend
make demo-device# DEMO num device/emulador Android
make test       # 116 testes
make analyze
make apk        # build/app/outputs/flutter-apk/app-debug.apk (usa config/local.json)
make run        # app REAL num device (usa config/local.json)
make help       # todos os alvos
```

Sem `make`, os comandos equivalentes:
`flutter run -d chrome -t lib/main_demo.dart` · `flutter test` ·
`flutter build apk --debug --dart-define-from-file=config/local.json`.

### Dois entrypoints
| Arquivo | Uso |
|---|---|
| `lib/main_demo.dart` | **demo** — plugue o mock do M4; FAB "Demo" troca o cenário (maior/menor de 18, inválida, expirada, timeout). Não precisa de servidor. |
| `lib/main.dart` | **real** — fala com o INJI Verify Service. Config via `--dart-define` / `--dart-define-from-file`. |

### Config do app real
`cp config/local.example.json config/local.json` e edite (`make run`/`make apk`
fazem isso na 1ª vez). `config/local.json` não vai pro git.

| Chave | Ex. | Nota |
|---|---|---|
| `VERIFY_BASE_URL` | `https://verify.seudominio.com` | host puro, **sem** `/v1/verify` |
| `VERIFY_CLIENT_ID` | `did:web:verify.seudominio.com:v1:verify` | == `INJI_DID_VERIFY_URI` do servidor |
| `VERIFY_ALLOW_INSECURE` | `false` | `true` só p/ HTTP em LAN (build debug) |
| `VERIFY_SEND_ORIGIN` | `true` | padrão do app; `false` só p/ experimentar |

### VS Code
`.vscode/launch.json` traz configs prontas: **Demo — Chrome**, **Demo — device**,
**App real — Chrome/device (config/local.json)**.

### Tela de diagnóstico
No app (build debug), ícone `⇄` na AppBar da Loja → `/diag`: mostra a config
efetiva e dispara `health` / `vp-request` / `status` / `vp-result` isolados.

## CI

`codemagic.yaml` — workflow `android-debug-test` gera o APK debug com as
`--dart-define` do grupo de env vars `verify_service`.
