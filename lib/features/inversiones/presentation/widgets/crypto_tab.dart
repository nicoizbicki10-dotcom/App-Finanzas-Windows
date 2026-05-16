import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/percentage_badge.dart';
import '../../../market_data/domain/crypto_price.dart';
import '../../../market_data/providers/market_data_providers.dart';
import '../../domain/inversion_models.dart';
import '../providers/inversiones_provider.dart';
import 'acciones_tab.dart' show EditOperacionSheet;
import 'add_crypto_sheet.dart';
import 'inversion_total_banner.dart';
import 'exchange_selector_bar.dart';
import 'ticker_tape_widget.dart';

// ─── Sort enum ─────────────────────────────────────────────────────────────

enum _SortCrypto {
  valorActual('Valor actual total'),
  cantidad('Cantidad de cripto'),
  ganancia('Ganancia %');

  const _SortCrypto(this.label);
  final String label;
}

// ─── Tab ───────────────────────────────────────────────────────────────────

class CryptoTab extends ConsumerStatefulWidget {
  const CryptoTab({super.key});

  @override
  ConsumerState<CryptoTab> createState() => _CryptoTabState();
}

class _CryptoTabState extends ConsumerState<CryptoTab> {
  final _nombreCtrl = TextEditingController();

  String _searchNombre = '';
  String _searchWallet = '';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortCrypto? _sort;
  bool _sortAsc = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_searchWallet.isNotEmpty) c++;
    if (_fechaDesde != null || _fechaHasta != null) c++;
    if (_sort != null) c++;
    return c;
  }

  void _clearAll() => setState(() {
        _searchNombre = '';
        _nombreCtrl.clear();
        _searchWallet = '';
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
      });

  Future<void> _openFilters(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CryptoFilterSheet(
        initWallet: _searchWallet,
        initFechaDesde: _fechaDesde,
        initFechaHasta: _fechaHasta,
        initSort: _sort,
        initSortAsc: _sortAsc,
        onApply: (wallet, fechaD, fechaH, sort, sortAsc) => setState(() {
          _searchWallet = wallet;
          _fechaDesde = fechaD;
          _fechaHasta = fechaH;
          _sort = sort;
          _sortAsc = sortAsc;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(cryptoHoldingsProvider);

    // Deduplicar por symbol
    final Map<String, CryptoHolding> bySymbol = {};
    for (final h in holdings) {
      bySymbol.putIfAbsent(h.symbol, () => h);
    }
    final holdingsUnicos = bySymbol.values.toList();

    final coinIds =
        holdingsUnicos.map((h) => h.coingeckoId).toSet().join(',');
    final pricesAsync = ref.watch(cryptoPricesProvider(coinIds));

    // Ticker top 20 (también usado como fallback de precios por símbolo)
    final topCoinIdsStr = topCryptoIds.join(',');
    final topPricesAsync = ref.watch(cryptoPricesProvider(topCoinIdsStr));

    // priceMap keyed por coingeckoId. Para holdings con ID incorrecto (ej: 'btc'
    // en lugar de 'bitcoin'), se agrega un fallback buscando por símbolo en el
    // top-20 ya disponible, evitando mostrar variación 0.00% por un ID inválido.
    final priceMap = <String, CryptoPrice>{
      if (pricesAsync.value != null)
        for (final p in pricesAsync.value!) p.id: p,
    };
    if (topPricesAsync.value != null) {
      final topBySymbol = {for (final p in topPricesAsync.value!) p.symbol.toLowerCase(): p};
      for (final h in holdingsUnicos) {
        if (!priceMap.containsKey(h.coingeckoId)) {
          final fallback = topBySymbol[h.symbol.toLowerCase()];
          if (fallback != null) priceMap[h.coingeckoId] = fallback;
        }
      }
    }

    // Pre-computar cantidad y valor para filtrado/ordenamiento
    final Map<String, double> cantidadMap = {};
    final Map<String, double> valorActualMap = {};
    for (final h in holdingsUnicos) {
      final ops = ref.watch(operacionesCryptoProvider(h.symbol));
      final cantidad = ops
          .fold(0.0, (s, op) => op.tipoOp == TipoOperacion.compra
              ? s + op.cantidad
              : s - op.cantidad)
          .clamp(0.0, double.infinity);
      cantidadMap[h.symbol] = cantidad;
      final precio =
          priceMap[h.coingeckoId]?.currentPrice ?? h.precioCompraUSD;
      valorActualMap[h.symbol] = cantidad * precio;
    }

    // Ganancia % por holding (precio actual vs precio de compra)
    final Map<String, double> gananciaMapCrypto = {};
    for (final h in holdingsUnicos) {
      final precioCompra = h.precioCompraUSD;
      final precioActual =
          priceMap[h.coingeckoId]?.currentPrice ?? precioCompra;
      gananciaMapCrypto[h.symbol] = precioCompra > 0
          ? (precioActual - precioCompra) / precioCompra * 100
          : 0;
    }
    final worldTickerItems = topPricesAsync.whenOrNull(
          data: (prices) => prices
              .map((p) => TickerItem(
                    symbol: p.symbol.toUpperCase(),
                    price: p.currentPrice,
                    changePercent: p.priceChangePercent24h,
                  ))
              .toList(),
        ) ??
        [];

    // Aplicar filtros
    var lista = holdingsUnicos.where((h) {
      if (_searchNombre.isNotEmpty) {
        final q = _searchNombre.toLowerCase();
        if (!h.symbol.toLowerCase().contains(q) &&
            !h.nombre.toLowerCase().contains(q)) return false;
      }
      if (_searchWallet.isNotEmpty &&
          !(h.wallet?.toLowerCase().contains(_searchWallet.toLowerCase()) ??
              false)) return false;
      if (_fechaDesde != null &&
          h.fechaAdquisicion.isBefore(_fechaDesde!)) return false;
      if (_fechaHasta != null &&
          h.fechaAdquisicion.isAfter(
              _fechaHasta!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    // Aplicar orden
    if (_sort != null) {
      lista.sort((a, b) {
        final double va, vb;
        switch (_sort!) {
          case _SortCrypto.valorActual:
            va = valorActualMap[a.symbol] ?? 0;
            vb = valorActualMap[b.symbol] ?? 0;
          case _SortCrypto.cantidad:
            va = cantidadMap[a.symbol] ?? 0;
            vb = cantidadMap[b.symbol] ?? 0;
          case _SortCrypto.ganancia:
            va = gananciaMapCrypto[a.symbol] ?? 0;
            vb = gananciaMapCrypto[b.symbol] ?? 0;
        }
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      });
    }

    final totalCryptoAsync = ref.watch(valorCryptoUSDProvider);
    final dolarVenta = ref.watch(dolarProvider).value
            ?.where((d) => d.casa.toLowerCase() == 'blue')
            .map((d) => d.venta)
            .firstOrNull ??
        1050.0;

    final varCrypto = holdingsUnicos
        .where((h) => h.precioCompraUSD > 0)
        .map((h) => gananciaMapCrypto[h.symbol] ?? 0.0)
        .toList();
    final avgVarCrypto = varCrypto.isEmpty
        ? null
        : varCrypto.reduce((a, b) => a + b) / varCrypto.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InversionTotalBanner(
          totalUSD: totalCryptoAsync.value,
          dolarVenta: dolarVenta,
          seccionKey: 'Cripto',
          variacionPromedio: avgVarCrypto,
        ),
        if (worldTickerItems.isNotEmpty) ...[
          TickerTapeWidget(items: worldTickerItems),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Exchange / Wallet selector
        const ExchangeSelectorBar(
          prefKey: 'cripto_exchange',
          accentColor: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Search bar + actions ─────────────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o símbolo...',
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchNombre.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() {
                              _searchNombre = '';
                              _nombreCtrl.clear();
                            }))
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchNombre = v),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.tune,
                    color: _activeFilterCount > 0
                        ? AppColors.warning
                        : AppColors.textSecondary),
                tooltip: 'Filtros y orden',
                onPressed: () => _openFilters(context),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: AppColors.warning, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$_activeFilterCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddCryptoSheet(),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]),
        const SizedBox(height: 4),

        // ── Active filter chips ──────────────────────────────────────────
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (_searchWallet.isNotEmpty)
                _ActiveChip(
                    label: '💼 $_searchWallet',
                    onRemove: () => setState(() => _searchWallet = '')),
              if (_fechaDesde != null || _fechaHasta != null)
                _ActiveChip(
                    label:
                        'Compra: ${_fechaDesde != null ? DateFormat('MM/yy').format(_fechaDesde!) : '?'}–${_fechaHasta != null ? DateFormat('MM/yy').format(_fechaHasta!) : '?'}',
                    onRemove: () => setState(() {
                          _fechaDesde = null;
                          _fechaHasta = null;
                        })),
              if (_sort != null)
                _ActiveChip(
                    label: '${_sortAsc ? '↑' : '↓'} ${_sort!.label}',
                    onRemove: () => setState(() => _sort = null)),
              TextButton(
                onPressed: _clearAll,
                child: const Text('Limpiar todo',
                    style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],

        // ── Results count ────────────────────────────────────────────────
        if (holdingsUnicos.isNotEmpty &&
            (_activeFilterCount > 0 || _searchNombre.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
                '${lista.length} de ${holdingsUnicos.length} criptomonedas',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),

        // ── List ─────────────────────────────────────────────────────────
        if (holdingsUnicos.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('₿', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No tenés criptomonedas registradas',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          )
        else if (lista.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off,
                        size: 40, color: AppColors.textDisabled),
                    const SizedBox(height: 12),
                    const Text('Sin resultados',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                        onPressed: _clearAll,
                        child: const Text('Limpiar filtros')),
                  ]),
            ),
          )
        else
          Expanded(
            child: pricesAsync.isLoading && priceMap.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.warning),
                  )
                : _CryptoList(holdings: lista, priceMap: priceMap),
          ),
      ],
    );
  }
}

