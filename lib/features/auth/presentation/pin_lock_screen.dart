import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../usuarios/presentation/providers/usuarios_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _input = '';
  bool _error = false;
  bool _biometricDisponible = false;
  final _localAuth = LocalAuthentication();

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    // Esperar a que la ventana tenga foco antes de pedir biometría.
    // Llamarlo en initState falla silenciosamente en macOS/iOS.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _verificarBiometria();
    });
  }

  Future<void> _verificarBiometria() async {
    try {
      final soportado = await _localAuth.isDeviceSupported();
      final disponible = await _localAuth.canCheckBiometrics;
      final tipos = await _localAuth.getAvailableBiometrics();
      print('[AUTH] isDeviceSupported=$soportado canCheckBiometrics=$disponible tipos=$tipos');
      if (mounted) {
        setState(() => _biometricDisponible = soportado);
      }
      if (soportado) _intentarTouchId();
    } catch (e) {
      print('[AUTH] Error en _verificarBiometria: $e');
    }
  }

  Future<void> _intentarTouchId() async {
    try {
      print('[AUTH] Intentando autenticación biométrica...');
      final ok = await _localAuth.authenticate(
        localizedReason: 'Verificá tu identidad para acceder',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      print('[AUTH] Resultado autenticación: $ok');
      if (ok && mounted) {
        ref.read(isLockedProvider.notifier).state = false;
      }
    } catch (e) {
      print('[AUTH] Error en _intentarTouchId: $e');
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = false;
    });
    if (_input.length == 4) _verificar();
  }

  void _onBorrar() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _verificar() async {
    final userId = ref.read(currentUserIdProvider);
    final user = ref.read(usuariosRepositoryProvider).getAll()
        .where((u) => u.id == userId).firstOrNull;

    if (user?.pin == _input) {
      ref.read(isLockedProvider.notifier).state = false;
    } else {
      setState(() {
        _error = true;
        _input = '';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final user = ref.watch(usuariosListProvider)
        .where((u) => u.id == userId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: user != null
                      ? Color(user.colorValue)
                      : AppColors.primary,
                  child: Text(
                    user?.nombre.isNotEmpty == true
                        ? user!.nombre[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.nombre ?? 'Mi cuenta',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresá tu PIN',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),

                // Puntos PIN
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      _error ? 8 * (0.5 - _shakeAnim.value).abs() * 4 : 0,
                      0,
                    ),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _input.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _error
                              ? AppColors.danger
                              : filled
                                  ? AppColors.primary
                                  : Colors.transparent,
                          border: Border.all(
                            color: _error
                                ? AppColors.danger
                                : AppColors.surfaceBorder,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                if (_error) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'PIN incorrecto',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 48),

                // Teclado numérico
                _NumPad(
                  onDigit: _onDigit,
                  onBorrar: _onBorrar,
                ),

                if (_biometricDisponible) ...[
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _intentarTouchId,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text('Usar Touch ID'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBorrar;

  const _NumPad({required this.onDigit, required this.onBorrar});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 88, height: 72);
            if (key == 'DEL') {
              return _NumKey(
                child: const Icon(Icons.backspace_outlined,
                    color: AppColors.textSecondary),
                onTap: onBorrar,
              );
            }
            return _NumKey(
              child: Text(key,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
              onTap: () => onDigit(key),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NumKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 72,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ─── Diálogo para configurar PIN ──────────────────────────────────────────────

Future<void> mostrarSetupPin(BuildContext context, WidgetRef ref, String userId) async {
  await showDialog(
    context: context,
    builder: (ctx) => _SetupPinDialog(userId: userId),
  );
}

class _SetupPinDialog extends ConsumerStatefulWidget {
  final String userId;
  const _SetupPinDialog({required this.userId});

  @override
  ConsumerState<_SetupPinDialog> createState() => _SetupPinDialogState();
}

class _SetupPinDialogState extends ConsumerState<_SetupPinDialog> {
  String _pin1 = '';
  String _pin2 = '';
  bool _confirmando = false;
  bool _errorConfirmacion = false;

  void _onDigit(String d) {
    setState(() {
      _errorConfirmacion = false;
      if (!_confirmando) {
        if (_pin1.length < 4) _pin1 += d;
        if (_pin1.length == 4) _confirmando = true;
      } else {
        if (_pin2.length < 4) _pin2 += d;
        if (_pin2.length == 4) _guardar();
      }
    });
  }

  void _onBorrar() {
    setState(() {
      if (_confirmando) {
        if (_pin2.isEmpty) {
          _confirmando = false;
        } else {
          _pin2 = _pin2.substring(0, _pin2.length - 1);
        }
      } else {
        if (_pin1.isNotEmpty) _pin1 = _pin1.substring(0, _pin1.length - 1);
      }
    });
  }

  void _guardar() {
    if (_pin1 != _pin2) {
      setState(() {
        _errorConfirmacion = true;
        _pin2 = '';
      });
      return;
    }
    ref.read(usuariosNotifierProvider.notifier).setPin(widget.userId, _pin1);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = _confirmando ? _pin2 : _pin1;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirmando ? 'Confirmá el PIN' : 'Elegí un PIN de 4 dígitos',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < current.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _errorConfirmacion
                        ? AppColors.danger
                        : filled
                            ? AppColors.primary
                            : Colors.transparent,
                    border: Border.all(
                      color: _errorConfirmacion
                          ? AppColors.danger
                          : AppColors.surfaceBorder,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_errorConfirmacion) ...[
              const SizedBox(height: 8),
              const Text('Los PINs no coinciden',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            _NumPad(onDigit: _onDigit, onBorrar: _onBorrar),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
