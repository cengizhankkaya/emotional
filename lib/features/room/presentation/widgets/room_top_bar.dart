import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import 'package:emotional/product/widget/network_status_header.dart';

class RoomTopBar extends StatelessWidget {
  final String roomId;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onLeave;

  const RoomTopBar({
    super.key,
    required this.roomId,
    required this.scaffoldKey,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const ProjectPadding.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLeaveButton(context),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: _buildRoomIdDisplay(context),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NetworkStatusHeader(isIconOnly: true),
              const SizedBox(width: 8),
              _buildInviteButton(context),
              SizedBox(width: context.dynamicWidth(0.02)),
              _buildThemeButton(context),
              SizedBox(width: context.dynamicWidth(0.02)),
              _buildChatButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
    Color? iconColor,
    required BuildContext context,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: context.dynamicValue(45),
          height: context.dynamicValue(45),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: context.dynamicValue(24),
            ),
            tooltip: tooltip,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        Share.share(
          LocaleKeys.room_inviteMessage.tr(args: [roomId, roomId]),
          subject: LocaleKeys.room_inviteTitle.tr(),
        );
      },
      icon: Icons.share,
      tooltip: LocaleKeys.room_tooltips_invite.tr(),
    );
  }

  Widget _buildLeaveButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        // Tercihen üst seviyeden gelen temizlik callback'ini çağır.
        if (onLeave != null) {
          onLeave!();
        } else {
          // Geriye hiçbir şey verilmediyse, sadece sayfadan çık.
          Navigator.of(context).pop();
        }
      },
      icon: Icons.no_meeting_room,
      iconColor: Colors.redAccent,
      tooltip: LocaleKeys.room_tooltips_leave.tr(),
    );
  }

  Widget _buildRoomIdDisplay(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SelectableText(
          LocaleKeys.room_id.tr(args: [roomId]),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            // Daha küçük font ile dar ekranlarda da taşma olmadan göster.
            fontSize: context.dynamicValue(20),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            shadows: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (c) {
            return BlocProvider.value(
              value: context.read<RoomDecorationCubit>(),
              child: const ArmchairSelectorSheet(),
            );
          },
        );
      },
      icon: Icons.chair,
      tooltip: LocaleKeys.room_tooltips_theme.tr(),
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        scaffoldKey.currentState?.openEndDrawer();
      },
      icon: Icons.chat_bubble_outline,
      tooltip: LocaleKeys.room_tooltips_chat.tr(),
    );
  }
}
