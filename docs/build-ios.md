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
   --no-codesign` → artefato **`Runner-app.zip`** (`build/ios/iphoneos/Runner.app`).
3. Valida que compila em Xcode real + pods resolvem. **Não instala em device**
   (sem assinatura). ~15–20 min (minutos macOS do Codemagic contam mais).

Para um build **instalável em iPhone** (`.ipa` assinado): precisa de conta
**Apple Developer Program** (US$ 99/ano) + configurar *code signing* no Codemagic
(certificado + provisioning profile). Isso é Fase 4.

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

## Config iOS já feita (M0)

`ios/Runner/Info.plist`:
- `CFBundleURLTypes` → `CFBundleURLSchemes = ["app18"]` (retorno da carteira)
- `LSApplicationQueriesSchemes = ["openid4vp"]` (sem isto `launchUrl` falha
  silenciosamente no iOS)
