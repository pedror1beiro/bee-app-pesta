import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String statusText;
  final bool isWarning;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.statusText,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accentColor, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.bark30, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, color: accentColor, height: 1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isWarning ? AppTheme.honey : AppTheme.leaf)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusText,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isWarning ? AppTheme.honeyLt : AppTheme.leafLt,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}
