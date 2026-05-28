import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.bark30,
        letterSpacing: 1.2,
      ),
    );
  }
}
