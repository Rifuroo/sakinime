import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ZoroService {
  final String baseUrl = 'https://apiconsumetorg-blond.vercel.app/anime/zoro';
  late final Dio _dio;

  ZoroService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
      },
      validateStatus: (code) => code != null && code < 500,
    ));
  }

  Future<Map<String, dynamic>?> getQualities(
    String episodeId, {
    String? server,
    bool dub = false,
  }) async {
    if (kDebugMode) {
      print('🎬 ZoroService.getQualities:');
      print('   Episode ID: $episodeId');
      print('   Server: $server');
      print('   Dub: $dub');
    }

    try {
      // ✅ Use http package to preserve $ character in URL
      var url = '$baseUrl/watch/$episodeId';
      
      // Add query parameters manually
      final params = <String>[];
      if (server != null && server.isNotEmpty) params.add('server=$server');
      if (dub) params.add('dub=true');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      if (kDebugMode) {
        print('   📡 Full URL: $url');
      }
      
      // Use http package (doesn't encode $ in URL)
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (kDebugMode) {
        print('   ✅ Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (kDebugMode) {
          print('   ✅ Response keys: ${data.keys.join(", ")}');
          if (data['sources'] is List) {
            print('   Sources count: ${(data['sources'] as List).length}');
          }
          if (data['subtitles'] is List) {
            print('   Subtitles count: ${(data['subtitles'] as List).length}');
          }
        }
        
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ❌ Error: $e');
      }
      rethrow;
    }
    
    return null;
  }

  Future<Map<String, dynamic>?> getInfo(String id) async {
    final res = await _dio.get('/info', queryParameters: {'id': id});
    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> search(String query, {int page = 1}) async {
    final res = await _dio.get('/$query', queryParameters: {'page': page});
    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }
}
