import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'dart:typed_data';

final visionServiceProvider = Provider<VisionService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return VisionService(apiService);
});

class VisionService {
  final ApiService _apiService;
  final String baseUrl = Env.apiUrl;
  
  // Fun loading messages
  final List<String> _loadingMessages = [
    "Teaching AI to appreciate your item's beauty...",
    "Convincing the AI that your item is worth more than a banana...",
    "Making sure the AI doesn't mistake your item for a cat...",
    "Calculating the perfect price using advanced AI algorithms...",
    "Teaching the AI about the difference between 'vintage' and 'old'...",
    "Convincing the AI that your item is not a paperclip...",
    "Making sure the AI understands the value of your item...",
    "Teaching the AI about the difference between 'used' and 'pre-loved'...",
    "Convincing the AI that your item is not a banana...",
    "Making sure the AI doesn't mistake your item for a toaster...",
  ];

  int _currentMessageIndex = 0;

  VisionService(this._apiService);

  String getNextLoadingMessage() {
    final message = _loadingMessages[_currentMessageIndex];
    _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
    debugPrint('Loading message: $message');
    return message;
  }

  /// Analyze image using OpenAI Vision API
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    debugPrint('Starting image analysis with OpenAI: \\${imageFile.path}');
    try {
      final uri = Uri.parse('$baseUrl/api/vision/openai/analyze');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      // Add auth if needed
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Response status code: \\${response.statusCode}');
      debugPrint('Response body: \\${response.body}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('OpenAI Vision analysis successful');
        final body = json.decode(response.body);
        return {
          'success': true,
          'data': body['data'] ?? body,
        };
      } else {
        debugPrint('Error response: \\${response.body}');
        return {
          'success': false,
          'error': 'Failed to analyze image: \\${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Exception during image analysis: $e');
      return {
        'success': false,
        'error': 'Error analyzing image: $e',
      };
    }
  }

  Future<Map<String, dynamic>> analyzeImageByUrl(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/vision/openai/analyze-url'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer \\${await _apiService.getToken()}',
        },
        body: json.encode({'imageUrl': imageUrl}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze image: \\${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing image: $e');
    }
  }

  /// Analyze image bytes using OpenAI Vision API (for web)
  Future<Map<String, dynamic>> analyzeImageBytes(Uint8List imageBytes) async {
    debugPrint('Starting image analysis with OpenAI (web bytes)');
    try {
      final uri = Uri.parse('$baseUrl/api/vision/openai/analyze');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'upload.png'),
      );
      // Add auth if needed
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Response status code: \\${response.statusCode}');
      debugPrint('Response body: \\${response.body}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('OpenAI Vision analysis successful (web)');
        final body = json.decode(response.body);
        return {
          'success': true,
          'data': body['data'] ?? body,
        };
      } else {
        debugPrint('Error response: \\${response.body}');
        return {
          'success': false,
          'error': 'Failed to analyze image: \\${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Exception during image analysis (web): $e');
      return {
        'success': false,
        'error': 'Error analyzing image: $e',
      };
    }
  }
} 