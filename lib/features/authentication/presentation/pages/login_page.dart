import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reception_workforce_scheduler/core/l10n/error_localizer.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/core/utils/validators.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loginToContinue,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return l10n.emailRequired;
                          if (!Validators.isValidEmail(value)) return l10n.invalidEmail;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) return l10n.passwordRequired;
                          if (value.length < 6) return l10n.passwordTooShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      authState.when(
                        loading: () => const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => Column(
                          children: [
                            Text(
                              localizeErrorText(
                                  context,
                                  error
                                      .toString()
                                      .replaceFirst('AppException: ', '')
                                      .replaceFirst('Exception: ', '')),
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _attemptSignIn,
                                child: Text(l10n.tryAgain),
                              ),
                            ),
                          ],
                        ),
                        data: (user) {
                          if (user != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              // Navigate based on role
                              if (user.role.toString().contains('admin')) {
                                context.go('/admin');
                              } else {
                                context.go('/employee');
                              }
                            });
                          }
                          return SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: () {
                                _attemptSignIn();
                              },
                              child: Text(l10n.signIn),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _attemptSignIn() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authViewModelProvider.notifier).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }
}