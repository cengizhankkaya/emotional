import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/moderation/bloc/moderation_bloc.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A confirmation dialog shown before blocking a user.
class BlockConfirmDialog extends StatelessWidget {
  final String currentUserId;
  final String blockedUserId;
  final String blockedUserName;
  final String roomId;

  const BlockConfirmDialog({
    super.key,
    required this.currentUserId,
    required this.blockedUserId,
    required this.blockedUserName,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ColorsCustom.darkABlue,
      shape: RoundedRectangleBorder(borderRadius: ProjectRadius.xlarge()),
      title: Row(
        children: [
          const Icon(Icons.block, color: Colors.redAccent, size: 22),
          const SizedBox(width: 8),
          Text(
            LocaleKeys.moderation_block_title.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Text(
        LocaleKeys.moderation_block_confirm.tr(args: [blockedUserName]),
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            LocaleKeys.button_cancel.tr(),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            context.read<ModerationBloc>().add(BlockUserRequested(
                  userId: currentUserId,
                  blockedUserId: blockedUserId,
                  blockedUserName: blockedUserName,
                  roomId: roomId,
                ));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  LocaleKeys.moderation_block_success
                      .tr(args: [blockedUserName]),
                ),
                backgroundColor: ColorsCustom.darkABlue,
              ),
            );
          },
          icon: const Icon(Icons.block, size: 16),
          label: Text(LocaleKeys.moderation_block_title.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: ProjectRadius.medium(),
            ),
          ),
        ),
      ],
    );
  }
}
