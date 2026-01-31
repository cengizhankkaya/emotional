import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';

/// A divider widget with text in the middle
class RoomDivider extends StatelessWidget {
  final String text;

  const RoomDivider({super.key, this.text = 'VEYA'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: ColorsCustom.darkGray)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(text, style: const TextStyle(color: ColorsCustom.cream)),
        ),
        const Expanded(child: Divider(color: ColorsCustom.darkGray)),
      ],
    );
  }
}
