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
        return {'minWidth': '480', 'minHeight': '360', 'minFrameRate': '15'};
      case CallQualityPreset.balanced:
        return {'minWidth': '640', 'minHeight': '480', 'minFrameRate': '24'};
      case CallQualityPreset.high:
        return {'minWidth': '1280', 'minHeight': '720', 'minFrameRate': '30'};
      case CallQualityPreset.ultra:
        return {'minWidth': '1920', 'minHeight': '1080', 'minFrameRate': '30'};
    }
  }

  String get displayName {
    switch (this) {
      case CallQualityPreset.low:
        return 'Veri Tasarrufu (360p)';
      case CallQualityPreset.balanced:
        return 'Dengeli (480p)';
      case CallQualityPreset.high:
        return 'Yüksek Kalite (720p)';
      case CallQualityPreset.ultra:
        return 'Ultra Kalite (1080p)';
    }
  }
}
