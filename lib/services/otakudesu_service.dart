import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class OtakuDesuService {
  static final OtakuDesuService _instance = OtakuDesuService._internal();
  factory OtakuDesuService() => _instance;

  final String baseUrl =
      'https://api-otakudesu-worker.joas77055.workers.dev/otakudesu';
  late final Dio _dio;

  OtakuDesuService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'Sukinime/2.0',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ));
    }
  }

  Future<List<Anime>> getOngoingAnime({int page = 1}) async {
    try {
      final response =
          await _dio.get('/ongoing', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is List) {
          return data
              .map((json) => Anime.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.getOngoingAnime error: $e');
    }
    return [];
  }

  Future<List<Anime>> getCompletedAnime({int page = 1}) async {
    try {
      final response =
          await _dio.get('/completed', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is List) {
          return data
              .map((json) => Anime.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.getCompletedAnime error: $e');
    }
    return [];
  }

  Future<List<Anime>> searchAnime(String query) async {
    try {
      final response =
          await _dio.get('/search', queryParameters: {'query': query});
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is List) {
          return data
              .map((json) => Anime.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.searchAnime error: $e');
    }
    return [];
  }

  Future<AnimeDetail?> getAnimeDetail(String slug) async {
    try {
      final response = await _dio.get('/anime/$slug');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          return AnimeDetail.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.getAnimeDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEpisodeDetails(String slug) async {
    try {
      final response = await _dio.get('/episode/$slug');
      if (response.statusCode == 200) {
        return response.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.getEpisodeDetails error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getServerDetails(String serverId) async {
    try {
      final response = await _dio.get('/server/$serverId');
      if (response.statusCode == 200) {
        return response.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('❌ OtakuDesuService.getServerDetails error: $e');
    }
    return null;
  }
}
