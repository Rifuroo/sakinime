import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class KuramanimeService {
  static final KuramanimeService _instance = KuramanimeService._internal();
  factory KuramanimeService() => _instance;

  final String baseUrl =
      'https://api-otakudesu-worker.joas77055.workers.dev/kuramanime';
  late final Dio _dio;

  KuramanimeService._internal() {
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

  Future<Map<String, List<Anime>>> getHome() async {
    try {
      final response = await _dio.get('/home');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final ongoing = <Anime>[];
        final added = <Anime>[];

        if (data['ongoing']?['episodeList'] is List) {
          for (var item in data['ongoing']['episodeList']) {
            ongoing.add(Anime.fromJson(Map<String, dynamic>.from(item)));
          }
        }

        if (data['recentlyAdded']?['animeList'] is List) {
          for (var item in data['recentlyAdded']['animeList']) {
            added.add(Anime.fromJson(Map<String, dynamic>.from(item)));
          }
        }

        return {'ongoing': ongoing, 'complete': added};
      }
    } catch (e) {
      if (kDebugMode) print('❌ KuramanimeService.getHome error: $e');
    }
    return {};
  }

  Future<AnimeDetail?> getAnimeDetail(String id, String slug) async {
    try {
      final response = await _dio.get('/anime/$id/$slug');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          return AnimeDetail.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ KuramanimeService.getAnimeDetail error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEpisodeDetails(
      String id, String slug, String episodeId) async {
    try {
      final response = await _dio.get('/episode/$id/$slug/$episodeId');
      if (response.statusCode == 200) {
        return response.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('❌ KuramanimeService.getEpisodeDetails error: $e');
    }
    return null;
  }
}
