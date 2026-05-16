import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pin_lock_screen.dart';
import '../../features/caja/presentation/caja_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/gastos/presentation/gastos_screen.dart';
import '../../features/ia/presentation/ia_screen.dart';
import '../../features/ingresos/presentation/ingresos_screen.dart';
import '../../features/inversiones/presentation/inversiones_screen.dart';
import '../../features/objetivos/presentation/objetivos_screen.dart';
import '../../features/pasivos/presentation/pasivos_screen.dart';
import '../../features/rentabilidad/presentation/rentabilidad_screen.dart';
import '../../features/usuarios/presentation/cuentas_screen.dart';
import '../../features/pasivos/presentation/providers/pasivos_provider.dart';
import '../../features/usuarios/presentation/providers/usuarios_provider.dart';
import '../constants/app_colors.dart';
import '../providers/nav_order_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/resumen',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/resumen',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/caja',
            builder: (context, state) => const CajaScreen(),
          ),
          GoRoute(
            path: '/gastos',
            builder: (context, state) => const GastosScreen(),
          ),
          GoRoute(
            path: '/ingresos',
            builder: (context, state) => const IngresosScreen(),
          ),
          GoRoute(
            path: '/inversiones',
            builder: (context, state) => const InversionesScreen(),
          ),
          GoRoute(
            path: '/pasivos',
            builder: (context, state) => const PasivosScreen(),
          ),
          GoRoute(
            path: '/objetivos',
            builder: (context, state) => const ObjetivosScreen(),
          ),
          GoRoute(
            path: '/cuentas',
            builder: (context, state) => const CuentasScreen(),
          ),
          GoRoute(
            path: '/rentabilidad',
            builder: (context, state) => const RentabilidadScreen(),
          ),
          GoRoute(
            path: '/ia',
            builder: (context, state) => const IaScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _lockDelay = Duration(minutes: 30);
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pasivosNotifierProvider.notifier).migrarCuotasExistentes();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _lockTimer?.cancel();
      _lockTimer = Timer(_lockDelay, _bloquearSiTienePin);
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
      _lockTimer = null;
    }
  }

  void _bloquearSiTienePin() {
    final userId = ref.read(currentUserIdProvider);
    final user = ref.read(usuariosRepositoryProvider)
        .getAll()
        .where((u) => u.id == userId)
        .firstOrNull;
    if (user?.pin != null) {
      ref.read(isLockedProvider.notifier).state = true;
    }
  }

  int _currentIndex(BuildContext context, List<NavItem> items) {
    final location = GoRouterState.of(context).uri.path;
    final index = items.indexWhere((t) => location.startsWith(t.route));
    return index < 0 ? 0 : index;
  }

  void _abrirReordenador(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ordenar secciones', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 300,
          height: 420,
          child: Consumer(
            builder: (ctx, ref, _) {
              final items = ref.watch(navOrderProvider);
              return ReorderableListView(
                onReorder: (oldIndex, newIndex) =>
                    ref.read(navOrderProvider.notifier).reorder(oldIndex, newIndex),
                children: [
                  for (final item in items)
                    ListTile(
                      key: ValueKey(item.route),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(item.icon, size: 20, color: AppColors.textSecondary),
                      title: Text(item.label,
                          style: const TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.drag_handle,
                          color: AppColors.textDisabled),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(navOrderProvider.notifier).resetToDefault();
            },
            child: const Text('Restablecer',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Listo',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(isLockedProvider);
    if (isLocked) return const PinLockScreen();

    final navItems = ref.watch(navOrderProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final currentIndex = _currentIndex(context, navItems);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(navItems[i].route),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              trailing: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: IconButton(
                  icon: const Icon(Icons.reorder, size: 20),
                  tooltip: 'Ordenar secciones',
                  color: AppColors.textDisabled,
                  onPressed: () => _abrirReordenador(context),
                ),
              ),
              destinations: [
                for (final item in navItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(navItems[i].route),
          type: BottomNavigationBarType.fixed,
          items: [
            for (final item in navItems)
              BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
