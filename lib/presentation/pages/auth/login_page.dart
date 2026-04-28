import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../config/theme.dart';
import '../../blocs/auth/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final FormGroup _form;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      'email': FormControl<String>(
        validators: [Validators.required, Validators.email],
      ),
      'password': FormControl<String>(
        validators: [Validators.required, Validators.minLength(8)],
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/dashboard');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.priorityHigh,
              ));
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 40),
                      _buildForm(context, state),
                      const SizedBox(height: 24),
                      _buildSignUpLink(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          'Smart Task Planner',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your account',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  Widget _buildForm(BuildContext context, AuthState state) {
    return ReactiveForm(
      formGroup: _form,
      child: Column(
        children: [
          ReactiveTextField<String>(
            formControlName: 'email',
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validationMessages: {
              ValidationMessage.required: (_) => 'Email is required',
              ValidationMessage.email: (_) => 'Enter a valid email',
            },
          ),
          const SizedBox(height: 16),
          ReactiveTextField<String>(
            formControlName: 'password',
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(context),
            validationMessages: {
              ValidationMessage.required: (_) => 'Password is required',
              ValidationMessage.minLength: (_) =>
                  'Password must be at least 8 characters',
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPassword(context),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: state is AuthLoading ? null : () => _signIn(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: state is AuthLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign In', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context, AuthState state) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: state is AuthLoading
              ? null
              : () => context
                  .read<AuthBloc>()
                  .add(AuthSignInWithGoogle()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: const Icon(Icons.g_mobiledata, size: 24),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: state is AuthLoading
              ? null
              : () => context
                  .read<AuthBloc>()
                  .add(AuthSignInWithMicrosoft()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: const Icon(Icons.window, size: 20),
          label: const Text('Continue with Microsoft'),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?",
            style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () => context.pushNamed('register'),
          child: const Text('Sign up'),
        ),
      ],
    );
  }

  void _signIn(BuildContext context) {
    if (_form.invalid) {
      _form.markAllAsTouched();
      return;
    }
    context.read<AuthBloc>().add(AuthSignInWithEmail(
          _form.control('email').value as String,
          _form.control('password').value as String,
        ));
  }

  void _showForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
              labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              // TODO: wire to auth repo reset password
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Password reset email sent')));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
