import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';

class PermissionSheet extends StatelessWidget {
  final VoidCallback onGrant;

  const PermissionSheet({super.key, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: ColorsCustom.darkBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'İzinler Gerekli',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Uygulamanın tam performansı için aşağıdaki izinlere ihtiyacı var:',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildPermissionItem(
            context,
            icon: Icons.video_call_rounded,
            title: 'Kamera ve Mikrofon',
            subtitle: 'Görüntülü ve sesli sohbet odaları için',
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            context,
            icon: Icons.notifications_active_rounded,
            title: 'Bildirimler',
            subtitle: 'İndirme durumunu takip edebilmeniz için',
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            context,
            icon: Icons.storage_rounded,
            title: 'Depolama',
            subtitle: 'Videoları cihazınıza kaydedebilmek için (Eski Cihazlar)',
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: onGrant,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ColorsCustom.darkBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'İzinleri Ver',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
