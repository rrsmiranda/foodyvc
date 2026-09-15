# Build iOS

O **código/config iOS já está pronto** (deep link `app18` + `openid4vp` no
`ios/Runner/Info.plist`, bundle id `br.com.verificaidade.appIdade18`, deployment
target 12.0). Falta só o **ambiente de build**.

## Por que não dá pra buildar nesta máquina

- **Xcode completo** não instalado (só Command Line Tools). Precisa de Mac App
  Store (Apple ID) ou download autenticado (~15 GB) da Apple.
- **Disco**: ~5 GB livres de 228 (98% cheio). Xcode ocupa ~40 GB instalado.
- **CocoaPods** não instalado (e sem Xcode não adianta).

## Opção A — Codemagic (recomendado, sem Xcode local)

Workflow **`ios-unsigned`** no `codemagic.yaml` (runner macOS com Xcode +
CocoaPods prontos):

1. Codemagic → app `rrsmiranda/foodyvc` → **Start new build** → workflow
   `ios-unsigned`.
2. Roda `pod install` → `analyze` → `test` → `flutter build ios --release
   --no-codesign` → empacota **`app-unsigned.ipa`**
   (`build/ios/iphoneos/app-unsigned.ipa`, estrutura `Payload/Runner.app`).
3. Valida que compila em Xcode real + pods resolvem. ~15–20 min (minutos
   macOS do Codemagic contam mais).

> **Por que `--release` e não `--debug`:** um build `--debug` do Flutter pra
> iOS depende de JIT (o Dart VM interpreta bytecode em vez de rodar código
> nativo) — isso só funciona com um debugger anexado (Xcode) ou com JIT
> habilitado manualmente no dispositivo. Sideload (AltStore/SideStore) não
> tem nenhum dos dois por padrão: o app abre uma tela branca e fecha sozinho
> quase na hora. `--release` compila o Dart pra ARM nativo (AOT) e roda
> standalone sem depender de debugger/JIT — é o modo certo pra testar via
> sideload. Efeito colateral: a tela `/diag` (só em `kDebugMode`) não fica
> disponível nesse build.

### Instalar esse `.ipa` no iPhone via SideStore (sem Apple Developer Program)

O `.ipa` gerado não é assinado — não dá pra distribuir via TestFlight/App
Store (isso exige conta **Apple Developer Program**, US$ 99/ano — Fase 4).
Dá pra **sideload de graça** com [SideStore](https://sidestore.io/) — o
sucessor ativamente mantido do AltStore, necessário porque o **AltStore
Classic/AltServer não conecta de forma confiável em iOS 17/18** (a Apple
mudou o protocolo de pareamento do device; erro típico: "AltServer could
not establish a connection to AltStore"). O SideStore lida com esse
protocolo novo nativamente, via um app de VPN local no próprio iPhone (sem
precisar do Mac por perto depois do setup inicial).

1. **No iPhone**: instale o app **LocalDevVPN** pela App Store. Em iOS 18+,
   ative Developer Mode (Ajustes → Privacidade e Segurança → Developer
   Mode → reinicia o aparelho).
2. **No Mac**: baixe e instale o **iloader** ([iloader.app](https://iloader.app/),
   DMG universal) — é quem instala/assina o SideStore no lugar do antigo
   AltServer.
3. Conecte o iPhone por **cabo USB**, toque em "Confiar" quando pedir.
4. Abra o iloader → faça login com um Apple ID → selecione o iPhone na
   lista → **"Install SideStore (Stable)"**.
5. No iPhone: Ajustes → Geral → VPN e Gestão de Dispositivo → confie na
   conta Apple usada no iloader.
6. Abra o **LocalDevVPN** → **Connect** (precisa ficar ativo toda vez que for
   instalar/atualizar/renovar apps pelo SideStore).
7. Abra o **SideStore**, faça login com a mesma conta do iloader → em **My
   Apps**, toque no contador **"7 DAYS"** do próprio SideStore pra fazer a
   primeira renovação (aceite os prompts de certificado).
8. Baixe `app-unsigned.ipa` do build do Codemagic, leve pro iPhone (AirDrop/
   iCloud Drive — precisa estar acessível pelo app Arquivos).
9. No SideStore → **My Apps** → **+** → escolha o `app-unsigned.ipa`. Com a
   LocalDevVPN conectada, instala/assina direto no aparelho.

**Limitações do plano grátis**: o app expira em **7 dias** (abrir o
SideStore com a LocalDevVPN conectada e tocar em "Refresh" renova, sem
precisar do Mac/iloader de novo — só quando expirar de vez).

## Opção B — Xcode local (quando tiver disco + Apple ID)

```sh
# 1. liberar ~50 GB de disco
# 2. instalar Xcode (App Store) e:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
# 3. CocoaPods:
brew install cocoapods        # ou: sudo gem install cocoapods
# 4. build:
make ios                      # flutter build ios --release --no-codesign
# ou rodar no simulador:
flutter run -d "iPhone 15" -t lib/main.dart --dart-define-from-file=config/local.json
```

`flutter doctor` deve mostrar `[✓] Xcode`.

> **Atenção ao rodar no simulador:** sempre pelo `flutter run`/`make run` com
> `--dart-define-from-file=config/local.json`, **nunca** abrindo
> `ios/Runner.xcworkspace` no Xcode e apertando ▶️ direto — isso builda sem
> nenhum `--dart-define`, então `VERIFY_BASE_URL` cai no default
> `https://verify.invalid` (sentinela que nunca resolve) e a tela de
> verificação quebra na hora com "Falha ao criar a solicitação de
> verificação" (erro de rede, não de credencial). Esse caso agora falha
> rápido com uma mensagem clara (`VerifyConfigException`) em vez do erro de
> rede genérico.
>
> Além disso, o **simulador não tem a Inji Wallet instalada** — mesmo com a
> config certa, o fluxo para em "abrir a carteira" (`WalletUnavailableException`).
> Simulador só valida até a criação da `vp-request`; o fluxo completo exige
> device físico com a wallet.

## Config iOS já feita (M0)

`ios/Runner/Info.plist`:
- `CFBundleURLTypes` → `CFBundleURLSchemes = ["app18"]` (retorno da carteira)
- `LSApplicationQueriesSchemes = ["openid4vp"]` (sem isto `launchUrl` falha
  silenciosamente no iOS)
