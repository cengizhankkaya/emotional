import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/generated/assets.gen.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: ColorsCustom.imperilRead,
              ),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(color: ColorsCustom.darkBlue),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const ProjectPadding.allXLarge(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Assets.logo.logo.image(
                        height: context.dynamicValue(300),
                        width: context.dynamicValue(300),
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: context.dynamicHeight(0.05)),
                    Text(
                      'Emoti',
                      style: GoogleFonts.righteous(
                        color: ColorsCustom.skyBlue.withAlpha(255),
                        fontWeight: FontWeight.w400,
                        fontSize: context.dynamicValue(42),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Birlikte izlemenin keyfi',
                      style: TextStyle(
                        color: ColorsCustom.skyBlue.withValues(alpha: 0.9),
                        fontSize: context.dynamicValue(16),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: context.dynamicHeight(0.08)),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: context.dynamicValue(56),
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    context.read<AuthBloc>().add(
                                      GoogleLoginRequested(),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorsCustom.cream,
                              foregroundColor: ColorsCustom.darkBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: ProjectRadius.medium(),
                              ),
                              padding: const ProjectPadding.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ColorsCustom.softGray,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/google_logo.png',
                                        height: 24,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.login,
                                                  size: 24,
                                                ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Google ile Giriş Yap',
                                        style: TextStyle(
                                          fontSize: context.dynamicValue(16),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Privacy note
                    Text(
                      'Giriş yaparak Kullanım Koşullarını\nve Gizlilik Politikasını kabul etmiş olursunuz',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: context.dynamicValue(12),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
