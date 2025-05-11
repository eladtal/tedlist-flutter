import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      // Use production backend for all mobile platforms
      return 'https://tedlist-backend.onrender.com';
    }
  }
} 