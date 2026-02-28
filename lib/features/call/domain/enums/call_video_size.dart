import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';

enum CallVideoSize { small, medium, large }

extension CallVideoSizeExtension on CallVideoSize {
  double get width {
    switch (this) {
      case CallVideoSize.small:
        return 80;
      case CallVideoSize.medium:
        return 160;
      case CallVideoSize.large:
        return 240;
    }
  }

  double get height {
    switch (this) {
      case CallVideoSize.small:
        return 45;
      case CallVideoSize.medium:
        return 90;
      case CallVideoSize.large:
        return 135;
    }
  }

  String get displayName {
    switch (this) {
      case CallVideoSize.small:
        return LocaleKeys.call_videoSize_small.tr();
      case CallVideoSize.medium:
        return LocaleKeys.call_videoSize_medium.tr();
      case CallVideoSize.large:
        return LocaleKeys.call_videoSize_large.tr();
    }
  }
}
