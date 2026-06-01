import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/shell.dart';
import 'shared/widgets/hex_badge.dart';

class ColmeiaSmartApp extends ConsumerWidget {
  const ColmeiaSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Colmeia Smart',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: authState.maybeWhen(
        loading: () => const _Splash(),
        orElse:  () => authState.valueOrNull != null
            ? const AppShell()
            : const LoginPage(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HexBadge(size: 64),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppTheme.honey),
          ],
        ),
      ),
    );
  }
}
