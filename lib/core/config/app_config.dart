/// Configuracao central do app.
///
/// Todos os valores sensiveis ao ambiente entram por `--dart-define`, para que
/// a troca entre mock (M4) e INJI Verify Service real seja feita sem alterar
/// codigo. Nomes de env alinhados ao tutorial VerificaIdade
/// (`VITE_VERIFY_SERVICE_URL` / `VITE_CLIENT_ID_DID`):
///
/// ```sh
/// flutter run \
///   --dart-define=VERIFY_BASE_URL=https://SEU_DOMINIO_PUBLICO \
///   --dart-define=VERIFY_CLIENT_ID=did:web:SEU_DOMINIO_PUBLICO:v1:verify
/// ```
class AppConfig {
  const AppConfig._();

  /// Scheme proprio do app: e por ele que a Inji Wallet devolve o usuario.
  /// Precisa bater com `CFBundleURLSchemes` (iOS) e com o `intent-filter`
  /// do `AndroidManifest.xml` (Android).
  static const String appScheme = 'app18';

  /// `origin` enviado no deep link OID4VP.
  static const String appOrigin = '$appScheme://';

  /// Scheme da carteira (OID4VP). Declarado em `LSApplicationQueriesSchemes`
  /// (iOS) e em `<queries>` (Android 11+).
  static const String walletScheme = 'openid4vp';

  /// Endpoint de autorizacao da carteira.
  static const String walletAuthorizeUrl = '$walletScheme://authorize';

  /// Sentinela usado quando `VERIFY_BASE_URL` nao foi passado via
  /// `--dart-define`. Host `.invalid` (RFC 2606): nunca resolve por design,
  /// entao qualquer tentativa de uso real falha rapido e de forma
  /// reconhecivel (ver guarda em `VerifyService`) em vez de um erro de rede
  /// generico.
  static const String verifyBaseUrlSentinel = 'https://verify.invalid';

  /// Base do INJI Verify Service. Pendente de confirmacao (Fase 0 do plano);
  /// ate la o app roda contra o mock do M4.
  static const String verifyBaseUrl = String.fromEnvironment(
    'VERIFY_BASE_URL',
    defaultValue: verifyBaseUrlSentinel,
  );

  /// Context path fixo do servico (plano, secao 4).
  static const String verifyContextPath = '/v1/verify';

  /// Identificador do verificador (`clientId` no corpo do vp-request e
  /// `client_id` no deep link). Um DID `did:web:...` ou a URL publica do
  /// verificador. Default = valor local do tutorial.
  static const String clientId = String.fromEnvironment(
    'VERIFY_CLIENT_ID',
    defaultValue: 'did:web:localhost:v1:verify',
  );

  /// `id` da presentation definition (o objeto completo vive em
  /// `VerifyPresentation.ecaAgeCheck`, em `features/age_check/data`).
  static const String presentationDefinitionId = 'eca-age-verification';

  /// Permite `VERIFY_BASE_URL` sem TLS (`http://`) — **so para testar contra um
  /// INJI Verify Service em LAN sem ngrok**. Em builds debug o Android tambem
  /// libera cleartext (ver `src/debug/AndroidManifest.xml`).
  /// `--dart-define=VERIFY_ALLOW_INSECURE=true`
  static const bool allowInsecure = bool.fromEnvironment(
    'VERIFY_ALLOW_INSECURE',
    defaultValue: false,
  );

  /// Inclui `origin=app18://` no deep link `openid4vp://authorize`.
  ///
  /// **Default `true`**: o guia mobile do VerificaIdade (integra-mobile.html)
  /// exige `origin` no fluxo same-device — e por ele que a Inji Wallet sabe
  /// para onde voltar. Desligue so para experimentar
  /// (`--dart-define=VERIFY_SEND_ORIGIN=false`).
  static const bool sendOrigin = bool.fromEnvironment(
    'VERIFY_SEND_ORIGIN',
    defaultValue: true,
  );

  /// `true` quando um Verify Service real foi injetado via `--dart-define`.
  static bool get hasRealVerifyService =>
      verifyBaseUrl != verifyBaseUrlSentinel;

  /// URL completa do servico, ja com o context path.
  static String get verifyApiUrl => '$verifyBaseUrl$verifyContextPath';
}
