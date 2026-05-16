import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class TickerItem {
  final String symbol;
  final double price;
  final double changePercent;

  const TickerItem({
    required this.symbol,
    required this.price,
    required this.changePercent,
  });
}

class TickerTapeWidget extends StatefulWidget {
  final List<TickerItem> items;

  const TickerTapeWidget({super.key, required this.items});

  @override
  State<TickerTapeWidget> createState() => _TickerTapeWidgetState();
}

class _TickerTapeWidgetState extends State<TickerTapeWidget> {
  late final ScrollController _sc;
  Timer? _timer;

  // Cuántas copias necesitamos para que el scroll sea continuo sin gaps visibles
  static const int _copies = 6;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_sc.hasClients) return;
      final max = _sc.position.maxScrollExtent;
      if (max == 0) return;
      // Una copia es 1/_copies del total; volver a inicio de la segunda copia
      final oneChunk = max / (_copies - 1);
      final next = _sc.offset + 0.6;
      if (next >= oneChunk) {
        _sc.jumpTo(next - oneChunk);
      } else {
        _sc.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // Duplicar los items suficientes veces para el loop sin saltos visibles
    final displayItems = List.generate(_copies, (_) => widget.items).expand((x) => x).toList();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayItems.length,
        itemBuilder: (_, i) => _TickerItemWidget(item: displayItems[i]),
      ),
    );
  }
}

class _TickerItemWidget extends StatelessWidget {
  final TickerItem item;
  const _TickerItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.changePercent >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.danger;
    final changeSign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.symbol,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatPrice(item.price),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 14,
            color: changeColor,
          ),
          Text(
            '$changeSign${item.changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: changeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: AppColors.surfaceBorder),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return '\$${price.toStringAsFixed(0)}';
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    return '\$${price.toStringAsFixed(4)}';
  }
}
