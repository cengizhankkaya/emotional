import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';

class DriveFileErrorView extends StatelessWidget {
  final String error;

  const DriveFileErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const ProjectPadding.allLarge(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: context.dynamicValue(64),
              color: Colors.redAccent,
            ),
            SizedBox(height: context.dynamicHeight(0.02)),
            Text(
              'Bir Hata Oluştu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontSize: context.dynamicValue(24),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.01)),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.dynamicValue(14),
              ),
            ),
            if (error.contains('etkinleştirin')) ...[
              SizedBox(height: context.dynamicHeight(0.03)),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const ProjectPadding.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: ProjectRadius.medium(),
                  ),
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Konsolu Aç (Tarayıcı)'),
              ),
              SizedBox(height: context.dynamicHeight(0.02)),
              Container(
                padding: const ProjectPadding.allMedium(),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: ProjectRadius.small(),
                ),
                child: const SelectableText(
                  'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=739508543260',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
