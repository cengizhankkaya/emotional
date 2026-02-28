import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';

/// A divider widget with text in the middle
class RoomDivider extends StatelessWidget {
  const RoomDivider({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: ColorsCustom.darkGray)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text ?? LocaleKeys.home_divider.tr(),
            style: const TextStyle(color: ColorsCustom.cream),
          ),
        ),
        const Expanded(child: Divider(color: ColorsCustom.darkGray)),
      ],
    );
  }
}
