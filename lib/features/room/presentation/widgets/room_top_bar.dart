import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
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
          _buildRoomIdDisplay(context),
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

  Widget _buildInviteButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        Share.share(
          'Emoti odama katıl!\n\nOda Kimliği: $roomId\n\nHızlı Katılma Linki: https://emotional-app-b42af.web.app/join/$roomId\n\nLinki tıklayarak direkt odaya katılabilirsin.',
          subject: 'Emoti Oda Daveti',
        );
      },
      icon: Icon(
        Icons.share,
        color: Colors.white,
        size: context.dynamicValue(24),
      ),
      tooltip: 'Davet Et',
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
      ),
    );
  }

  Widget _buildLeaveButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
        context.read<RoomBloc>().add(
          LeaveRoomRequested(roomId: roomId, userId: user.uid),
        );
      },
      icon: Icon(
        Icons.no_meeting_room,
        color: Colors.redAccent,
        size: context.dynamicValue(24),
      ),
      tooltip: 'Odadan Çık',
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
      ),
    );
  }

  Widget _buildRoomIdDisplay(BuildContext context) {
    return Container(
      padding: const ProjectPadding.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: ProjectRadius.large(),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            'Oda ID: $roomId',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.dynamicValue(20),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(BuildContext context) {
    return IconButton(
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
      icon: Icon(
        Icons.chair,
        color: Colors.white,
        size: context.dynamicValue(24),
      ),
      tooltip: 'Koltuk Teması',
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
      ),
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        scaffoldKey.currentState?.openEndDrawer();
      },
      icon: Icon(
        Icons.chat_bubble_outline,
        color: Colors.white,
        size: context.dynamicValue(24),
      ),
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: ProjectRadius.medium()),
      ),
    );
  }
}
