import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginRequested(_emailController.text.trim(), _passwordController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            size: context.dynamicValue(80),
            color: Colors.white.withValues(alpha: 0.9),
          ),
          SizedBox(height: context.dynamicHeight(0.02)),
          Text(
            "Tekrar Hoşgeldiniz",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: context.dynamicValue(28),
            ),
          ),
          SizedBox(height: context.dynamicHeight(0.01)),
          Text(
            "Devam etmek için giriş yapın",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontSize: context.dynamicValue(14),
            ),
          ),
          SizedBox(height: context.dynamicHeight(0.04)),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'E-posta',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'E-postanızı girin',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Colors.white70,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: const BorderSide(
                  color: Colors.pinkAccent,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen e-postanızı girin';
              }
              if (!value.contains('@')) {
                return 'Geçerli bir e-posta girin';
              }
              return null;
            },
          ),
          SizedBox(height: context.dynamicHeight(0.02)),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Şifre',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Şifrenizi girin',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ProjectRadius.medium(),
                borderSide: const BorderSide(
                  color: Colors.pinkAccent,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen şifrenizi girin';
              }
              if (value.length < 6) {
                return 'Şifre en az 6 karakter olmalı';
              }
              return null;
            },
          ),
          SizedBox(height: context.dynamicHeight(0.04)),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: context.dynamicValue(50),
                child: ElevatedButton(
                  onPressed: state is AuthLoading ? null : _onLoginPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: ProjectRadius.medium(),
                    ),
                    elevation: 5,
                  ),
                  child: state is AuthLoading
                      ? SizedBox(
                          height: context.dynamicValue(24),
                          width: context.dynamicValue(24),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'GİRİŞ YAP',
                          style: TextStyle(
                            fontSize: context.dynamicValue(16),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              );
            },
          ),
          SizedBox(height: context.dynamicHeight(0.02)),
          OutlinedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(GoogleLoginRequested());
            },
            icon: Image.asset(
              'assets/google_logo.png',
              height: context.dynamicValue(24),
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.login, color: Colors.white),
            ),
            label: Text(
              "Google ile Giriş Yap",
              style: TextStyle(
                color: Colors.white,
                fontSize: context.dynamicValue(16),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const ProjectPadding.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: ProjectRadius.medium(),
              ),
            ),
          ),
          SizedBox(height: context.dynamicHeight(0.01)),
          TextButton(
            onPressed: () {
              context.read<AuthBloc>().add(AnonymousLoginRequested());
            },
            child: Text(
              "Misafir Olarak Devam Et",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: context.dynamicValue(16),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
