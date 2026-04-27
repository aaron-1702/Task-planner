import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../config/theme.dart';
import '../../blocs/auth/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final FormGroup _form;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _form = FormGroup(
      {
        'displayName': FormControl<String>(
          validators: [Validators.required, Validators.minLength(2)],
        ),
        'email': FormControl<String>(
          validators: [Validators.required, Validators.email],
        ),
        'password': FormControl<String>(
          validators: [Validators.required, Validators.minLength(8)],
        ),
        'confirmPassword': FormControl<String>(
          validators: [Validators.required],
        ),
      },
      validators: [
        Validators.mustMatch('password', 'confirmPassword'),
      ],
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) context.go('/dashboard');
          if (state is AuthError) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.priorityHigh,
              ));
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ReactiveForm(
                  formGroup: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReactiveTextField<String>(
                        formControlName: 'displayName',
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                        validationMessages: {
                          ValidationMessage.required: (_) => 'Name is required',
                          ValidationMessage.minLength: (_) =>
                              'Name must be at least 2 characters',
                        },
                      ),
                      const SizedBox(height: 16),
                      ReactiveTextField<String>(
                        formControlName: 'email',
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Email is required',
                          ValidationMessage.email: (_) =>
                              'Enter a valid email',
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
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Password is required',
                          ValidationMessage.minLength: (_) =>
                              'Minimum 8 characters',
                        },
                      ),
                      const SizedBox(height: 16),
                      ReactiveTextField<String>(
                        formControlName: 'confirmPassword',
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _register(context),
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Please confirm your password',
                          ValidationMessage.mustMatch: (_) =>
                              'Passwords do not match',
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state is AuthLoading
                            ? null
                            : () => _register(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: state is AuthLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Account',
                                style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?'),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
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

  void _register(BuildContext context) {
    if (_form.invalid) {
      _form.markAllAsTouched();
      return;
    }
    context.read<AuthBloc>().add(AuthSignUpRequested(
          _form.control('email').value as String,
          _form.control('password').value as String,
          _form.control('displayName').value as String,
        ));
  }
}
