# Primeiro teste real — passo a passo

> Objetivo: rodar o app **contra um INJI Verify Service de verdade** e uma **Inji Wallet**
> num device Android, sem instalar Android SDK nesta máquina (o APK sai do Codemagic).
>
> Fontes: https://verificaidade.dev — `quickstart.html`, `setup-vm.html`,
> `inji-verify.html`, `integra-mobile.html`, `onboarding.html`, `api-reference.html`.

## Visão geral

```
  [PC/VM com Docker]                         [Device Android]
  INJI Verify Service  ── ngrok (https) ──▶  App (APK debug do Codemagic)
  + Postgres                                 + Inji Wallet + ECACredential teste
       │  GET /v1/verify/actuator/health = UP
       │  did:web resolvido em https://<host>/v1/verify/did.json
```

O app já implementa os 3 endpoints (`vp-request`, `status`, `vp-result`) + `checkHealth`,
o deep link `openid4vp://authorize?client_id=&request_uri=&origin=app18://` e o polling
com retomada no `AppLifecycleState.resumed`. Falta **infra + credencial + gerar o APK**.

---

## Parte A — Onboarding (VerificaIdade)

O onboarding **não é self-service** (`onboarding.html`). Antes de tudo:

1. **Contatar o órgão responsável pelo VerificaIdade** e pedir:
   - acesso ao **portal/gateway WSO2** (credenciais de verificador);
   - o **DID Web** do seu verificador (ou instruções para gerar) + **keystore de teste**;
   - **credenciais de teste** (`ECACredential`) e/ou acesso ao ambiente de **staging** para emiti-las numa Inji Wallet;
   - o **APK/link da Inji Wallet** (Android) usado no piloto.
2. Guardar: `client_id`/DID, keystore, URL de staging.

> Para um smoke test **sem** onboarding completo dá para rodar o Verify Service local
> (o `quickstart` usa `did:web:localhost:v1:verify`) e exercitar `health` + `vp-request` +
> `status`. O `vp-result` com credencial de verdade **só fecha** com a `ECACredential`
> emitida numa wallet (Parte E).

---

## Parte B — Máquina com Docker (`setup-vm.html`)

Pode ser sua VM, um servidor ou o próprio Mac.

```sh
docker --version
docker compose version        # precisa existir (Docker Compose v2)
mkdir -p ~/verificaidade && cd ~/verificaidade
```

---

## Parte C — Subir o INJI Verify Service (`inji-verify.html`)

Crie `~/verificaidade/docker-compose.yml`. **Modelo** (confirme imagem/vars com a
página `inji-verify.html` ou com o material que a equipe te passar):

```yaml
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: inji
      POSTGRES_PASSWORD: inji123
      POSTGRES_DB: inji_verify
    ports: ["5432:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U inji -d inji_verify"]
      interval: 5s
      retries: 10

  inji-verify-service:
    image: injistack/inji-verify-service:0.18.1   # use EXATAMENTE 0.18.1
    depends_on:
      postgres: { condition: service_healthy }
    ports: ["8080:8080"]
    environment:
      # DB
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: inji
      DB_PASSWORD: inji123
      DB_NAME: inji_verify
      # Identidade do verificador — ajuste na Parte D (depois do ngrok)
      INJI_VP_SUBMISSION_BASE_URL: http://localhost:8080/v1/verify
      INJI_DID_VERIFY_URI: did:web:localhost:v1:verify
      INJI_DID_VERIFY_PUBLIC_KEY_URI: did:web:localhost:v1:verify#key-0
```

Subir e validar:

```sh
docker compose up -d
docker ps
docker logs inji-verify-service --tail 50
curl -s http://localhost:8080/v1/verify/actuator/health        # -> {"status":"UP"}
```

---

## Parte D — Expor com ngrok e reconfigurar

A carteira precisa **alcançar o Service pela internet** e **resolver o `did:web`**.

