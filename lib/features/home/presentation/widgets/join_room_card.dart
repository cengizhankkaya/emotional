import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

/// Card widget for joining an existing room
class JoinRoomCard extends StatelessWidget {
  final TextEditingController roomIdController;
  final VoidCallback onJoinRoom;

  const JoinRoomCard({
    super.key,
    required this.roomIdController,
    required this.onJoinRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColorsCustom.darkABlue,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: ProjectRadius.medium(),
        side: const BorderSide(color: ColorsCustom.white10),
      ),
      child: Padding(
        padding: const ProjectPadding.allLarge(),
        child: Column(
          children: [
            Text(
              'Odaya Katıl',
              style: TextStyle(
                fontSize: context.dynamicValue(18),
                fontWeight: FontWeight.bold,
                color: ColorsCustom.white,
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            TextField(
              controller: roomIdController,
              style: const TextStyle(color: ColorsCustom.white),
              decoration: InputDecoration(
                labelText: 'Oda ID',
                labelStyle: const TextStyle(color: ColorsCustom.skyBlue),
                hintText: '6 haneli Oda ID girin',
                hintStyle: const TextStyle(color: ColorsCustom.skyBlue),
                prefixIcon: const Icon(
                  Icons.numbers,
                  color: ColorsCustom.skyBlue,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: ProjectRadius.medium(),
                  borderSide: const BorderSide(color: ColorsCustom.skyBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: ProjectRadius.medium(),
                  borderSide: const BorderSide(color: ColorsCustom.skyBlue),
                ),
                border: OutlineInputBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: context.dynamicHeight(0.025)),
            SizedBox(
              width: double.infinity,
              height: context.dynamicValue(50),
              child: OutlinedButton(
                onPressed: onJoinRoom,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorsCustom.skyBlue,
                  side: const BorderSide(color: ColorsCustom.skyBlue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                ),
                child: const Text('ODAYA KATIL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
