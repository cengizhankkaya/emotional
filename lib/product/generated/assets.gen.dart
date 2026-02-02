// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsAppGen {
  const $AssetsAppGen();

  /// File path: assets/app/logo.png
  AssetGenImage get logo => const AssetGenImage('assets/app/logo.png');

  /// List of all assets
  List<AssetGenImage> get values => [logo];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// Directory path: assets/images/armchair
  $AssetsImagesArmchairGen get armchair => const $AssetsImagesArmchairGen();
}

class $AssetsLogoGen {
  const $AssetsLogoGen();

  /// File path: assets/logo/logo.png
  AssetGenImage get logo => const AssetGenImage('assets/logo/logo.png');

  /// List of all assets
  List<AssetGenImage> get values => [logo];
}

class $AssetsTranslationsGen {
  const $AssetsTranslationsGen();

  /// File path: assets/translations/en.json
  String get en => 'assets/translations/en.json';

  /// File path: assets/translations/tr.json
  String get tr => 'assets/translations/tr.json';

  /// List of all assets
  List<String> get values => [en, tr];
}

class $AssetsImagesArmchairGen {
  const $AssetsImagesArmchairGen();

  /// File path: assets/images/armchair/esce.png
  AssetGenImage get esce =>
      const AssetGenImage('assets/images/armchair/esce.png');

  /// File path: assets/images/armchair/fwhite.png
  AssetGenImage get fwhite =>
      const AssetGenImage('assets/images/armchair/fwhite.png');

  /// File path: assets/images/armchair/lacivert.png
  AssetGenImage get lacivert =>
      const AssetGenImage('assets/images/armchair/lacivert.png');

  /// File path: assets/images/armchair/mor.png
  AssetGenImage get mor =>
      const AssetGenImage('assets/images/armchair/mor.png');

  /// File path: assets/images/armchair/pembe.png
  AssetGenImage get pembe =>
      const AssetGenImage('assets/images/armchair/pembe.png');

  /// File path: assets/images/armchair/unnamed-3.png
  AssetGenImage get unnamed3 =>
      const AssetGenImage('assets/images/armchair/unnamed-3.png');

  /// File path: assets/images/armchair/unnamed-6.png
  AssetGenImage get unnamed6 =>
      const AssetGenImage('assets/images/armchair/unnamed-6.png');

  /// File path: assets/images/armchair/uzay.png
  AssetGenImage get uzay =>
      const AssetGenImage('assets/images/armchair/uzay.png');

  /// File path: assets/images/armchair/yeşil.png
  AssetGenImage get yesIl =>
      const AssetGenImage('assets/images/armchair/yeşil.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    esce,
    fwhite,
    lacivert,
    mor,
    pembe,
    unnamed3,
    unnamed6,
    uzay,
    yesIl,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsAppGen app = $AssetsAppGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsLogoGen logo = $AssetsLogoGen();
  static const $AssetsTranslationsGen translations = $AssetsTranslationsGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