```sh
ngrok http 8080
# copie a URL: https://abc123.ngrok-free.app
```

Edite as 3 vars no `docker-compose.yml` trocando `localhost` pelo host do ngrok
(**sem `https://`** no DID; **com** na base URL):

```yaml
      INJI_VP_SUBMISSION_BASE_URL: https://abc123.ngrok-free.app/v1/verify
      INJI_DID_VERIFY_URI: did:web:abc123.ngrok-free.app:v1:verify
      INJI_DID_VERIFY_PUBLIC_KEY_URI: did:web:abc123.ngrok-free.app:v1:verify#key-0
```

Reinicie e confira o DID document e o health pela URL pública:

```sh
docker compose down && docker compose up -d
curl -s https://abc123.ngrok-free.app/v1/verify/actuator/health     # {"status":"UP"}
curl -s https://abc123.ngrok-free.app/v1/verify/did.json            # documento did:web
```

> **A URL do ngrok muda a cada `ngrok http`.** Toda vez que mudar: reeditar as vars,
> `docker compose down && up -d`, **e** atualizar as env vars no Codemagic + rebuildar
> (Parte F). Para evitar: `ngrok http 8080 --domain=<seu-dominio-estatico>` (domínio
> reservado no painel do ngrok) ou hospedar o Service com URL fixa.

---

## Parte E — Inji Wallet + credencial de teste

1. Instalar a **Inji Wallet** no device Android (APK/link da equipe VerificaIdade).
2. Emitir uma **`ECACredential` de teste** na wallet (fluxo de staging / issuer de teste —
   Parte A). A credencial precisa ter `type` contendo `ECACredential` (é o que a
   *presentation definition* `eca-age-check` filtra).
3. Ter **uma** credencial 18+ = `true` e, se possível, **outra** 18+ = `false` para testar
   o bloqueio.

---

## Parte F — Gerar o APK no Codemagic

O repositório já está em **github.com/rrsmiranda/foodyvc** (`main`) com `codemagic.yaml`.

### F1. Conectar
1. codemagic.io → **Add application** → GitHub → repositório `rrsmiranda/foodyvc`.
2. O Codemagic detecta o `codemagic.yaml` → workflow **`android-debug-test`**.

### F2. Variáveis de ambiente
Menu **Environment variables** → criar o grupo **`verify_service`**:

| Variável | Valor (exemplo) | Secure |
|---|---|---|
| `VERIFY_BASE_URL` | `https://abc123.ngrok-free.app` | ✔ |
| `VERIFY_CLIENT_ID` | `did:web:abc123.ngrok-free.app:v1:verify` | ✔ |
| `VERIFY_ALLOW_INSECURE` | `false` (só `true` p/ HTTP em LAN) | |
| `VERIFY_SEND_ORIGIN` | *(não precisa — o app já manda `origin` por padrão)* | |

> `VERIFY_BASE_URL` = **host puro**, sem `/v1/verify` (o app já acrescenta).
> `VERIFY_CLIENT_ID` deve casar com o `INJI_DID_VERIFY_URI` do servidor.

### F3. Build
1. **Start new build** → `android-debug-test`.
2. Passos: `pub get` → `flutter analyze` → `flutter test` (116) → `flutter build apk --debug`.
3. Baixar o artefato **`app-debug.apk`** (`build/app/outputs/flutter-apk/app-debug.apk`)
   na página do build. ~8–12 min (cabe no plano free).

> É **debug** de propósito: ativa o `network_security_config` que libera HTTP em LAN e o
> ícone de **Diagnóstico** (`/diag`, só em `kDebugMode`). O keystore de debug é gerado
> pelo Codemagic — não precisa configurar assinatura.

---

## Parte G — Instalar no device

- Via cabo: `adb install -r app-debug.apk`
- Ou: abrir o link do artefato **no navegador do aparelho** e instalar (liberar
  "Instalar apps desconhecidos" para o navegador/gerenciador de arquivos).

