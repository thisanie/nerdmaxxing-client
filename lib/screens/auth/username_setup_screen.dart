import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool? _available;
  bool _checking = false;
  bool _submitting = false;
  String? _error;

  static final _pattern = RegExp(r'^[A-Za-z0-9_]{3,24}$');

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _error = null;
    });
    if (!_pattern.hasMatch(value)) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _check(value));
  }

  Future<void> _check(String value) async {
    setState(() => _checking = true);
    try {
      final authService = context.read<AuthService>();
      final available = await authService.checkUsernameAvailability(value);
      if (!mounted) return;
      setState(() => _available = available);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (!_pattern.hasMatch(value)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final authService = context.read<AuthService>();
      final username = await authService.setUsername(value);
      if (!mounted) return;
      context.read<AuthProvider>().onUsernameSet(username);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final validFormat = _pattern.hasMatch(value);
    final canSubmit = validFormat && _available == true && !_submitting;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Pick a username', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'This is how other curious people will find you.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ada_lovelace',
                  suffixIcon: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _available == true
                          ? const Icon(Icons.check_circle, color: AppColors.success)
                          : (_available == false ? const Icon(Icons.cancel, color: AppColors.danger) : null),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '3-24 characters: letters, numbers, underscores.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (_available == false) ...[
                const SizedBox(height: 8),
                const Text('That username is taken.', style: TextStyle(color: AppColors.danger)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