// ─── Filter sheet ──────────────────────────────────────────────────────────

class _CryptoFilterSheet extends StatefulWidget {
  final String initWallet;
  final DateTime? initFechaDesde;
  final DateTime? initFechaHasta;
  final _SortCrypto? initSort;
  final bool initSortAsc;
  final void Function(String wallet, DateTime? fechaD, DateTime? fechaH,
      _SortCrypto? sort, bool sortAsc) onApply;

  const _CryptoFilterSheet({
    required this.initWallet,
    required this.initFechaDesde,
    required this.initFechaHasta,
    required this.initSort,
    required this.initSortAsc,
    required this.onApply,
  });

  @override
  State<_CryptoFilterSheet> createState() => _CryptoFilterSheetState();
}

class _CryptoFilterSheetState extends State<_CryptoFilterSheet> {
  late final TextEditingController _walletCtrl;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  _SortCrypto? _sort;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _walletCtrl = TextEditingController(text: widget.initWallet);
    _fechaDesde = widget.initFechaDesde;
    _fechaHasta = widget.initFechaHasta;
    _sort = widget.initSort;
    _sortAsc = widget.initSortAsc;
  }

  @override
  void dispose() {
    _walletCtrl.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _walletCtrl.clear();
        _fechaDesde = null;
        _fechaHasta = null;
        _sort = null;
        _sortAsc = false;
      });

  void _apply() {
    widget.onApply(
        _walletCtrl.text.trim(), _fechaDesde, _fechaHasta, _sort, _sortAsc);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: Text('Filtros y ordenar',
                      style: Theme.of(context).textTheme.headlineMedium)),
              TextButton(
                  onPressed: _clear,
                  child: const Text('Limpiar',
                      style:
                          TextStyle(color: AppColors.danger, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            // ── Wallet / plataforma ───────────────────────────────────
            const _SectionLabel(label: 'Buscar por wallet / plataforma'),
            TextField(
              controller: _walletCtrl,
              decoration: const InputDecoration(
                hintText: 'Ej: Binance, Ledger, MetaMask...',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                    size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Fecha de compra ───────────────────────────────────────
            const _SectionLabel(label: 'Fecha de compra'),
            Row(children: [
              Expanded(
                  child: _DateButton(
                label: 'Desde',
                date: _fechaDesde,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaDesde ?? DateTime(2020),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaDesde = d);
                },
                onClear: _fechaDesde != null
                    ? () => setState(() => _fechaDesde = null)
                    : null,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _DateButton(
                label: 'Hasta',
                date: _fechaHasta,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaHasta ?? DateTime.now(),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => _fechaHasta = d);
                },
                onClear: _fechaHasta != null
                    ? () => setState(() => _fechaHasta = null)
                    : null,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Ordenar ───────────────────────────────────────────────
            const _SectionLabel(label: 'Ordenar por'),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _FilterChip2(
                  label: 'Sin ordenar',
                  selected: _sort == null,
                  onTap: () => setState(() => _sort = null)),
              ..._SortCrypto.values.map((s) => _FilterChip2(
                    label: s.label,
                    selected: _sort == s,
                    onTap: () =>
                        setState(() => _sort = _sort == s ? null : s),
                  )),
            ]),
            if (_sort != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('Dirección:',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('↓ Mayor primero'),
                  selected: !_sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = false),
                  selectedColor: AppColors.warning.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: !_sortAsc
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('↑ Menor primero'),
                  selected: _sortAsc,
                  onSelected: (_) => setState(() => _sortAsc = true),
                  selectedColor: AppColors.warning.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: _sortAsc
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Aplicar',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List + Card ───────────────────────────────────────────────────────────

class _CryptoList extends StatelessWidget {
  final List<CryptoHolding> holdings;
  final Map<String, CryptoPrice> priceMap;

  const _CryptoList({required this.holdings, required this.priceMap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: holdings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) =>
          _CryptoCard(holding: holdings[i], priceMap: priceMap),
    );
  }
}

class _CryptoCard extends ConsumerWidget {
  final CryptoHolding holding;
  final Map<String, CryptoPrice> priceMap;
  const _CryptoCard({required this.holding, required this.priceMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = holding;
    final price = priceMap[h.coingeckoId];
    final currentPrice = price?.currentPrice ?? h.precioCompraUSD;
    final changePercent = price?.priceChangePercent24h ?? 0.0;

    final operaciones = ref.watch(operacionesCryptoProvider(h.symbol));
    final cantidadActual = operaciones
        .fold(0.0, (sum, op) => op.tipoOp == TipoOperacion.compra
            ? sum + op.cantidad
            : sum - op.cantidad)
        .clamp(0.0, double.infinity);

    final valorActual = cantidadActual * currentPrice;
    final rentabilidad = h.precioCompraUSD > 0
        ? ((currentPrice - h.precioCompraUSD) / h.precioCompraUSD) * 100
        : 0.0;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: price?.imageUrl != null
                ? ClipOval(
                    child: Image.network(
                      price!.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(h.symbol.substring(0, 1),
                            style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : Center(
                    child: Text(h.symbol.substring(0, 1),
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(h.symbol,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  PercentageBadge(percentage: changePercent, fontSize: 11),
                ]),
                Text(h.nombre,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                Text(CurrencyFormatter.crypto(cantidadActual, h.symbol),
                    style: Theme.of(context).textTheme.bodySmall),
                if (h.wallet != null && h.wallet!.isNotEmpty)
                  Text('💼 ${h.wallet}',
                      style: const TextStyle(
                          color: AppColors.textDisabled, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.usd(valorActual),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              PercentageBadge(
                  percentage: rentabilidad, fontSize: 11, showIcon: false),
              Text(CurrencyFormatter.usd(currentPrice),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.history,
                size: 18, color: AppColors.textSecondary),
            tooltip: 'Historial',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _HistorialCryptoSheet(symbol: h.symbol),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSecondary),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddCryptoSheet(crypto: h),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.textDisabled),
            onPressed: () => ref
                .read(inversionesNotifierProvider.notifier)
                .eliminarCryptosPorSymbol(h.symbol),
          ),
        ],
      ),
    );
  }
}

// ─── Filter helper widgets (local copies) ─────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.warning),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip2(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warning.withOpacity(0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.warning : AppColors.surfaceBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? AppColors.warning : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateButton(
      {required this.label,
      required this.date,
      required this.onTap,
      this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null
              ? AppColors.warning.withOpacity(0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: date != null
                  ? AppColors.warning
                  : AppColors.surfaceBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                  Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date!)
                        : 'Seleccionar',
                    style: TextStyle(
                        fontSize: 12,
                        color: date != null
                            ? AppColors.warning
                            : AppColors.textDisabled,
                        fontWeight: date != null
                            ? FontWeight.w500
                            : FontWeight.normal),
                  ),
                ]),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear,
                  size: 14, color: AppColors.textDisabled),
            )
          else
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textDisabled),
        ]),
      ),
    );
  }
}

