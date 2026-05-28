import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class BleBadge extends StatelessWidget {
  final bool isConnected;
  final bool isSyncing;
  const BleBadge({super.key, required this.isConnected, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final color = isSyncing
        ? AppTheme.honeyLt
        : isConnected
            ? AppTheme.leafLt
            : AppTheme.bark30;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConnected
              ? Icons.bluetooth_connected_rounded
              : Icons.bluetooth_disabled_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          isConnected ? 'LIGADO' : 'BLE',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
