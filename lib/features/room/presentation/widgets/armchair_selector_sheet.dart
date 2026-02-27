import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/furniture_theme_data.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArmchairSelectorSheet extends StatelessWidget {
  const ArmchairSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2229),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.room_armchairTheme.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ArmchairStyle.values.length,
              itemBuilder: (context, index) {
                final style = ArmchairStyle.values[index];
                final isSelected =
                    context.watch<RoomDecorationCubit>().state.armchairStyle ==
                    style;

                // Check participants count for restricted themes (Love & Esce)
                final roomState = context.read<RoomBloc>().state;
                final participants = roomState is RoomJoined
                    ? roomState.participants
                    : <String>[];
                final bool isRestrictedTheme =
                    style == ArmchairStyle.love || style == ArmchairStyle.esce;
                final bool isEnabled =
                    !isRestrictedTheme || participants.length <= 2;

                final theme = FurnitureThemeData.getTheme(style);

                return GestureDetector(
                  onTap: isEnabled
                      ? () {
                          context.read<RoomDecorationCubit>().setArmchairStyle(
                            style,
                          );
                        }
                      : null,
                  child: Opacity(
                    opacity: isEnabled ? 1.0 : 0.5,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2F37),
                        border: isSelected
                            ? Border.all(
                                color: Colors.deepPurpleAccent,
                                width: 2,
                              )
                            : Border.all(color: Colors.white10, width: 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            // Theme Image
                            Positioned.fill(
                              child: theme.image != null
                                  ? theme.image!.image(fit: BoxFit.cover)
                                  : Container(
                                      color: theme.baseColor,
                                      child: const Icon(
                                        Icons.chair,
                                        color: Colors.white24,
                                      ),
                                    ),
                            ),
                            // Selection Overlay (optional highlight)
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.deepPurpleAccent.withOpacity(
                                    0.1,
                                  ),
                                ),
                              ),
                            // Info Bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  _getStyleName(style),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStyleName(ArmchairStyle style) {
    switch (style) {
      case ArmchairStyle.modern:
        return LocaleKeys.room_armchairStyleModern.tr();
      case ArmchairStyle.vintage:
        return LocaleKeys.room_armchairStyleRetro.tr();
      case ArmchairStyle.clay:
        return LocaleKeys.room_armchairStyleClay.tr();
      case ArmchairStyle.love:
        return LocaleKeys.room_armchairStyleLove.tr();
      case ArmchairStyle.fwhite:
        return LocaleKeys.room_armchairStyleWhite.tr();
      case ArmchairStyle.esce:
        return LocaleKeys.room_armchairStyleAntrasit.tr();
      case ArmchairStyle.lacivert:
        return LocaleKeys.room_armchairStyleNavy.tr();
      case ArmchairStyle.mor:
        return LocaleKeys.room_armchairStylePurple.tr();
      case ArmchairStyle.yesIl:
        return LocaleKeys.room_armchairStyleGreen.tr();
    }
  }
}
