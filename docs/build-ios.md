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
2. Roda `pod install` → `analyze` → `test` → `flutter build ios --debug
   --no-codesign` → empacota **`app-unsigned.ipa`**
   (`build/ios/iphoneos/app-unsigned.ipa`, estrutura `Payload/Runner.app`).
3. Valida que compila em Xcode real + pods resolvem. ~15–20 min (minutos
   macOS do Codemagic contam mais).

### Instalar esse `.ipa` no iPhone via AltStore (sem Apple Developer Program)

O `.ipa` gerado não é assinado — não dá pra distribuir via TestFlight/App
Store (isso exige conta **Apple Developer Program**, US$ 99/ano — Fase 4).
Mas dá pra **sideload de graça** com [AltStore](https://faq.altstore.io/)
(Classic), que assina o app na hora da instalação usando seu Apple ID
pessoal:

1. **No Mac**: baixe e instale `AltServer.app` em `/Applications`, abra
   (fica na barra de menu).
2. **No iPhone**: conecte por cabo e ative "Wi-Fi sync" pelo Finder (ou
   deixe na mesma rede Wi-Fi do Mac); em iOS 16+ ative Developer Mode
   (Ajustes → Privacidade e Segurança).
3. No menu do AltServer → **Install AltStore** → seu dispositivo → informe
   seu Apple ID (vai só pra Apple). No iPhone: Ajustes → Geral → VPN e
   Gestão de Dispositivos → confie no seu Apple ID.
4. Baixe `app-unsigned.ipa` do build do Codemagic e leve pro iPhone (AirDrop
   do Mac, iCloud Drive, etc. — precisa estar acessível pelo app Arquivos).
5. No AltStore → aba **My Apps** → **+** → escolha o `app-unsigned.ipa` no
   Arquivos. O AltServer (precisa estar rodando, mesma rede) assina e
   instala.

**Limitações do plano grátis**: o app expira em **7 dias** (reabra o
AltStore com o Mac por perto pra renovar, ou reinstale); **máx. 3 apps**
sideloaded por vez com Apple ID grátis.

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
make ios                      # flutter build ios --debug --no-codesign
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
