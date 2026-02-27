import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class PermissionSheet extends StatelessWidget {
  final VoidCallback onGrant;

  const PermissionSheet({super.key, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const ProjectPadding.allLarge(),
      decoration: BoxDecoration(
        color: ColorsCustom.darkBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(context.dynamicValue(24)),
          topRight: Radius.circular(context.dynamicValue(24)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'İzinler Gerekli',
              style: TextStyle(
                fontSize: context.dynamicValue(22),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.dynamicHeight(0.01)),
            Text(
              'Uygulamanın tam performansı için aşağıdaki izinlere ihtiyacı var:',
              style: TextStyle(
                fontSize: context.dynamicValue(14),
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.dynamicHeight(0.04)),
            _buildPermissionItem(
              context,
              icon: Icons.video_call_rounded,
              title: 'Kamera ve Mikrofon',
              subtitle: 'Görüntülü ve sesli sohbet odaları için',
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.photo_library_rounded,
              title: 'Galeri ve Medya',
              subtitle: 'Videoları seçip arkadaşlarınızla izleyebilmek için',
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.notifications_active_rounded,
              title: 'Bildirimler',
              subtitle: 'İndirme durumunu takip edebilmeniz için',
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            _buildPermissionItem(
              context,
              icon: Icons.storage_rounded,
              title: 'Depolama',
              subtitle:
                  'Videoları cihazınıza kaydedebilmek için (Eski Cihazlar)',
            ),
            SizedBox(height: context.dynamicHeight(0.03)),
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ColorsCustom.darkBlue,
                padding: const ProjectPadding.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: ProjectRadius.medium(),
                ),
                elevation: 0,
              ),
              child: Text(
                'İzinleri Ver',
                style: TextStyle(
                  fontSize: context.dynamicValue(16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
          ],
        ),
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
          padding: const ProjectPadding.allMedium(),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: ProjectRadius.medium(),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: context.dynamicValue(24),
          ),
        ),
        SizedBox(width: context.dynamicWidth(0.04)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: context.dynamicValue(16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: context.dynamicHeight(0.005)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: context.dynamicValue(13),
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
