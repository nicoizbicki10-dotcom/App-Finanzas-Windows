import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kNavOrderKey = 'nav_item_order_v1';

class NavItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const kAllNavItems = [
  NavItem(
    route: '/resumen',
    label: 'Patrimonio',
    icon: Icons.pie_chart_outline,
    selectedIcon: Icons.pie_chart,
  ),
  NavItem(
    route: '/caja',
    label: 'Caja',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  NavItem(
    route: '/gastos',
    label: 'Gastos',
    icon: Icons.credit_card_outlined,
    selectedIcon: Icons.credit_card,
  ),
  NavItem(
    route: '/ingresos',
    label: 'Ingresos',
    icon: Icons.trending_up_outlined,
    selectedIcon: Icons.trending_up,
  ),
  NavItem(
    route: '/inversiones',
    label: 'Inversiones',
    icon: Icons.savings_outlined,
    selectedIcon: Icons.savings,
  ),
  NavItem(
    route: '/pasivos',
    label: 'Pasivos',
    icon: Icons.trending_down_outlined,
    selectedIcon: Icons.trending_down,
  ),
  NavItem(
    route: '/objetivos',
    label: 'Objetivos',
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag,
  ),
  NavItem(
    route: '/ia',
    label: 'IA',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  ),
  NavItem(
    route: '/cuentas',
    label: 'Cuentas',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts,
  ),
];

class NavOrderNotifier extends StateNotifier<List<NavItem>> {
  NavOrderNotifier() : super(kAllNavItems) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kNavOrderKey);
    if (json == null) return;

    final routes = (jsonDecode(json) as List).cast<String>();
    final ordered = routes
        .map((r) => kAllNavItems.where((i) => i.route == r).firstOrNull)
        .whereType<NavItem>()
        .toList();

    // Append any new items added since the order was saved
    for (final item in kAllNavItems) {
      if (!ordered.any((i) => i.route == item.route)) {
        ordered.add(item);
      }
    }

    if (mounted) state = ordered;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _persist(list);
  }

  Future<void> resetToDefault() async {
    state = kAllNavItems;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNavOrderKey);
  }

  Future<void> _persist(List<NavItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kNavOrderKey, jsonEncode(items.map((i) => i.route).toList()));
  }
}

final navOrderProvider =
    StateNotifierProvider<NavOrderNotifier, List<NavItem>>(
  (ref) => NavOrderNotifier(),
);
