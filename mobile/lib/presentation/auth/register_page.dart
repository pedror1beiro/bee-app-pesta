import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nomeCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'As passwords não coincidem.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(authProvider.notifier).register(
            _nomeCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
      setState(() => _success = 'Conta criada! Podes fazer login.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bark,
      appBar: AppBar(
        title: const Text('Criar conta'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.honey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  _Banner(text: _error!, isError: true),
                if (_success != null)
                  _Banner(text: _success!, isError: false),

                _Field(label: 'Nome completo', ctrl: _nomeCtrl,
                    icon: Icons.person_outline),
                const SizedBox(height: 14),
                _Field(label: 'Email', ctrl: _emailCtrl,
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _Field(label: 'Password', ctrl: _passCtrl,
                    icon: Icons.lock_outline, obscure: true),
                const SizedBox(height: 14),
                _Field(label: 'Confirmar password', ctrl: _confirmCtrl,
                    icon: Icons.lock_outline, obscure: true),
                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.bark),
                          )
                        : const Text('Criar conta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final bool isError;
  const _Banner({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.danger : AppTheme.leafLt;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _Field extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool obscure;
  final TextInputType type;
  const _Field({
    required this.label,
    required this.ctrl,
    required this.icon,
    this.obscure = false,
    this.type = TextInputType.text,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.ctrl,
      obscureText: widget.obscure && !_show,
      keyboardType: widget.type,
      style: const TextStyle(color: AppTheme.wax),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: AppTheme.bark30),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                    _show ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.bark30),
                onPressed: () => setState(() => _show = !_show),
              )
            : null,
      ),
    );
  }
}
