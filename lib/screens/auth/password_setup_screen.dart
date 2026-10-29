import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class PasswordSetupScreen extends StatefulWidget {
  final bool hasPassword;
  final bool canSkip;

  const PasswordSetupScreen({
    super.key,
    this.hasPassword = false,
    this.canSkip = true,
  });

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.length < 12 || password.length > 128) {
      setState(() => _error = 'Use a password between 12 and 128 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Those passwords do not match.');
      return;
    }
    setState(() => _error = null);
    try {
      final auth = context.read<AuthProvider>();
      if (widget.hasPassword) {
        await auth.updatePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: password,
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        await auth.setupPassword(password);
        if (mounted && !widget.canSkip) Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                widget.hasPassword ? 'Update password' : 'Add a password',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.hasPassword
                    ? 'Choose a new password for your account.'
                    : 'You can use your username and password to sign in next time.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (widget.hasPassword) ...[
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: 128,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: '12-128 characters',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirmation,
                maxLength: 128,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => auth.isBusy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isBusy ? null : _submit,
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.hasPassword ? 'Update password' : 'Save password',
                        ),
                ),
              ),
              if (widget.canSkip)
                Center(
                  child: TextButton(
                    onPressed: auth.isBusy ? null : auth.skipPasswordSetup,
                    child: const Text('Skip for now'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}