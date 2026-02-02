import 'dart:ui';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class RoomTopBar extends StatelessWidget {
  final String roomId;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const RoomTopBar({
    super.key,
    required this.roomId,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const ProjectPadding.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildLeaveButton(context),
          const Spacer(),
          Expanded(flex: 6, child: _buildRoomIdDisplay(context)),
          const Spacer(),
          _buildInviteButton(context),
          SizedBox(width: context.dynamicWidth(0.02)),
          _buildThemeButton(context),
          SizedBox(width: context.dynamicWidth(0.02)),
          _buildChatButton(context),
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
          'Emoti odama katıl!\n\nOda Kimliği: $roomId\n\nHızlı Katılma Linki: https://emotional-app-b42af.web.app/join/$roomId\n\nLinki tıklayarak direkt odaya katılabilirsin.',
          subject: 'Emoti Oda Daveti',
        );
      },
      icon: Icons.share,
      tooltip: 'Davet Et',
    );
  }

  Widget _buildLeaveButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
        context.read<RoomBloc>().add(
          LeaveRoomRequested(roomId: roomId, userId: user.uid),
        );
      },
      icon: Icons.no_meeting_room,
      iconColor: Colors.redAccent,
      tooltip: 'Odadan Çık',
    );
  }

  Widget _buildRoomIdDisplay(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SelectableText(
          'Oda ID: $roomId',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9), // Slightly softer white
            fontSize: context.dynamicValue(28),
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
      tooltip: 'Koltuk Teması',
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return _buildGlassButton(
      context: context,
      onPressed: () {
        scaffoldKey.currentState?.openEndDrawer();
      },
      icon: Icons.chat_bubble_outline,
      tooltip: 'Sohbet',
    );
  }
}
