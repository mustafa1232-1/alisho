import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppEnv {
  static const _defaultApiBaseUrl = 'https://mazarty-mazarty-170f.up.railway.app';

  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }

    if (kIsWeb) {
      return _defaultApiBaseUrl;
    }

    if (Platform.isAndroid) {
      return _defaultApiBaseUrl;
    }

    return _defaultApiBaseUrl;
  }
}
