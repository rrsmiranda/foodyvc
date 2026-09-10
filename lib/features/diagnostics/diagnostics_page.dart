import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/widgets.dart';
import '../age_check/application/age_check_controller.dart';
import '../age_check/data/verify_service.dart';

/// Tela de diagnostico para QA — mostra a configuracao efetiva e permite
/// disparar cada chamada REST isoladamente (health, vp-request + carteira,
/// status, resultado). Nao faz parte do fluxo de compra.
///
/// Acesso: acao na AppBar da `ShopPage` (so em build debug) ou rota `/diag`.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  bool _busy = false;
  String? _health;
  String? _session;
  String? _status;
  String? _result;
  String? _error;
  String? _requestId;
  String? _transactionId;

  VerifyService get _service => ref.read(verifyServiceProvider);

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on VerifyException catch (e) {
      setState(() => _error = '$label: ${e.runtimeType} — ${e.message}');
    } catch (e) {
      setState(() => _error = '$label: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkHealth() => _run('health', () async {
        final bool up = await _service.checkHealth();
        setState(() => _health = up ? 'UP' : 'sem resposta / DOWN');
      });

  Future<void> _createRequest() => _run('vp-request', () async {
        final ({String requestId, String transactionId}) s =
            await _service.createVpRequestAndOpenWallet();
        setState(() {
          _requestId = s.requestId;
          _transactionId = s.transactionId;
          _session =
              'requestId=${s.requestId}\ntransactionId=${s.transactionId}';
          _status = null;
          _result = null;
        });
      });

  Future<void> _pollStatus() => _run('status', () async {
        final String v = await _service.pollStatus(_requestId!);
        setState(() => _status = v);
      });

  Future<void> _getResult() => _run('vp-result', () async {
        final ({bool underage, bool verified}) r =
            await _service.getResult(_transactionId!);
        setState(
            () => _result = 'verified=${r.verified} · underage=${r.underage}');
      });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostico'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text('Configuracao efetiva', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _Kv('VERIFY_BASE_URL', AppConfig.verifyBaseUrl),
          const _Kv('Verify API', '${AppConfig.verifyBaseUrl}/v1/verify'),
          const _Kv('clientId', AppConfig.clientId),
          const _Kv(
            'presentationDefinition',
            AppConfig.presentationDefinitionId,
          ),
          const _Kv('deep link', AppConfig.walletAuthorizeUrl),
          const _Kv('origin no deep link', '${AppConfig.sendOrigin}'),
          const _Kv('allowInsecure (HTTP)', '${AppConfig.allowInsecure}'),
          _Kv('Verify Service real?', '${AppConfig.hasRealVerifyService}'),
          const Divider(height: AppSpacing.xl),
          if (_error != null) ...<Widget>[
            AppBanner(kind: AppBannerKind.error, message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          _Step(
            title: '0. Health check',
            output: _health == null ? null : 'status: $_health',
            button: AppButton(
              label: 'GET /actuator/health',
              onPressed: _busy ? null : _checkHealth,
              loading: _busy,
            ),
          ),
          _Step(
            title: '1. Criar VP request + abrir carteira',
            output: _session,
            button: AppButton(
              label: 'POST /vp-request',
              onPressed: _busy ? null : _createRequest,
              loading: _busy,
            ),
          ),
          _Step(
            title: '2. Consultar status',
            output: _status == null ? null : 'status: $_status',
            button: AppButton(
              label: 'GET /vp-request/{id}/status',
              variant: AppButtonVariant.secondary,
              onPressed: (_busy || _requestId == null) ? null : _pollStatus,
            ),
          ),
          _Step(
            title: '3. Obter resultado',
            output: _result,
            button: AppButton(
              label: 'GET /vp-result/{txn}',
              variant: AppButtonVariant.secondary,
              onPressed: (_busy || _transactionId == null) ? null : _getResult,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Passos 2 e 3 usam requestId/transactionId do passo 1. Em device: '
            'autorize na carteira entre o passo 1 e o 2.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(k, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(v, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.button, this.output});
  final String title;
  final Widget button;
  final String? output;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          button,
          if (output != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: SelectableText(
                output!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
