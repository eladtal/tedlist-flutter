import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiUrl {
    // Always use production backend
    return 'https://tedlist-backend.onrender.com';
  }
} 