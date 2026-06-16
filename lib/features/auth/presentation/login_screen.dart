import 'package:emotional/core/manager/cache_manager.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/product/utility/constants/legal_urls.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/generated/assets.gen.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Apple sheet acikken Bloc rebuild ile butonun devre disi kalmasini onler.
  bool _appleAuthorizing = false;

  /// EULA kabul durumu — true olana kadar giriş butonları devre dışıdır.
  bool _eulaAccepted = false;
  final _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _loadEulaState();
  }

  Future<void> _loadEulaState() async {
    final accepted = await _cacheManager.hasAcceptedEula();
    if (mounted && accepted) {
      setState(() => _eulaAccepted = true);
    }
  }

  void _onEulaChanged(bool? value) {
    setState(() => _eulaAccepted = value ?? false);
    _cacheManager.setEulaAccepted(_eulaAccepted);
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _onAppleSignInPressed() {
    if (_appleAuthorizing) return;
    setState(() => _appleAuthorizing = true);
    context.read<AuthBloc>().add(AppleLoginRequested());
  }

  void _clearAppleAuthorizing() {
    if (_appleAuthorizing) {
      setState(() => _appleAuthorizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated ||
            state is AuthFailure ||
            state is AuthUnauthenticated) {
          _clearAppleAuthorizing();
        }
      },
      child: Scaffold(
        body: Container(
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
                      LocaleKeys.app_name.tr(),
                      style: GoogleFonts.righteous(
                        color: ColorsCustom.skyBlue.withAlpha(255),
                        fontWeight: FontWeight.w400,
                        fontSize: context.dynamicValue(42),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LocaleKeys.auth_login_subtitle.tr(),
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
                        final isFirebaseLoading = state is AuthLoading;
                        final buttonsDisabled =
                            isFirebaseLoading || _appleAuthorizing || !_eulaAccepted;

                        return Column(
                          children: [
                            if (!kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.iOS) ...[
                              SizedBox(
                                width: double.infinity,
                                height: context.dynamicValue(50),
                                child: ElevatedButton(
                                  key: const ValueKey('apple_sign_in_button'),
                                  onPressed: buttonsDisabled
                                      ? null
                                      : _onAppleSignInPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: ProjectRadius.medium(),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.apple, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        LocaleKeys.auth_login_appleButton.tr(),
                                        style: TextStyle(
                                          fontSize: context.dynamicValue(16),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: context.dynamicValue(56),
                              child: ElevatedButton(
                                onPressed: buttonsDisabled
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
                                child: isFirebaseLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                ColorsCustom.softGray,
                                              ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/google_logo.png',
                                            height: 24,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const Icon(
                                                  Icons.login,
                                                  size: 24,
                                                ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            LocaleKeys.auth_login_googleButton
                                                .tr(),
                                            style: TextStyle(
                                              fontSize: context.dynamicValue(
                                                16,
                                              ),
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // ── EULA Checkbox ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _eulaAccepted,
                            onChanged: _onEulaChanged,
                            activeColor: ColorsCustom.skyBlue,
                            checkColor: ColorsCustom.darkBlue,
                            side: BorderSide(
                              color: ColorsCustom.skyBlue.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onEulaChanged(!_eulaAccepted),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: context.dynamicValue(12),
                                ),
                                children: [
                                  TextSpan(
                                    text: LocaleKeys.moderation_eula_checkbox.tr(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: context.dynamicValue(12),
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: LocaleKeys.auth_login_privacyStarted.tr(),
                          ),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () =>
                                  _launchUrl(LegalUrls.termsOfService),
                              child: Text(
                                LocaleKeys.auth_login_terms.tr(),
                                style: TextStyle(
                                  color: ColorsCustom.skyBlue,
                                  fontSize: context.dynamicValue(12),
                                  decoration: TextDecoration.underline,
                                  decorationColor: ColorsCustom.skyBlue,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(text: LocaleKeys.auth_login_and.tr()),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () =>
                                  _launchUrl(LegalUrls.privacyPolicy),
                              child: Text(
                                LocaleKeys.auth_login_privacyPolicy.tr(),
                                style: TextStyle(
                                  color: ColorsCustom.skyBlue,
                                  fontSize: context.dynamicValue(12),
                                  decoration: TextDecoration.underline,
                                  decorationColor: ColorsCustom.skyBlue,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: LocaleKeys.auth_login_privacyEnded.tr(),
                          ),
                        ],
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
