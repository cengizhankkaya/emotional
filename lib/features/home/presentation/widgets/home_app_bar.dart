import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/auth/presentation/widgets/logout_dialog.dart';
import 'package:emotional/features/home/presentation/widgets/profile_dialog.dart';
import 'package:emotional/features/home/presentation/widgets/settings_dialog.dart';
import 'package:emotional/product/generated/assets.gen.dart';
import 'package:emotional/product/utility/constants/app_icons.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom AppBar for the Home Screen
import 'package:emotional/product/widget/network_status_header.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leadingWidth: 100,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          IconButton(
            icon: Transform.rotate(
              angle: 3.14159, // 180 degrees in radians (pi)
              child: const Icon(
                Icons.exit_to_app_outlined,
                color: ColorsCustom.darkGray,
              ),
            ),
            onPressed: () async {
              final confirm = await LogoutDialog.show(context);
              if (confirm == true && context.mounted) {
                context.read<AuthBloc>().add(LogoutRequested());
              }
            },
          ),
          const Center(child: NetworkStatusHeader(isIconOnly: true)),
        ],
      ),
      title: Text(
        'Emoti',
        style: GoogleFonts.righteous(
          color: ColorsCustom.skyBlue.withAlpha(255),
          fontWeight: FontWeight.w400,
          fontSize: context.dynamicValue(22),
          letterSpacing: 1.2,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => SettingsDialog.show(context),
          icon: const Icon(AppIcons.settings, color: ColorsCustom.darkGray),
        ),
        InkResponse(
          onTap: () {
            ProfileDialog.show(context);
          },
          highlightColor: Colors.transparent,
          radius: 24,
          child: Padding(
            padding: const ProjectPadding.allSmall(),
            child: ClipOval(
              child: Assets.logo.logo.image(
                fit: BoxFit.cover,
                width: 38,
                height: 38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
