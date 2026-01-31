import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_widget.dart';
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
          const Text(
            'Koltuk Teması Seçin',
            style: TextStyle(
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

                // Check participants count for Love theme
                final roomState = context.read<RoomBloc>().state;
                final participants = roomState is RoomJoined
                    ? roomState.participants
                    : <String>[];
                final bool isLoveTheme = style == ArmchairStyle.love;
                final bool isEnabled = !isLoveTheme || participants.length <= 2;

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
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(
                                color: Colors.deepPurpleAccent,
                                width: 2,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Transform.scale(
                              scale: 0.6,
                              child: ArmchairWidget(
                                participant: null,
                                isLeft: false,
                                style: style,
                                child: const SizedBox(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getStyleName(style),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
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
        return 'Modern';
      case ArmchairStyle.cozy:
        return 'Sıcak';
      case ArmchairStyle.vintage:
        return 'Retro';
      case ArmchairStyle.clay:
        return 'Pastel';
      case ArmchairStyle.love:
        return 'Aşk';
    }
  }
}
