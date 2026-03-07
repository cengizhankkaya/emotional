import 'package:emotional/product/init/config/app_configuration.dart';
import 'package:flutter/foundation.dart';

@immutable
final class AppEnviroment {
  const AppEnviroment._();

  static late final AppConfiguration config;

  static void setup({required AppConfiguration config}) {
    AppEnviroment.config = config;
  }
}
