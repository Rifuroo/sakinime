// services/anime_service.dart - FIXED ALL PARSING ISSUES
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class AnimeService {
  final String baseUrl = 'https://apiconsumetorg-blond.vercel.app/anime/zoro/';
  late Dio _dio;

  AnimeService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Sukinime/2.0',
      },
      validateStatus: (status) => status != null && status < 500,
    ));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: true,
          error: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  Future<Response?> _safeApiCall(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (kDebugMode) print('🔄 Attempt ${attempt + 1}: $endpoint');
        
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
        
        final response = await _dio.get(
          endpoint,
          queryParameters: queryParameters,
        );
        
        if (response.statusCode == 200) {
          if (kDebugMode) print('✅ Success: $endpoint');
          return response;
        }
        
        if (kDebugMode) print('⚠️ Status ${response.statusCode}: $endpoint');
        
      } on DioException catch (e) {
        if (kDebugMode) {
          print('❌ DioException: ${e.type}');
          print('   Message: ${e.message}');
        }
        
        if (attempt == maxRetries - 1) break;
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    
    return null;
  }

  // ✅ FIXED: Parsing yang lebih fleksibel
  List<Anime> _parseAnimeList(dynamic data) {
    if (kDebugMode) {
      print('\n🔍 PARSING ANIME LIST');
      print('   Data type: ${data.runtimeType}');
    }
    
    if (data == null) {
      if (kDebugMode) print('❌ Data is null');
      return [];
    }
    
    List<dynamic> animeListRaw = [];
    
    // ✅ NEW: Cek berbagai struktur data yang mungkin
    if (data is Map) {
      // Struktur 1: {data: {anime: [...]}}
      if (data['data'] is Map && data['data']['anime'] is List) {
        animeListRaw = data['data']['anime'] as List;
        if (kDebugMode) print('   📦 Found: data.anime structure');
      }
      // Struktur 2: {data: {animeList: [...]}}
      else if (data['data'] is Map && data['data']['animeList'] is List) {
        animeListRaw = data['data']['animeList'] as List;
        if (kDebugMode) print('   📦 Found: data.animeList structure');
      }
      // Struktur 3: {data: [..]} (direct array)
      else if (data['data'] is List) {
        animeListRaw = data['data'] as List;
        if (kDebugMode) print('   📦 Found: data array structure');
      }
      // Struktur 4: {anime: [...]}
      else if (data['anime'] is List) {
        animeListRaw = data['anime'] as List;
        if (kDebugMode) print('   📦 Found: anime array structure');
      }
      // Struktur 5: {animeList: [...]}
      else if (data['animeList'] is List) {
        animeListRaw = data['animeList'] as List;
        if (kDebugMode) print('   📦 Found: animeList array structure');
      }
      // Struktur 6: {results: [...]}
      else if (data['results'] is List) {
        animeListRaw = data['results'] as List;
        if (kDebugMode) print('   📦 Found: results array structure');
      }
    } 
    // Struktur 6: Direct array
    else if (data is List) {
      animeListRaw = data;
      if (kDebugMode) print('   📦 Found: direct array structure');
    }
    
    if (animeListRaw.isEmpty) {
      if (kDebugMode) {
        print('❌ Could not parse anime list');
        print('   Available keys: ${data is Map ? data.keys.toList() : "N/A"}');
      }
      return [];
    }
    
    if (kDebugMode) print('✅ Found ${animeListRaw.length} anime items');
    
    final result = <Anime>[];
    
    for (int index = 0; index < animeListRaw.length; index++) {
      try {
        final item = animeListRaw[index];
        
        if (item is Map<String, dynamic>) {
          final anime = Anime.fromJson(item);
          result.add(anime);
        } else if (item is Map) {
          final anime = Anime.fromJson(Map<String, dynamic>.from(item));
          result.add(anime);
        } else {
          if (kDebugMode) print('⚠️ Skip anime $index: invalid type ${item.runtimeType}');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('⚠️ Skip anime $index: $e');
          final lines = stackTrace.toString().split('\n');
          if (lines.isNotEmpty) print('   ${lines[0]}');
        }
      }
    }
    
    if (kDebugMode) print('✅ Parsed ${result.length} anime successfully');
    return result;
  }

  // HOME
  Future<Map<String, List<Anime>>> getHome() async {
    try {
      if (kDebugMode) print('\n🏠 Fetching home from Zoro...');

      final recent = await _dio.get('recent-episodes');
      final topAiring = await _dio.get('top-airing');

      final ongoing = recent.statusCode == 200
          ? _parseAnimeList(recent.data)
          : <Anime>[];
      final complete = topAiring.statusCode == 200
          ? _parseAnimeList(topAiring.data)
          : <Anime>[];

      if (kDebugMode) {
        print('✅ Home loaded (Zoro): ongoing=${ongoing.length}, complete=${complete.length}');
      }

      return {
        'ongoing': ongoing,
        'complete': complete,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro home): $e');
      return {};
    }
  }

  Future<List<Anime>> _fetchList(
    String endpoint, {
    int page = 1,
    String debugLabel = '',
  }) async {
    final label = debugLabel.isEmpty ? endpoint : debugLabel;
    try {
      if (kDebugMode) print('\n📡 Fetching $label (page: $page) [Zoro]');
      final response = await _dio.get(endpoint, queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final list = _parseAnimeList(response.data);
        if (kDebugMode) print('✅ Loaded $label: ${list.length} anime');
        return list;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error ($label): $e');
      return [];
    }
  }

  // RECENT ANIME
  Future<List<Anime>> getRecentAnime({int page = 1}) async =>
      _fetchList('recent-episodes', page: page, debugLabel: 'recent-episodes');

  Future<List<Anime>> getRecentAdded({int page = 1}) async =>
      _fetchList('recent-added', page: page, debugLabel: 'recent-added');

  Future<List<Anime>> getTopAiring({int page = 1}) async =>
      _fetchList('top-airing', page: page, debugLabel: 'top-airing');

  Future<List<Anime>> getMostPopular({int page = 1}) async =>
      _fetchList('most-popular', page: page, debugLabel: 'most-popular');

  Future<List<Anime>> getMostFavorite({int page = 1}) async =>
      _fetchList('most-favorite', page: page, debugLabel: 'most-favorite');

  // ✅ FIXED: Search with fallback
  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) return [];

      if (kDebugMode) print('\n🔍 Searching (Zoro): $trimmedQuery');
      final response = await _dio.get(trimmedQuery, queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final animeList = _parseAnimeList(response.data);
        if (kDebugMode) print('✅ Search (Zoro) found ${animeList.length} results');
        return animeList;
      }

      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro search): $e');
      return [];
    }
  }

  // ONGOING
  Future<List<Anime>> getOngoingAnime({int page = 1, String order = 'popular'}) async =>
      _fetchList('top-airing', page: page, debugLabel: 'top-airing');

  // COMPLETED
  Future<List<Anime>> getCompletedAnime({int page = 1, String order = 'latest'}) async {
    try {
      if (kDebugMode) print('\n📡 Fetching latest-completed (page: $page) [Zoro]');
      final response = await _dio.get('latest-completed', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final list = _parseAnimeList(response.data);
        if (kDebugMode) print('✅ Completed (latest-completed) loaded: ${list.length}');
        return list;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro latest-completed): $e');
      return [];
    }
  }

  // POPULAR
  Future<List<Anime>> getPopularAnime({int page = 1}) async =>
      _fetchList('most-popular', page: page, debugLabel: 'most-popular');

  // MOVIES
  Future<List<Anime>> getMovies({int page = 1, String order = 'update'}) async =>
      _fetchList('movies', page: page, debugLabel: 'movies');

  Future<List<Anime>> getOna({int page = 1}) async =>
      _fetchList('ona', page: page, debugLabel: 'ona');

  Future<List<Anime>> getOva({int page = 1}) async =>
      _fetchList('ova', page: page, debugLabel: 'ova');

  Future<List<Anime>> getSpecials({int page = 1}) async =>
      _fetchList('specials', page: page, debugLabel: 'specials');

  Future<List<Anime>> getTv({int page = 1}) async =>
      _fetchList('tv', page: page, debugLabel: 'tv');

  // ✅ FIXED: All Anime List with fallback
  Future<List<Anime>> getAllAnimeList() async {
    try {
      if (kDebugMode) print('\n📚 Fetching anime list (top-airing page 1) [Zoro]');
      final response = await _dio.get('top-airing', queryParameters: {'page': 1});
      if (response.statusCode == 200) {
        final list = _parseAnimeList(response.data);
        if (list.isNotEmpty) return list;
      }
      final home = await getHome();
      return [
        ...?home['ongoing'],
        ...?home['complete'],
      ];
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro all list): $e');
      return [];
    }
  }

  // ✅ FIXED: Schedule with better error handling
  Future<Map<String, dynamic>> getSchedule() async {
    try {
      if (kDebugMode) print('\n📅 Fetching schedule...');
      
      final response = await _safeApiCall('schedule', maxRetries: 1);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          if (data is List) {
            final scheduleMap = <String, dynamic>{};
            for (var dayData in data) {
              if (dayData is Map && dayData['day'] != null) {
                scheduleMap[dayData['day']] = dayData['anime_list'] ?? [];
              }
            }
            
            if (kDebugMode) print('✅ Schedule loaded: ${scheduleMap.keys.length} days');
            if (scheduleMap.isNotEmpty) return scheduleMap;
          }
        }
      }
      
      // ✅ Return empty if unavailable
      if (kDebugMode) print('⚠️ Schedule endpoint unavailable');
      return {};
      
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {};
    }
  }

  // GENRES
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      if (kDebugMode) print('\n📂 Fetching genres (Zoro)...');
      final response = await _dio.get('genre/list');
      if (response.statusCode == 200) {
        final data = response.data;
        final list = (data is Map && data['genres'] is List)
            ? List.from(data['genres'] as List)
            : (data is List ? data : <dynamic>[]);
        final genres = list.map<Map<String, dynamic>>((e) {
          final name = e is String ? e : (e['name']?.toString() ?? e['title']?.toString() ?? e.toString());
          final slug = name.toString();
          return {
            'id': slug,
            'name': name,
            'slug': slug,
            'url': '',
          };
        }).toList();
        if (kDebugMode) print('✅ Found ${genres.length} genres (Zoro)');
        return genres;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro genres): $e');
      return [];
    }
  }

  // ✅ FIXED: Anime by Genre with pagination
  Future<Map<String, dynamic>> getAnimeByGenreWithPagination(String genreId, {int page = 1}) async {
    try {
      if (kDebugMode) print('\n📂 Fetching genre "$genreId" (page: $page) [Zoro]');
      final response = await _dio.get('genre/$genreId', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final data = response.data;
        final animeList = _parseAnimeList(data);
        final currentPage = (data is Map && data['currentPage'] != null)
            ? int.tryParse(data['currentPage'].toString()) ?? page
            : page;
        final hasNextPage = (data is Map && data['hasNextPage'] != null)
            ? (data['hasNextPage'] == true)
            : animeList.length >= 16;
        final paginationInfo = {
          'currentPage': currentPage,
          'hasNextPage': hasNextPage,
          'totalPages': hasNextPage ? currentPage + 1 : currentPage,
        };
        if (kDebugMode) {
          print('✅ Genre loaded (Zoro): ${animeList.length} animes | page=$currentPage hasMore=$hasNextPage');
        }
        return {
          'animes': animeList,
          'pagination': paginationInfo,
        };
      }
      return {
        'animes': <Anime>[],
        'pagination': {
          'currentPage': page,
          'hasNextPage': false,
          'totalPages': 1,
        },
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error (Zoro genre): $e');
      return {
        'animes': <Anime>[],
        'pagination': {
          'currentPage': page,
          'hasNextPage': false,
          'totalPages': 1,
        },
      };
    }
  }

  Future<List<Anime>> getAnimeByGenre(String genreId, {int page = 1}) async {
    final result = await getAnimeByGenreWithPagination(genreId, page: page);
    return result['animes'] as List<Anime>;
  }

  // BATCH LIST
  Future<List<Map<String, dynamic>>> getBatchList({int page = 1}) async {
    try {
      if (kDebugMode) print('\n📦 Batch list not available');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // ✅ FIXED: Anime Detail with better episode parsing
  Future<AnimeDetail?> getAnimeDetail(String animeId) async {
    try {
      if (kDebugMode) print('\n📺 Fetching detail: $animeId');
      // Zoro detail endpoint
      final response = await _dio.get('info', queryParameters: {'id': animeId});
      if (response.statusCode != 200) return null;

      final data = response.data;
      final raw = (data is Map && data['data'] is Map)
          ? Map<String, dynamic>.from(data['data'] as Map)
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});

      if (raw.isEmpty) return null;

      try {
        if (kDebugMode) {
          print('📊 Zoro info keys: ${raw.keys.toList()}');
        }
        final detail = AnimeDetail.fromJson(raw);
        if (kDebugMode) {
          print('✅ AnimeDetail parsed successfully (Zoro): ${detail.title} | eps=${detail.episodes.length}');
        }
        return detail;
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('❌ Failed to parse AnimeDetail (Zoro): $e');
          print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        }
        return null;
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Exception in getAnimeDetail: $e');
      return null;
    }
  }

  // EPISODE DETAIL
  Future<Map<String, dynamic>?> getEpisodeDetail(String episodeId) async {
    try {
      String cleanEpisodeId = episodeId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      
      if (kDebugMode) print('🎬 SERVICE: Fetching episode detail for: $cleanEpisodeId');
      
      final response = await _safeApiCall('episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          
          if (data != null && data is Map) {
            if (kDebugMode) {
              print('✅ SERVICE: Episode data received');
              print('   Available keys: ${data.keys.toList()}');
            }
            
            return Map<String, dynamic>.from(data);
          }
        }
      }
      
      if (kDebugMode) print('⚠️ SERVICE: Failed to get episode detail');
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ SERVICE Error in getEpisodeDetail: $e');
        print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }
      return null;
    }
  }

  // STREAMING LINKS
  Future<List<StreamLink>> getStreamingLinks(String episodeUrl) async {
    try {
      if (kDebugMode) print('\n🔥 FETCHING STREAMING LINKS: $episodeUrl');
      
      String cleanEpisodeId = episodeUrl;
      
      final response = await _safeApiCall('episode/$cleanEpisodeId', maxRetries: 3);
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          final data = responseData['data'];
          final List<StreamLink> allLinks = [];
          
          if (data['stream_url'] != null && data['stream_url'].toString().isNotEmpty) {
            final streamUrl = data['stream_url'].toString();
            allLinks.add(StreamLink.fromJson({
              'provider': 'Desustream Default',
              'url': streamUrl,
              'type': streamUrl.contains('.m3u8') ? 'hls' : 'mp4',
              'quality': 'auto',
              'source': 'default',
              'priority': 0,
            }));
            if (kDebugMode) print('✅ Added stream_url: Desustream');
          }
          
          if (data['download_urls'] != null && data['download_urls'] is Map) {
            final downloadUrls = data['download_urls'] as Map;
            
            if (downloadUrls['mp4'] is List) {
              for (var resolutionData in downloadUrls['mp4']) {
                final resolution = resolutionData['resolution'] ?? 'auto';
                final urls = resolutionData['urls'] as List? ?? [];
                
                for (var urlData in urls) {
                  final provider = urlData['provider'] ?? 'Unknown';
                  final url = urlData['url'] ?? '';
                  
                  if (url.isNotEmpty) {
                    allLinks.add(StreamLink.fromJson({
                      'provider': '$provider $resolution',
                      'url': url,
                      'type': 'mp4',
                      'quality': resolution,
                      'source': 'download',
                      'priority': 50,
                    }));
                  }
                }
              }
            }
          }
          
          allLinks.sort((a, b) {
            final priorityA = (a.toJson()['priority'] ?? 99) as int;
            final priorityB = (b.toJson()['priority'] ?? 99) as int;
            return priorityA.compareTo(priorityB);
          });
          
          if (kDebugMode) {
            print('✅ Total links: ${allLinks.length}');
            if (allLinks.isNotEmpty) {
              print('   🎯 Primary: ${allLinks.first.provider}');
            }
          }
          
          return allLinks;
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return [];
    }
  }

  // BATCH DETAIL
  Future<Map<String, dynamic>?> getBatchDetail(String batchId) async {
    try {
      if (kDebugMode) print('\n📦 Fetching batch detail: $batchId');
      
      final response = await _safeApiCall('batch/$batchId');
      
      if (response != null && response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map) {
          return responseData['data'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }

  // SERVER URL
  Future<String?> getServerUrl(String serverId) async {
    try {
      if (kDebugMode) print('\n🎬 Server URL not available');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return null;
    }
  }
}