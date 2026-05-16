import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'widgets/acciones_tab.dart';
import 'widgets/alternativas_tab.dart';
import 'widgets/bienes_tab.dart';
import 'widgets/crypto_tab.dart';
import 'widgets/inmuebles_tab.dart';
import 'widgets/instrumentos_tab.dart';
import 'widgets/liquidez_tab.dart';
import 'widgets/negocio_tab.dart';
import 'widgets/otras_tab.dart';

class _TabDef {
  final String id;
  final String label;
  const _TabDef({required this.id, required this.label});
}

class InversionesScreen extends ConsumerStatefulWidget {
  const InversionesScreen({super.key});

  @override
  ConsumerState<InversionesScreen> createState() => _InversionesScreenState();
}

class _InversionesScreenState extends ConsumerState<InversionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<_TabDef> _kTabMeta = [
    _TabDef(id: 'inmuebles', label: '🏠 Inmuebles'),
    _TabDef(id: 'acciones', label: '📈 Acciones'),
    _TabDef(id: 'cripto', label: '₿ Cripto'),
    _TabDef(id: 'liquidez', label: '💵 Liquidez'),
    _TabDef(id: 'instrumentos', label: '🏛️ Instrumentos Financieros'),
    _TabDef(id: 'bienes', label: '🚗 Bienes de Uso'),
    _TabDef(id: 'otras', label: '📦 Otras'),
    _TabDef(id: 'negocio', label: '🏪 Negocio Personal'),
    _TabDef(id: 'alternativas', label: '💎 Inv. Alternativas'),
  ];

  List<String> _tabOrder = [
    'inmuebles', 'acciones', 'cripto', 'liquidez',
    'instrumentos', 'bienes', 'otras', 'negocio', 'alternativas',
  ];
  bool _orderLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabMeta.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('inversiones_tab_order');
      if (saved != null &&
          saved.length == _kTabMeta.length &&
          saved.toSet().containsAll(_kTabMeta.map((t) => t.id).toSet())) {
        setState(() {
          _tabOrder = saved;
          _orderLoaded = true;
        });
      } else {
        setState(() => _orderLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _viewForId(String id) {
    switch (id) {
      case 'inmuebles': return const InmueblesTab();
      case 'acciones': return const AccionesTab();
      case 'cripto': return const CryptoTab();
      case 'liquidez': return const LiquidezTab();
      case 'instrumentos': return const InstrumentosTab();
      case 'bienes': return const BienesTab();
      case 'otras': return const OtrasTab();
      case 'negocio': return const NegocioTab();
      case 'alternativas': return const AlternativasTab();
      default: return const SizedBox.shrink();
    }
  }

  Future<void> _openReorderSheet() async {
    List<String> tempOrder = List.from(_tabOrder);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Expanded(
                      child: Text('Ordenar pestañas',
                          style: Theme.of(ctx).textTheme.headlineMedium),
                    ),
                    TextButton(
                      onPressed: () {
                        tempOrder = _kTabMeta.map((t) => t.id).toList();
                        setS(() {});
                      },
                      child: const Text('Restablecer',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: sc,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: tempOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setS(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = tempOrder.removeAt(oldIndex);
                        tempOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (_, i) {
                      final id = tempOrder[i];
                      final meta = _kTabMeta.firstWhere((t) => t.id == id);
                      return ListTile(
                        key: ValueKey(id),
                        leading: const Icon(Icons.drag_handle,
                            color: AppColors.textSecondary),
                        title: Text(meta.label,
                            style: const TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.reorder,
                            color: AppColors.textDisabled, size: 16),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setStringList(
                          'inversiones_tab_order', tempOrder);
                      if (context.mounted) Navigator.of(ctx).pop();
                      setState(() {
                        _tabOrder = tempOrder;
                        _tabController.dispose();
                        _tabController = TabController(
                            length: _kTabMeta.length, vsync: this);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Guardar orden',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inversiones y Otros Activos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_week_outlined),
            tooltip: 'Ordenar pestañas',
            onPressed: _openReorderSheet,
          ),
        ],
        bottom: _orderLoaded
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: _tabOrder.map((id) {
                  final meta = _kTabMeta.firstWhere((t) => t.id == id);
                  return Tab(text: meta.label);
                }).toList(),
              )
            : null,
      ),
      body: !_orderLoaded
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(
                        height: 600,
                        child: TabBarView(
                          controller: _tabController,
                          children: _tabOrder
                              .map((id) => _viewForId(id))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

