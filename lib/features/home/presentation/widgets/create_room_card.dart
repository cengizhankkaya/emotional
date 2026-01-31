import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';

/// Card widget for creating a new room
class CreateRoomCard extends StatelessWidget {
  final VoidCallback onCreateRoom;

  const CreateRoomCard({super.key, required this.onCreateRoom});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2229),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Yeni Oda Oluştur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yeni bir oturum başlat ve arkadaşlarını davet et.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onCreateRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsCustom.cream,
                  foregroundColor: ColorsCustom.backgrounddark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ODA OLUŞTUR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