// ─── Historial sheet ───────────────────────────────────────────────────────

class _HistorialCryptoSheet extends ConsumerWidget {
  final String symbol;
  const _HistorialCryptoSheet({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operaciones = ref.watch(operacionesCryptoProvider(symbol));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Historial de $symbol',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            if (operaciones.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 40, color: AppColors.textDisabled),
                      SizedBox(height: 12),
                      Text('Sin operaciones registradas',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  itemCount: operaciones.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                  itemBuilder: (ctx, i) {
                    final op = operaciones[i];
                    final isCompra = op.tipoOp == TipoOperacion.compra;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isCompra
                                      ? AppColors.success
                                      : AppColors.danger)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCompra
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isCompra
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCompra ? 'Compra' : 'Venta',
                                  style: TextStyle(
                                    color: isCompra
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(op.fecha),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11),
                                ),
                                if (op.exchange != null)
                                  Text(op.exchange!,
                                      style: const TextStyle(
                                          color: AppColors.textDisabled,
                                          fontSize: 10)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.usd(op.montoTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                '${op.cantidad % 1 == 0 ? op.cantidad.toStringAsFixed(0) : op.cantidad.toStringAsFixed(6)} × ${CurrencyFormatter.usd(op.precioUSD)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16,
                                color: AppColors.textSecondary),
                            onPressed: () => showModalBottomSheet(
                              context: ctx,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EditOperacionSheet(op: op),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16,
                                color: AppColors.textDisabled),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Eliminar operación'),
                                  content: Text(
                                      '¿Eliminar esta ${isCompra ? "compra" : "venta"} de $symbol?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text('Cancelar')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, true),
                                        child: const Text('Eliminar',
                                            style: TextStyle(
                                                color: AppColors.danger))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                ref
                                    .read(inversionesNotifierProvider.notifier)
                                    .eliminarOperacion(op);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
