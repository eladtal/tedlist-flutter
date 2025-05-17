import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiUrl {
    if (kIsWeb) {
      // Web: use local backend for development
      return 'http://localhost:8000';
    } else {
      // Mobile: use production backend
      return 'https://tedlist-backend.onrender.com';
    }
  }
} 