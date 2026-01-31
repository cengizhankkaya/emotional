import 'package:emotional/product/utility/decorations/colors_custom.dart';
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColorsCustom.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Odaya Katıl',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorsCustom.white,
              ),
            ),
            const SizedBox(height: 16),
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ColorsCustom.skyBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ColorsCustom.skyBlue),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onJoinRoom,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorsCustom.skyBlue,
                  side: const BorderSide(color: ColorsCustom.skyBlue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
