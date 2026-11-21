import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/sync_engine.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../finance/data/repositories/finance_repository.dart';

/// Stream reactivo del estado de autenticación de Supabase (o null si no está configurado).
final authStateProvider = StreamProvider<User?>((ref) {
  final client = SupabaseConfig.clientOrNull;
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange.map((e) => e.session?.user);
});

/// Modal de Sincronización en la Nube (Supabase Auth + Push/Pull manual).
Future<void> showCloudSyncDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _CloudSyncDialog(),
  );
}

class _CloudSyncDialog extends ConsumerStatefulWidget {
  const _CloudSyncDialog();

  @override
  ConsumerState<_CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends ConsumerState<_CloudSyncDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;

    setState(() {
      _loading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      await client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final result = await ref.read(syncEngineProvider).syncAll();
      ref.invalidate(financeSummaryProvider);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = result.status == SyncStatus.error;
        _statusMessage = result.status == SyncStatus.idle
            ? 'Sesión iniciada y sincronización completada.'
            : (result.lastError ?? 'Sesión iniciada.');
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = true;
        _statusMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = true;
        _statusMessage = e.toString();
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
      _isError = false;
    });
    final result = await ref.read(syncEngineProvider).syncAll();
    ref.invalidate(financeSummaryProvider);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _isError = result.status == SyncStatus.error;
      _statusMessage = switch (result.status) {
        SyncStatus.idle => 'Sincronización Push + Pull completada.',
        SyncStatus.offline => 'Sin conexión a internet. Tus datos siguen seguros localmente.',
        SyncStatus.unauthenticated => 'Inicia sesión primero para sincronizar.',
        SyncStatus.unconfigured => 'Supabase no está configurado aún.',
        SyncStatus.syncing => 'Ya hay una sincronización en curso.',
        SyncStatus.error => 'Error: ${result.lastError ?? "desconocido"}',
      };
    });
  }

  Future<void> _signOut() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;
    await client.auth.signOut();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Sesión cerrada. Modo local Offline-First activo.';
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = SupabaseConfig.clientOrNull;
    final currentUser = client?.auth.currentUser;
    final pendingCount = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: AppColors.accentCyan),
          SizedBox(width: 8),
          Text('Nube Supabase'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!SupabaseConfig.isConfigured) ...[
                const Text(
                  'La app está funcionando en modo 100% local (Offline-First).',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para activar sincronización entre tu Android, iPad y bots, ejecuta la app pasando tus credenciales de Supabase:\n\n'
                  '--dart-define=SUPABASE_URL=https://xxx.supabase.co\n'
                  '--dart-define=SUPABASE_ANON_KEY=tu_clave',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (currentUser != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conectado a Supabase',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email ?? currentUser.id,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pendientes en cola local: $pendingCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _syncNow,
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(
                          _loading ? 'Sincronizando...' : 'Sincronizar Ahora',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _loading ? null : _signOut,
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Inicia sesión con tu usuario de Supabase para sincronizar tus ventas, pedidos y jornada entre Android y iPad.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Ingresa un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onFieldSubmitted: (_) => _signIn(),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      _loading ? 'Conectando...' : 'Iniciar Sesión y Sincronizar',
                    ),
                  ),
                ),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isError ? AppColors.error : AppColors.accentCyan,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
