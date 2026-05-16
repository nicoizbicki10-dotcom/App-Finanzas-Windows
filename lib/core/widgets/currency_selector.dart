import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/display_currency_provider.dart';

class CurrencySelector extends ConsumerWidget {
  final Color color;
  const CurrencySelector({super.key, this.color = Colors.white});

  static const _options = [
    ('USD', 'Dólar estadounidense'),
    ('ARS', 'Peso argentino'),
    ('EUR', 'Euro'),
    ('CHF', 'Franco suizo'),
    ('GBP', 'Libra esterlina'),
    ('BRL', 'Real brasileño'),
    ('CNY', 'Yuan chino'),
    ('JPY', 'Yen japonés'),
    ('BTC', 'Bitcoin'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    return PopupMenuButton<String>(
      onSelected: (v) => ref.read(displayCurrencyProvider.notifier).state = v,
      itemBuilder: (_) => _options
          .map((o) => PopupMenuItem(
                value: o.$1,
                child: Row(children: [
                  Text(o.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(o.$2,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ]),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
