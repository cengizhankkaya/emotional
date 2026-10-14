import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/home/presentation/widgets/create_room_card.dart';
import 'package:emotional/features/home/presentation/widgets/join_room_card.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';

/// Home screen body for wide browser windows: greeting and room actions on
/// the left, a short "how it works" guide on the right.
class WebHomeBody extends StatelessWidget {
  const WebHomeBody({
    super.key,
    required this.userName,
    required this.roomIdController,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final String userName;
  final TextEditingController roomIdController;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      LocaleKeys.home_welcome.tr(args: [userName]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LocaleKeys.web_homeSubtitle.tr(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CreateRoomCard(onCreateRoom: onCreateRoom),
                    const SizedBox(height: 16),
                    JoinRoomCard(
                      roomIdController: roomIdController,
                      onJoinRoom: onJoinRoom,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              const Expanded(flex: 4, child: _HowItWorks()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        Icons.add_circle_outline,
        LocaleKeys.web_step1Title.tr(),
        LocaleKeys.web_step1Desc.tr(),
      ),
      (
        Icons.share_outlined,
        LocaleKeys.web_step2Title.tr(),
        LocaleKeys.web_step2Desc.tr(),
      ),
      (
        Icons.live_tv_outlined,
        LocaleKeys.web_step3Title.tr(),
        LocaleKeys.web_step3Desc.tr(),
      ),
    ];

    return Container(
      // Lines the card up with the room cards, below the greeting.
      margin: const EdgeInsets.only(top: 110),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColorsCustom.darkABlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorsCustom.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.web_stepsTitle.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          for (final (index, (icon, title, description)) in steps.indexed) ...[
            if (index > 0) const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColorsCustom.skyBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ColorsCustom.skyBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. $title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
