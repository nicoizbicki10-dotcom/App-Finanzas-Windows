import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/exchange_data.dart';

class ExchangeSelectorBar extends StatefulWidget {
  final String prefKey;
  final Color accentColor;

  const ExchangeSelectorBar({
    super.key,
    required this.prefKey,
    this.accentColor = AppColors.primary,
  });

  @override
  State<ExchangeSelectorBar> createState() => _ExchangeSelectorBarState();
}

class _ExchangeSelectorBarState extends State<ExchangeSelectorBar> {
  String _exchange = kExchanges.first.nombre;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(widget.prefKey);
    if (saved != null && kExchanges.any((e) => e.nombre == saved)) {
      setState(() => _exchange = saved);
    }
  }

  Future<void> _guardar(String nombre) async {
    setState(() => _exchange = nombre);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.prefKey, nombre);
  }

  ExchangeInfo get _info => kExchanges.firstWhere(
        (e) => e.nombre == _exchange,
        orElse: () => kExchanges.first,
      );

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Selector dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _exchange,
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.surfaceElevated,
                style: TextStyle(
                  color: widget.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                icon: Icon(Icons.expand_more, color: widget.accentColor, size: 16),
                items: kExchanges.map((e) {
                  return DropdownMenuItem(
                    value: e.nombre,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.network(
                              e.faviconUrl,
                              width: 18, height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                radius: 9,
                                backgroundColor: widget.accentColor.withOpacity(0.2),
                                child: Text(e.initials,
                                    style: TextStyle(fontSize: 7, color: widget.accentColor,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(e.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => _guardar(v!),
              ),
            ),
          ),

          // Botón "Ir al exchange"
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse(info.url);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            icon: Icon(Icons.open_in_new, size: 14, color: widget.accentColor),
            label: Text('Ir', style: TextStyle(color: widget.accentColor, fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
