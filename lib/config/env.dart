import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiUrl {
    if (kDebugMode) {
      if (kIsWeb) {
        // For web debug, backend is on localhost:8000
        // Ensure your backend allows CORS from where your Flutter web app is served (e.g., localhost:3000)
        return 'http://localhost:8000'; 
      } else if (Platform.isAndroid) {
        // For Android emulator, 10.0.2.2 points to the host machine's localhost (port 8000 for backend)
        return 'http://10.0.2.2:8000';
      } else if (Platform.isIOS) {
        // For iOS simulator, localhost directly works (port 8000 for backend)
        return 'http://localhost:8000';
      }
    }
    // Default to production backend for release builds or other platforms
    return 'https://tedlist-backend.onrender.com';
  }
} 