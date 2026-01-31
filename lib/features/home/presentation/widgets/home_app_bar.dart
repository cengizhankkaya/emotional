import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/product/generated/assets.gen.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom AppBar for the Home Screen
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: IconButton(
        icon: Transform.rotate(
          angle: 3.14159, // 180 degrees in radians (pi)
          child: const Icon(
            Icons.exit_to_app_outlined,
            color: ColorsCustom.darkGray,
          ),
        ),
        onPressed: () {
          context.read<AuthBloc>().add(LogoutRequested());
        },
      ),
      title: Text(
        'Emoti',
        style: GoogleFonts.righteous(
          color: ColorsCustom.skyBlue.withAlpha(255),
          fontWeight: FontWeight.w400,
          fontSize: 22,
          letterSpacing: 1.2,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipOval(child: Assets.logo.logo.image(fit: BoxFit.cover)),
        ),
      ],
    );
  }
}
