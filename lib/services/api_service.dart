import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Base URL from environment configuration
  final String baseUrl = Env.apiUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Singleton pattern
  ApiService._();
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  
  // Get authentication token
  Future<String?> getToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    debugPrint('getToken: token=$token');
    return token;
  }
  
  // Save authentication token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    debugPrint('saveToken: token=$token');
  }
  
  // Clear authentication token (logout)
  Future<void> logout() async {
    // Do not clear the token, so biometric login remains available
    // Optionally, clear other user data here if needed
    debugPrint('logout: token NOT cleared, biometric login remains available');
  }
  
  // Explicitly clear authentication token (for 'Forget Biometric Login')
  Future<void> clearToken() async {
    await _secureStorage.delete(key: 'auth_token');
    debugPrint('clearToken: token deleted');
  }
  
  // Helper for HTTP headers
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  // GET request
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final url = '$baseUrl/api/$endpoint';
    print('GET request to: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    
    return _handleResponse(response);
  }
  
  // POST request
  Future<dynamic> post(String endpoint, dynamic data, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final url = '$baseUrl/api/$endpoint';
    print('POST request to: $url');
    print('Request data: ${json.encode(data)}');
    
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(data),
    );
    
    return _handleResponse(response);
  }
  
  // PUT request
  Future<dynamic> put(String endpoint, dynamic data, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final url = '$baseUrl/api/$endpoint';
    print('PUT request to: $url');
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: json.encode(data),
    );
    
    return _handleResponse(response);
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final url = '$baseUrl/api/$endpoint';
    print('DELETE request to: $url');
    
    final response = await http.delete(
      Uri.parse(url),
      headers: headers,
    );
    
    return _handleResponse(response);
  }
  
  // Response handler
  dynamic _handleResponse(http.Response response) {
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _getErrorMessage(response),
      );
    }
  }
  
  // Extract error message from response
  String _getErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      return body['message'] ?? body['error'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error ${response.statusCode}: ${response.reasonPhrase}';
    }
  }
  
  // Auth methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = {
      'email': email,
      'password': password,
    };
    
    print('Attempting login with email: $email');
    final response = await post('auth/login', data, requiresAuth: false);
    print('Login response: $response');
    
    if (response['token'] != null) {
      await saveToken(response['token']);
    } else if (response['accessToken'] != null) {
      await saveToken(response['accessToken']);
    } else if (response['access_token'] != null) {
      await saveToken(response['access_token']);
    }
    
    return response;
  }
  
  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    final data = {
      'email': email,
      'password': password,
      'name': name,
    };
    
    final response = await post('auth/register', data, requiresAuth: false);
    if (response['token'] != null) {
      await saveToken(response['token']);
    }
    
    return response;
  }
  
  // Item methods
  Future<List<dynamic>> getItems() async {
    return await get('items');
  }
  
  Future<Map<String, dynamic>> getItemDetails(String itemId) async {
    return await get('items/$itemId');
  }
  
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> itemData) async {
    return await post('items', itemData);
  }
  
  Future<Map<String, dynamic>> updateItem(String itemId, Map<String, dynamic> itemData) async {
    return await put('items/$itemId', itemData);
  }
  
  Future<void> deleteItem(String itemId) async {
    await delete('items/$itemId');
  }
  
  // Trade methods
  Future<List<dynamic>> getTrades() async {
    return await get('trades');
  }
  
  Future<Map<String, dynamic>> createTradeOffer(String offeredItemId, String requestedItemId) async {
    final data = {
      'offeredItemId': offeredItemId,
      'requestedItemId': requestedItemId,
    };
    
    return await post('trades', data);
  }
  
  Future<Map<String, dynamic>> respondToTradeOffer(String tradeId, String status) async {
    return await put('trades/$tradeId/status', {'status': status});
  }
}

// Error handling
class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException({required this.statusCode, required this.message});
  
  @override
  String toString() => 'ApiException: $statusCode - $message';
}

// Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
}); 