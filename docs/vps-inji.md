# INJI Verify Service — VPS dedicada (produção de teste)

> No ar: **https://verify.beachd.com.br** · deployado em 2026-09-10.

## Servidor

| | |
|---|---|
| Host | `2.25.149.198` (Hostinger), Ubuntu 26.04, 2 vCPU / 8 GB / 2 GB swap |
| Stack | `docker compose` em **`/root/inji/`** (`docker-compose.yml`, `Caddyfile`, `.env`) |
| Serviços | `caddy` (80/443, TLS Let's Encrypt automático) → `inji-verify-service:0.18.1` → `postgres:15-alpine` |
| `DB_PASSWORD` | em `/root/inji/.env` (gerado com `openssl rand -hex 24`) |
| Firewall | ufw: 22, 80, 443 |

O `did.json` é servido pela própria INJI em `/v1/verify/did.json`
(chave `did:web:verify.beachd.com.br:v1:verify#key-0`, Ed25519).

## Operação

```sh
ssh root@2.25.149.198
cd /root/inji

docker compose ps
docker compose logs -f inji-verify-service
docker compose restart caddy            # forca nova tentativa de cert
docker compose pull && docker compose up -d   # atualizar imagens
```

Validar:
```sh
curl -s https://verify.beachd.com.br/v1/verify/actuator/health   # {"status":"UP"}
curl -s https://verify.beachd.com.br/v1/verify/did.json
```

## DNS

`verify.beachd.com.br` → **A** `2.25.149.198` (era CNAME pro apex da VPS antiga).
Os outros `*.beachd.com.br` seguem na VPS antiga (`147.79.82.31`).

## Config do app

`config/local.json` e grupo `verify_service` no Codemagic:

| Chave | Valor |
|---|---|
| `VERIFY_BASE_URL` | `https://verify.beachd.com.br` |
| `VERIFY_CLIENT_ID` | `did:web:verify.beachd.com.br:v1:verify` |
| `VERIFY_ALLOW_INSECURE` | `false` |
| `VERIFY_SEND_ORIGIN` | `true` (padrão do app) |

## Observações do serviço real (INJI 0.18.1) — testado ao vivo

- **`POST /vp-request`** devolve **menos** que a doc: só
  `{ transactionId, requestId, expiresAt (epoch ms), requestUri (topo) }`.
  **Sem `authorizationDetails`.** O app já lê `requestUri` do topo e o
  `client_id` do deep link cai no `VerifyConfig.clientId`.
- **`GET /status` é long-polling (~55 s por chamada)** — só responde na hora
  quando o estado muda. Params `?timeout=` / `?timeoutMs=` são ignorados.
  → `VerifyService.pollStatus` usa `receiveTimeout` de 70 s e, se estourar,
  devolve `ACTIVE` (não é erro); `AgeCheckTiming` = `pollInterval 1s`,
  `maxPolls 8` (≈ 7 min de espera máxima pela autorização).
- **`GET /vp-result` antes da submissão** → HTTP 400
  `{"errorCode":"NO_VP_SUBMISSION","errorMessage":"..."}`. No fluxo normal
  só é chamado após `VP_SUBMITTED`, então não ocorre.
- Sem cabeçalhos de autenticação (confirmado).

## Pendências

- **Box antigo** `147.79.82.31`: remover a stack órfã `injiverify` (`docker stack rm injiverify`) quando o servidor voltar a responder (estava sobrecarregado: load ~40, 37 serviços).
- **Onboarding VerificaIdade**: Inji Wallet + `ECACredential` de teste emitida (issuer/staging). Confirmar se `did:web:verify.beachd.com.br:v1:verify` precisa ser registrado no gateway deles.
- Hardening: trocar senha root por chave SSH, restringir a porta do Portainer (se instalar).

## docker-compose.yml (referência)

```yaml
services:
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks: [web]
  inji-verify-service:
    image: injistack/inji-verify-service:0.18.1
    restart: unless-stopped
    environment:
      DATABASE_HOST: postgres
      DATABASE_PORT: "5432"
      DATABASE_NAME: inji_verify
      DATABASE_SCHEMA: public
      DATABASE_USERNAME: inji
      DATABASE_PASSWORD: ${DB_PASSWORD}
      INJI_VP_SUBMISSION_BASE_URL: https://verify.beachd.com.br/v1/verify
      INJI_DID_VERIFY_URI: did:web:verify.beachd.com.br:v1:verify
      INJI_DID_VERIFY_PUBLIC_KEY_URI: did:web:verify.beachd.com.br:v1:verify#key-0
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
      MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "*"
      MANAGEMENT_ENDPOINT_MAPPINGS_ENABLED: "true"
    depends_on:
      postgres: { condition: service_healthy }
    networks: [web, internal]
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: inji
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: inji_verify
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U inji -d inji_verify"]
      interval: 5s
      timeout: 5s
      retries: 12
    networks: [internal]
networks: { web: {}, internal: {} }
volumes: { pgdata: {}, caddy_data: {}, caddy_config: {} }
```

Caddyfile:
```
{
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}
verify.beachd.com.br {
    reverse_proxy inji-verify-service:8080
}
```
