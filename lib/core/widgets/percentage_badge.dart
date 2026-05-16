import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';

class PercentageBadge extends StatelessWidget {
  final double percentage;
  final bool showIcon;
  final double fontSize;

  const PercentageBadge({
    super.key,
    required this.percentage,
    this.showIcon = true,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = percentage >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              size: fontSize,
              color: color,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            CurrencyFormatter.percentage(percentage),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
