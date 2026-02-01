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
        return 'Küçük';
      case CallVideoSize.medium:
        return 'Orta';
      case CallVideoSize.large:
        return 'Büyük';
    }
  }
}
