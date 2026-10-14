import 'package:emotional/product/utility/responsiveness/web_layout.dart';
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
            child: WebLayout.isWide(context)
                ? _buildWideLayout(context)
                : Center(
                    child: SingleChildScrollView(
                      padding: const ProjectPadding.allXLarge(),
                      child: WebContentWidth(
                        maxWidth: 480,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ..._buildBranding(context),
                            SizedBox(height: context.dynamicHeight(0.08)),
                            ..._buildAuthControls(context),
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

  /// Wide browser windows: brand and features on the left, sign-in card on
  /// the right. Both sit in one centred band so they stay together on large
  /// monitors instead of drifting to opposite edges.
  Widget _buildWideLayout(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorsCustom.skyBlue.withValues(alpha: 0.16),
            ColorsCustom.darkBlue,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                Expanded(child: _buildWideBranding()),
                const SizedBox(width: 48),
                SizedBox(
                  width: WebLayout.fluidWidth(
                    context,
                    fraction: 0.36,
                    min: 380,
                    max: 460,
                  ),
                  child: _buildSignInCard(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideBranding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Assets.logo.logo.image(
            height: 160,
            width: 160,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          LocaleKeys.app_name.tr(),
          style: GoogleFonts.righteous(
            color: ColorsCustom.skyBlue,
            fontSize: 56,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.auth_login_subtitle.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 22),
        ),
        const SizedBox(height: 40),
        _WebFeature(
          icon: Icons.live_tv_outlined,
          title: LocaleKeys.web_featureWatchTitle.tr(),
          description: LocaleKeys.web_featureWatchDesc.tr(),
        ),
        _WebFeature(
          icon: Icons.videocam_outlined,
          title: LocaleKeys.web_featureCallTitle.tr(),
          description: LocaleKeys.web_featureCallDesc.tr(),
        ),
        _WebFeature(
          icon: Icons.screen_share_outlined,
          title: LocaleKeys.web_featureShareTitle.tr(),
          description: LocaleKeys.web_featureShareDesc.tr(),
        ),
      ],
    );
  }

  Widget _buildSignInCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: ColorsCustom.darkABlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColorsCustom.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.web_loginTitle.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.web_loginSubtitle.tr(),
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
          const SizedBox(height: 32),
          ..._buildAuthControls(context),
        ],
      ),
    );
  }

  List<Widget> _buildBranding(BuildContext context) {
    return [
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
    ];
  }

  List<Widget> _buildAuthControls(BuildContext context) {
    return [
      BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isFirebaseLoading = state is AuthLoading;
          final buttonsDisabled =
              isFirebaseLoading || _appleAuthorizing || !_eulaAccepted;

          return Column(
            children: [
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                SizedBox(
                  width: double.infinity,
                  height: context.dynamicValue(50),
                  child: ElevatedButton(
                    key: const ValueKey('apple_sign_in_button'),
                    onPressed: buttonsDisabled ? null : _onAppleSignInPressed,
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
                          context.read<AuthBloc>().add(GoogleLoginRequested());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorsCustom.cream,
                    foregroundColor: ColorsCustom.darkBlue,
                    // Visible but muted until the EULA is accepted.
                    disabledBackgroundColor: ColorsCustom.cream.withValues(
                      alpha: 0.25,
                    ),
                    disabledForegroundColor: ColorsCustom.cream.withValues(
                      alpha: 0.7,
                    ),
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
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.login, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              LocaleKeys.auth_login_googleButton.tr(),
                              style: TextStyle(
                                fontSize: context.dynamicValue(16),
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
                    TextSpan(text: LocaleKeys.moderation_eula_checkbox.tr()),
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
            TextSpan(text: LocaleKeys.auth_login_privacyStarted.tr()),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _launchUrl(LegalUrls.termsOfService),
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
                onTap: () => _launchUrl(LegalUrls.privacyPolicy),
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
            TextSpan(text: LocaleKeys.auth_login_privacyEnded.tr()),
          ],
        ),
      ),
    ];
  }
}

class _WebFeature extends StatelessWidget {
  const _WebFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorsCustom.skyBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ColorsCustom.skyBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
