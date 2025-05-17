import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiUrl {
    // FORCE LOCAL BACKEND FOR ALL BUILDS
    return 'http://localhost:8000';
  }
} 