---

## Parte H — Testar

### H1. Smoke test (tela de Diagnóstico)
Abrir o app → **Loja** → ícone `⇄` na AppBar (`/diag`). Conferir a config e:

1. **GET /actuator/health** → `UP`. Falhou aqui = problema de rede/URL/ngrok, não o app.
2. **POST /vp-request** → mostra `requestId`/`transactionId` **e abre a Inji Wallet**.
3. Autorizar na wallet → **voltar ao app** → **GET status** → deve ir de `ACTIVE` para
   `VP_SUBMITTED` (pode levar alguns segundos; toque de novo).
4. **GET vp-result** → `verified=true/false`.

### H2. Fluxo completo
Loja → adicionar um item **18+** (Cerveja/Vinho) → **Finalizar compra** →
tela de verificação → **Verificar idade** → autoriza na Inji Wallet → **volta ao app**:
a tela sai sozinha de "aguardando" (polling no `resumed`) → **Idade confirmada** /
**Compra não autorizada** → volta à Loja com o gate aplicado (carrinho concluído ou
itens 18+ removidos).

---

## Parte I — Troubleshooting

| Sintoma no app | Causa provável | O que checar |
|---|---|---|
| `health` != UP no `/diag` | Service fora / URL errada / ngrok caiu | `curl .../actuator/health` no PC; ngrok ativo; `VERIFY_BASE_URL` sem `/v1/verify` |
| `WalletUnavailableException` ("instale a carteira") | Inji Wallet não instalada / scheme `openid4vp` não resolve | instalar a wallet; o `AndroidManifest`/`Info.plist` já declaram `openid4vp` |
| `VerifyNetworkException` (HTTP) | 4xx/5xx do Service, CORS, DNS | `docker logs inji-verify-service`; `VERIFY_CLIENT_ID` == `INJI_DID_VERIFY_URI` |
| `VerificationExpiredException` / "Sessão expirada" sempre | wallet não submeteu a apresentação | `INJI_VP_SUBMISSION_BASE_URL` público e correto; `did.json` acessível; credencial casa com `type == ECACredential` |
| `CredentialInvalidException` | assinatura/emissor não conferem | keystore/issuer de teste; credencial emitida no ambiente certo |
| `CredentialExpiredException` | `ECACredential` vencida | reemitir credencial de teste |
| App não volta da wallet | retorno depende do foreground | trazer o app ao foreground (recentes/voltar) — o polling retoma no `resumed`. `origin` já vai no deep link por padrão. |
| Build do Codemagic falha em `flutter test` | versão do Flutter diferente | fixar `flutter: 3.24.5` (ou `3.24.x`) no `codemagic.yaml` |

---

## Anexo — env vars: servidor × app

| Onde | Variável | Exemplo | Observação |
|---|---|---|---|
| Docker (Service) | `INJI_VP_SUBMISSION_BASE_URL` | `https://abc123.ngrok-free.app/v1/verify` | **com** `/v1/verify` |
| Docker (Service) | `INJI_DID_VERIFY_URI` | `did:web:abc123.ngrok-free.app:v1:verify` | sem `https://` |
| Docker (Service) | `INJI_DID_VERIFY_PUBLIC_KEY_URI` | `did:web:abc123.ngrok-free.app:v1:verify#key-0` | sufixo `#key-0` |
| Codemagic (app) | `VERIFY_BASE_URL` | `https://abc123.ngrok-free.app` | **host puro**, sem path |
| Codemagic (app) | `VERIFY_CLIENT_ID` | `did:web:abc123.ngrok-free.app:v1:verify` | == `INJI_DID_VERIFY_URI` |
| Codemagic (app) | `VERIFY_ALLOW_INSECURE` | `false` | `true` só p/ `http://` em LAN |
| Codemagic (app) | `VERIFY_SEND_ORIGIN` | *(omitir)* | app já manda `origin=app18://` |
