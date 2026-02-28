import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';

enum CallQualityPreset {
  low, // 360p, 15fps (Data Saver)
  balanced, // 540p, 24fps (Default)
  high, // 720p, 30fps (Wi-Fi)
  ultra, // 1080p, 30fps (High-end devices)
}

extension CallQualityExtension on CallQualityPreset {
  Map<String, dynamic> toConstraints() {
    switch (this) {
      case CallQualityPreset.low:
        return {'minWidth': 480, 'minHeight': 360, 'minFrameRate': 15};
      case CallQualityPreset.balanced:
        return {'minWidth': 640, 'minHeight': 480, 'minFrameRate': 24};
      case CallQualityPreset.high:
        return {'minWidth': 1280, 'minHeight': 720, 'minFrameRate': 30};
      case CallQualityPreset.ultra:
        return {'minWidth': 1920, 'minHeight': 1080, 'minFrameRate': 30};
    }
  }

  Map<String, dynamic> toScreenConstraints() {
    switch (this) {
      case CallQualityPreset.low:
        return {'width': 640, 'height': 360, 'frameRate': 15};
      case CallQualityPreset.balanced:
        return {'width': 960, 'height': 540, 'frameRate': 24};
      case CallQualityPreset.high:
        return {'width': 1280, 'height': 720, 'frameRate': 30};
      case CallQualityPreset.ultra:
        return {'width': 1920, 'height': 1080, 'frameRate': 60};
    }
  }

  String get displayName {
    switch (this) {
      case CallQualityPreset.low:
        return LocaleKeys.call_quality_low.tr();
      case CallQualityPreset.balanced:
        return LocaleKeys.call_quality_balanced.tr();
      case CallQualityPreset.high:
        return LocaleKeys.call_quality_high.tr();
      case CallQualityPreset.ultra:
        return LocaleKeys.call_quality_ultra.tr();
    }
  }
}
