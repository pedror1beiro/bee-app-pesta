import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HexBadge extends StatelessWidget {
  final double size;
  const HexBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(AppTheme.honey),
        child: Center(
          child: Text('🐝', style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  const _HexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (pi / 180) * (60 * i - 30);
      final x = cx + r * cos(a);
      final y = cy + r * sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}
