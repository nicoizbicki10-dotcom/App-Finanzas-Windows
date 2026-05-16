import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/pin_lock_screen.dart';
import '../domain/usuario.dart';
import 'providers/usuarios_provider.dart';

class CuentasScreen extends ConsumerWidget {
  const CuentasScreen({super.key});

  static const List<int> _colores = [
    0xFF2196F3, // blue
    0xFF4CAF50, // green
    0xFFFF9800, // orange
    0xFF9C27B0, // purple
    0xFFF44336, // red
    0xFF009688, // teal
    0xFFE91E63, // pink
    0xFF607D8B, // blue grey
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosListProvider);
    final currentId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            snap: true,
            title: Text('Cuentas'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SectionHeader(
                  title: 'MIS CUENTAS',
                  subtitle: 'Cada cuenta tiene sus propios datos',
                ),
                const SizedBox(height: AppSpacing.sm),
                ...usuarios.map((u) {
                  final isActive = u.id == currentId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(u.colorValue),
                            radius: 22,
                            backgroundImage: u.fotoUrl != null && u.fotoUrl!.isNotEmpty
                                ? NetworkImage(u.fotoUrl!)
                                : null,
                            child: u.fotoUrl == null || u.fotoUrl!.isEmpty
                                ? Text(
                                    u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.nombre,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                if (isActive)
                                  const Text('Cuenta activa',
                                      style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 11)),
                              ],
                            ),
                          ),
                          if (!isActive)
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(usuariosNotifierProvider.notifier)
                                    .seleccionar(u.id);
                              },
                              child: const Text('Usar'),
                            ),
                          // Botón editar perfil
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18,
                                color: AppColors.textSecondary),
                            tooltip: 'Editar perfil',
                            onPressed: () => _editarPerfil(context, ref, u),
                          ),
                          // Botón PIN (siempre visible para la cuenta activa)
                          IconButton(
                            icon: Icon(
                              u.pin != null ? Icons.lock : Icons.lock_open,
                              size: 18,
                              color: u.pin != null
                                  ? AppColors.warning
                                  : AppColors.textDisabled,
                            ),
                            tooltip: u.pin != null ? 'Cambiar/quitar PIN' : 'Agregar PIN',
                            onPressed: () => _gestionarPin(context, ref, u.id, u.pin),
                          ),
                          if (isActive)
                            const Icon(Icons.check_circle,
                                color: AppColors.success, size: 20),
                          if (usuarios.length > 1 && !isActive)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.textDisabled),
                              onPressed: () => _confirmarEliminar(
                                  context, ref, u.id, u.nombre),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _mostrarCrearUsuario(context, ref),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Nueva cuenta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarPerfil(
      BuildContext context, WidgetRef ref, UsuarioPerfil usuario) async {
    final nombreCtrl = TextEditingController(text: usuario.nombre);
    final fotoCtrl = TextEditingController(text: usuario.fotoUrl ?? '');
    int selectedColor = usuario.colorValue;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Editar cuenta', style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre de la cuenta'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fotoCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de foto de perfil (opcional)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colores.map((c) {
                  final selected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final nombre = nombreCtrl.text.trim();
                    if (nombre.isEmpty) return;
                    final fotoUrl = fotoCtrl.text.trim().isEmpty ? null : fotoCtrl.text.trim();
                    await ref.read(usuariosNotifierProvider.notifier)
                        .actualizarPerfil(usuario.id, nombre, selectedColor, fotoUrl);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Guardar cambios',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarCrearUsuario(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    int selectedColor = _colores[0];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Nueva cuenta',
                  style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre de la cuenta'),
              ),
              const SizedBox(height: 16),
              const Text('Color',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colores.map((c) {
                  final selected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final nombre = ctrl.text.trim();
                    if (nombre.isEmpty) return;
                    final usuario = await ref
                        .read(usuariosNotifierProvider.notifier)
                        .crearUsuario(nombre, selectedColor);
                    await ref
                        .read(usuariosNotifierProvider.notifier)
                        .seleccionar(usuario.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Crear y activar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gestionarPin(
      BuildContext context, WidgetRef ref, String id, String? pinActual) async {
    if (pinActual != null) {
      // Ya tiene PIN — ofrecer cambiar o quitar
      final accion = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Gestionar PIN'),
          content: const Text('Esta cuenta tiene un PIN configurado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'quitar'),
              child: const Text('Quitar PIN', style: TextStyle(color: AppColors.danger)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cambiar'),
              child: const Text('Cambiar PIN'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (accion == 'quitar') {
        ref.read(usuariosNotifierProvider.notifier).setPin(id, null);
      } else if (accion == 'cambiar' && context.mounted) {
        await mostrarSetupPin(context, ref, id);
      }
    } else {
      await mostrarSetupPin(context, ref, id);
    }
  }

  Future<void> _confirmarEliminar(
      BuildContext context, WidgetRef ref, String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar cuenta'),
        content: Text('¿Eliminar la cuenta "$nombre" y todos sus datos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      ref.read(usuariosNotifierProvider.notifier).eliminarUsuario(id);
    }
  }
}
