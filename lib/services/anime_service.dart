// services/anime_service.dart - HiAnime API v2.0.0
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';

class AnimeService {
  // ✅ NEW API BASE URL
  final String baseUrl = 'https://hianime-api.joas77055.workers.dev/api/v1';
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
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: true,
        error: true,
        requestHeader: false,
        responseHeader: false,
      ));
    }
  }

  // ✅ Safe API call with retry
  Future<Response?> _safeApiCall(String endpoint, {
    Map<String, dynamic>? queryParameters,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (kDebugMode) print('🔄 Attempt ${attempt + 1}: $endpoint');
        if (attempt > 0) await Future.delayed(Duration(seconds: 2 * attempt));
        
        final response = await _dio.get(endpoint, queryParameters: queryParameters);
        if (response.statusCode == 200) {
          if (kDebugMode) print('✅ Success: $endpoint');
          return response;
        }
        if (kDebugMode) print('⚠️ Status ${response.statusCode}: $endpoint');
      } on DioException catch (e) {
        if (kDebugMode) print('❌ DioException: ${e.type} - ${e.message}');
        if (attempt == maxRetries - 1) break;
      }
    }
    return null;
  }


  // ✅ Parse anime list - handles new API response format
  // Response: { success: true, data: { response: [...], pageInfo: {...} } }
  List<Anime> _parseAnimeList(dynamic data) {
    if (kDebugMode) {
      print('\n🔍 PARSING ANIME LIST');
      print('   Data type: ${data.runtimeType}');
    }
    
    if (data == null) return [];
    
    List<dynamic> animeListRaw = [];
    
    if (data is Map) {
      // NEW API: { success: true, data: { response: [...] } }
      if (data['success'] == true && data['data'] is Map) {
        final innerData = data['data'];
        if (innerData['response'] is List) {
          animeListRaw = innerData['response'] as List;
          if (kDebugMode) print('   📦 Found: data.response structure (new API)');
        } else if (innerData['animes'] is List) {
          animeListRaw = innerData['animes'] as List;
          if (kDebugMode) print('   📦 Found: data.animes structure');
        }
      }
      // Direct data array
      else if (data['data'] is List) {
        animeListRaw = data['data'] as List;
        if (kDebugMode) print('   📦 Found: data array structure');
      }
      // Results array
      else if (data['results'] is List) {
        animeListRaw = data['results'] as List;
        if (kDebugMode) print('   📦 Found: results array structure');
      }
    } else if (data is List) {
      animeListRaw = data;
      if (kDebugMode) print('   📦 Found: direct array structure');
    }
    
    if (animeListRaw.isEmpty) {
      if (kDebugMode) print('❌ Could not parse anime list');
      return [];
    }
    
    if (kDebugMode) print('✅ Found ${animeListRaw.length} anime items');
    
    final result = <Anime>[];
    for (var item in animeListRaw) {
      try {
        if (item is Map) {
          final anime = Anime.fromJson(Map<String, dynamic>.from(item));
          result.add(anime);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Skip anime: $e');
      }
    }
    
    if (kDebugMode) print('✅ Parsed ${result.length} anime successfully');
    return result;
  }

  // ✅ HOME - /home endpoint
  Future<Map<String, List<Anime>>> getHome() async {
    try {
      if (kDebugMode) print('\n🏠 Fetching home...');
      final response = await _safeApiCall('/home');
      
      if (response != null && response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          final homeData = data['data'];
          
          final ongoing = <Anime>[];
          final complete = <Anime>[];
          
          // Parse spotlight/trending as ongoing
          if (homeData['spotlight'] is List) {
            for (var item in homeData['spotlight']) {
              try {
                ongoing.add(Anime.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }
          if (homeData['trending'] is List) {
            for (var item in homeData['trending']) {
              try {
                ongoing.add(Anime.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }
          
          // Parse top airing as complete
          if (homeData['topAiring'] is List) {
            for (var item in homeData['topAiring']) {
              try {
                complete.add(Anime.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }
          
          if (kDebugMode) print('✅ Home loaded: ongoing=${ongoing.length}, complete=${complete.length}');
          return {'ongoing': ongoing, 'complete': complete};
        }
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ Error (home): $e');
      return {};
    }
  }


  // ✅ Generic fetch list helper with PAGINATION support
  Future<Map<String, dynamic>> _fetchDataWithPagination(String endpoint, {int page = 1, String debugLabel = '', Map<String, dynamic>? extraParams}) async {
    final label = debugLabel.isEmpty ? endpoint : debugLabel;
    try {
      if (kDebugMode) print('\n📡 Fetching $label (page: $page)');
      
      final Map<String, dynamic> params = {'page': page};
      if (extraParams != null) params.addAll(extraParams);
      
      final response = await _dio.get(endpoint, queryParameters: params);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final list = _parseAnimeList(data);
        
        // Extract pagination info
        int currentPage = page;
        bool hasNextPage = false;
        int totalPages = 1;
        
        if (data is Map && data['data'] is Map) {
          final pageInfo = data['data']['pageInfo'];
          if (pageInfo is Map) {
            currentPage = pageInfo['currentPage'] ?? page;
            hasNextPage = pageInfo['hasNextPage'] ?? false;
            totalPages = pageInfo['totalPages'] ?? 1;
          }
        }
        
        if (kDebugMode) print('✅ Loaded $label: ${list.length} anime | page=$currentPage hasNext=$hasNextPage');
        
        return {
          'animes': list,
          'pagination': {
            'currentPage': currentPage,
            'hasNextPage': hasNextPage,
            'totalPages': totalPages,
          },
        };
      }
      return {'animes': <Anime>[], 'pagination': {'currentPage': page, 'hasNextPage': false, 'totalPages': 1}};
    } catch (e) {
      if (kDebugMode) print('❌ Error ($label): $e');
      return {'animes': <Anime>[], 'pagination': {'currentPage': page, 'hasNextPage': false, 'totalPages': 1}};
    }
  }

  // ✅ Legacy helper for backward compatibility
  Future<List<Anime>> _fetchList(String endpoint, {int page = 1, String debugLabel = ''}) async {
    final result = await _fetchDataWithPagination(endpoint, page: page, debugLabel: debugLabel);
    return result['animes'] as List<Anime>;
  }

  // ✅ ANIME LISTS - New API endpoints with PAGINATION versions
  Future<Map<String, dynamic>> getRecentAnimeWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/recently-updated', page: page, debugLabel: 'recently-updated');
      
  Future<List<Anime>> getRecentAnime({int page = 1}) async =>
      _fetchList('/animes/recently-updated', page: page, debugLabel: 'recently-updated');

  Future<Map<String, dynamic>> getRecentAddedWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/recently-added', page: page, debugLabel: 'recently-added');

  Future<List<Anime>> getRecentAdded({int page = 1}) async =>
      _fetchList('/animes/recently-added', page: page, debugLabel: 'recently-added');

  Future<Map<String, dynamic>> getTopAiringWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/top-airing', page: page, debugLabel: 'top-airing');

  Future<List<Anime>> getTopAiring({int page = 1}) async =>
      _fetchList('/animes/top-airing', page: page, debugLabel: 'top-airing');

  Future<Map<String, dynamic>> getMostPopularWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/most-popular', page: page, debugLabel: 'most-popular');

  Future<List<Anime>> getMostPopular({int page = 1}) async =>
      _fetchList('/animes/most-popular', page: page, debugLabel: 'most-popular');

  Future<Map<String, dynamic>> getMostFavoriteWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/most-favorite', page: page, debugLabel: 'most-favorite');

  Future<List<Anime>> getMostFavorite({int page = 1}) async =>
      _fetchList('/animes/most-favorite', page: page, debugLabel: 'most-favorite');

  Future<Map<String, dynamic>> getOngoingAnimeWithPagination({int page = 1, String order = 'popular'}) async =>
      _fetchDataWithPagination('/animes/top-airing', page: page, debugLabel: 'top-airing');

  Future<List<Anime>> getOngoingAnime({int page = 1, String order = 'popular'}) async =>
      _fetchList('/animes/top-airing', page: page, debugLabel: 'top-airing');

  Future<Map<String, dynamic>> getCompletedAnimeWithPagination({int page = 1, String order = 'latest'}) async =>
      _fetchDataWithPagination('/animes/completed', page: page, debugLabel: 'completed');

  Future<List<Anime>> getCompletedAnime({int page = 1, String order = 'latest'}) async =>
      _fetchList('/animes/completed', page: page, debugLabel: 'completed');

  Future<Map<String, dynamic>> getPopularAnimeWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/most-popular', page: page, debugLabel: 'most-popular');

  Future<List<Anime>> getPopularAnime({int page = 1}) async =>
      _fetchList('/animes/most-popular', page: page, debugLabel: 'most-popular');

  Future<Map<String, dynamic>> getTopUpcomingWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/top-upcoming', page: page, debugLabel: 'top-upcoming');

  Future<List<Anime>> getTopUpcoming({int page = 1}) async =>
      _fetchList('/animes/top-upcoming', page: page, debugLabel: 'top-upcoming');

  // ✅ TYPE-BASED LISTS with PAGINATION
  Future<Map<String, dynamic>> getMoviesWithPagination({int page = 1, String order = 'update'}) async =>
      _fetchDataWithPagination('/animes/movie', page: page, debugLabel: 'movie');

  Future<List<Anime>> getMovies({int page = 1, String order = 'update'}) async =>
      _fetchList('/animes/movie', page: page, debugLabel: 'movie');

  Future<Map<String, dynamic>> getTvWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/tv', page: page, debugLabel: 'tv');

  Future<List<Anime>> getTv({int page = 1}) async =>
      _fetchList('/animes/tv', page: page, debugLabel: 'tv');

  Future<Map<String, dynamic>> getOvaWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/ova', page: page, debugLabel: 'ova');

  Future<List<Anime>> getOva({int page = 1}) async =>
      _fetchList('/animes/ova', page: page, debugLabel: 'ova');

  Future<Map<String, dynamic>> getOnaWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/ona', page: page, debugLabel: 'ona');

  Future<List<Anime>> getOna({int page = 1}) async =>
      _fetchList('/animes/ona', page: page, debugLabel: 'ona');

  Future<Map<String, dynamic>> getSpecialsWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/special', page: page, debugLabel: 'special');

  Future<List<Anime>> getSpecials({int page = 1}) async =>
      _fetchList('/animes/special', page: page, debugLabel: 'special');

  // ✅ SUB/DUB LISTS with PAGINATION
  Future<Map<String, dynamic>> getSubbedAnimeWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/subbed-anime', page: page, debugLabel: 'subbed-anime');

  Future<List<Anime>> getSubbedAnime({int page = 1}) async =>
      _fetchList('/animes/subbed-anime', page: page, debugLabel: 'subbed-anime');

  Future<Map<String, dynamic>> getDubbedAnimeWithPagination({int page = 1}) async =>
      _fetchDataWithPagination('/animes/dubbed-anime', page: page, debugLabel: 'dubbed-anime');

  Future<List<Anime>> getDubbedAnime({int page = 1}) async =>
      _fetchList('/animes/dubbed-anime', page: page, debugLabel: 'dubbed-anime');


  // ✅ SEARCH - /search?keyword={query}&page={page} with PAGINATION
  Future<Map<String, dynamic>> searchAnimeWithPagination(String query, {int page = 1}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return {'animes': <Anime>[], 'pagination': {'currentPage': page, 'hasNextPage': false, 'totalPages': 1}};
    }
    return _fetchDataWithPagination('/search', page: page, debugLabel: 'search', extraParams: {'keyword': trimmedQuery});
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    final result = await searchAnimeWithPagination(query, page: page);
    return result['animes'] as List<Anime>;
  }

  // ✅ SUGGESTION - /suggestion?keyword={query}
  Future<List<Anime>> getSuggestions(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      
      final response = await _dio.get('/suggestion', queryParameters: {'keyword': query.trim()});
      if (response.statusCode == 200) {
        return _parseAnimeList(response.data);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (suggestion): $e');
      return [];
    }
  }

  // ✅ FILTER - /filter with multiple params
  Future<List<Anime>> filterAnime({
    String? keyword,
    String? genres,
    String? type,
    String? status,
    String? rated,
    String? score,
    String? season,
    String? language,
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{'page': page};
      if (keyword != null) params['keyword'] = keyword;
      if (genres != null) params['genres'] = genres;
      if (type != null) params['type'] = type;
      if (status != null) params['status'] = status;
      if (rated != null) params['rated'] = rated;
      if (score != null) params['score'] = score;
      if (season != null) params['season'] = season;
      if (language != null) params['language'] = language;
      
      final response = await _dio.get('/filter', queryParameters: params);
      if (response.statusCode == 200) {
        return _parseAnimeList(response.data);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (filter): $e');
      return [];
    }
  }

  // ✅ A-Z LIST - /animes/az-list/{letter}
  Future<List<Anime>> getAnimeAZList(String letter, {int page = 1}) async {
    return _fetchList('/animes/az-list/$letter', page: page, debugLabel: 'az-list-$letter');
  }


  // ✅ GENRES - /genres and /animes/genre/{genre}
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      if (kDebugMode) print('\n📂 Fetching genres...');
      final response = await _dio.get('/genres');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is List) {
          final genres = (data['data'] as List).map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return {
                'id': e['id'] ?? e['slug'] ?? e['name']?.toString().toLowerCase().replaceAll(' ', '-'),
                'name': e['name'] ?? e['title'] ?? e.toString(),
                'slug': e['slug'] ?? e['id'] ?? e['name']?.toString().toLowerCase().replaceAll(' ', '-'),
              };
            }
            return {'id': e.toString(), 'name': e.toString(), 'slug': e.toString()};
          }).toList();
          if (kDebugMode) print('✅ Found ${genres.length} genres');
          return genres;
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (genres): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAnimeByGenreWithPagination(String genreId, {int page = 1}) async {
    try {
      if (kDebugMode) print('\n📂 Fetching genre "$genreId" (page: $page)');
      final response = await _dio.get('/animes/genre/$genreId', queryParameters: {'page': page});
      
      if (response.statusCode == 200) {
        final data = response.data;
        final animeList = _parseAnimeList(data);
        
        // Parse pagination from new API format
        int currentPage = page;
        bool hasNextPage = false;
        int totalPages = 1;
        
        if (data is Map && data['data'] is Map) {
          final pageInfo = data['data']['pageInfo'];
          if (pageInfo is Map) {
            currentPage = pageInfo['currentPage'] ?? page;
            hasNextPage = pageInfo['hasNextPage'] ?? false;
            totalPages = pageInfo['totalPages'] ?? 1;
          }
        }
        
        if (kDebugMode) print('✅ Genre loaded: ${animeList.length} animes | page=$currentPage hasMore=$hasNextPage');
        
        return {
          'animes': animeList,
          'pagination': {
            'currentPage': currentPage,
            'hasNextPage': hasNextPage,
            'totalPages': totalPages,
          },
        };
      }
      
      return {'animes': <Anime>[], 'pagination': {'currentPage': page, 'hasNextPage': false, 'totalPages': 1}};
    } catch (e) {
      if (kDebugMode) print('❌ Error (genre): $e');
      return {'animes': <Anime>[], 'pagination': {'currentPage': page, 'hasNextPage': false, 'totalPages': 1}};
    }
  }

  Future<List<Anime>> getAnimeByGenre(String genreId, {int page = 1}) async {
    final result = await getAnimeByGenreWithPagination(genreId, page: page);
    return result['animes'] as List<Anime>;
  }

  // ✅ PRODUCER - /animes/producer/{producer}
  Future<List<Anime>> getAnimeByProducer(String producer, {int page = 1}) async {
    return _fetchList('/animes/producer/$producer', page: page, debugLabel: 'producer-$producer');
  }


  // ✅ ANIME DETAIL - /anime/{id}
  Future<AnimeDetail?> getAnimeDetail(String animeId) async {
    try {
      if (kDebugMode) print('\n📺 Fetching detail: $animeId');
      
      // Clean anime ID
      String cleanId = animeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      if (cleanId.endsWith('/')) cleanId = cleanId.substring(0, cleanId.length - 1);
      
      final response = await _dio.get('/anime/$cleanId');
      if (response.statusCode != 200) return null;

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final animeData = Map<String, dynamic>.from(data['data']);
        
        if (kDebugMode) print('📊 Anime detail keys: ${animeData.keys.toList()}');
        
        // Fetch episodes separately
        final episodesResponse = await _dio.get('/episodes/$cleanId');
        if (episodesResponse.statusCode == 200) {
          final epData = episodesResponse.data;
          if (epData is Map && epData['success'] == true && epData['data'] is List) {
            animeData['episodes'] = epData['data'];
          }
        }
        
        final detail = AnimeDetail.fromJson(animeData);
        if (kDebugMode) print('✅ AnimeDetail parsed: ${detail.title} | eps=${detail.episodes.length}');
        return detail;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (detail): $e');
      return null;
    }
  }

  // ✅ EPISODES - /episodes/{id}
  Future<List<Episode>> getEpisodes(String animeId) async {
    try {
      String cleanId = animeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      
      final response = await _dio.get('/episodes/$cleanId');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is List) {
          final episodes = <Episode>[];
          for (var ep in data['data']) {
            try {
              episodes.add(Episode.fromJson(Map<String, dynamic>.from(ep)));
            } catch (_) {}
          }
          return episodes;
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (episodes): $e');
      return [];
    }
  }

  // ✅ CHARACTERS - /characters/{id}
  Future<List<Map<String, dynamic>>> getCharacters(String animeId, {int page = 1}) async {
    try {
      final response = await _dio.get('/characters/$animeId', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final data = response.data;
        if (kDebugMode) print('👥 getCharacters data keys: ${data.keys}');
        if (data is Map && data['success'] == true && data['data'] is Map) {
          final charData = data['data'];
          if (kDebugMode) print('👥 charData keys: ${charData.keys}');
          if (charData['response'] is List) {
            final charList = List<Map<String, dynamic>>.from(charData['response']);
            if (kDebugMode) print('👥 Found ${charList.length} characters');
            if (charList.isNotEmpty && kDebugMode) {
              print('👥 First character sample: ${charList.first}');
            }
            return charList;
          }
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (characters): $e');
      return [];
    }
  }

  // ✅ CHARACTER DETAIL - /character/{id}
  Future<Map<String, dynamic>?> getCharacterDetail(String characterId) async {
    try {
      final response = await _dio.get('/character/$characterId');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (character): $e');
      return null;
    }
  }


  // ✅ SCHEDULE - /schedules
  Future<Map<String, dynamic>> getSchedule() async {
    try {
      if (kDebugMode) print('\n📅 Fetching schedule...');
      final response = await _dio.get('/schedules');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          if (kDebugMode) print('✅ Schedule loaded');
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('❌ Error (schedule): $e');
      return {};
    }
  }

  // ✅ NEWS - /news
  Future<List<Map<String, dynamic>>> getNews({int page = 1}) async {
    try {
      final response = await _dio.get('/news', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final data = response.data;
        if (kDebugMode) print('📰 getNews data keys: ${data.keys}');
        if (data is Map && data['success'] == true && data['data'] is Map) {
          final newsData = data['data'];
          if (kDebugMode) print('📰 newsData keys: ${newsData.keys}');
          if (newsData['news'] is List) {
            final newsList = List<Map<String, dynamic>>.from(newsData['news']);
            if (kDebugMode) print('📰 Found ${newsList.length} news items');
            return newsList;
          }
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (news): $e');
      return [];
    }
  }

  // ✅ NEXT EPISODE SCHEDULE - /schedule/next/{id}
  Future<Map<String, dynamic>?> getNextEpisodeSchedule(String animeId) async {
    try {
      final response = await _dio.get('/schedule/next/$animeId');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (next schedule): $e');
      return null;
    }
  }


  // ✅ RANDOM ANIME - /random
  Future<String?> getRandomAnime() async {
    try {
      final response = await _dio.get('/random');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return data['data']?['id']?.toString();
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (random): $e');
      return null;
    }
  }

  // ✅ WATCH2GETHER - /watch2gether
  Future<List<Map<String, dynamic>>> getWatch2GetherRooms({String room = 'all'}) async {
    try {
      final response = await _dio.get('/watch2gether', queryParameters: {'room': room});
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          final rooms = data['data']['rooms'];
          if (rooms is List) {
            return List<Map<String, dynamic>>.from(rooms);
          }
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error (watch2gether): $e');
      return [];
    }
  }

  // ✅ SYNC DATA - /sync/:id
  Future<Map<String, dynamic>?> getSyncData(String id) async {
    try {
      final response = await _dio.get('/sync/$id');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (syncData): $e');
      return null;
    }
  }

  // ✅ FILTER OPTIONS - /filter/options
  Future<Map<String, dynamic>?> getFilterOptions() async {
    try {
      final response = await _dio.get('/filter/options');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (filter options): $e');
      return null;
    }
  }


  // ✅ SERVERS - /servers?id={episodeId}
  Future<Map<String, dynamic>?> getServers(String episodeId) async {
    try {
      String cleanId = episodeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      
      final response = await _dio.get('/servers', queryParameters: {'id': cleanId});
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (servers): $e');
      return null;
    }
  }

  // ✅ STREAM - /stream?id={episodeId}&type={sub/dub}&server={hd-1/hd-2}
  Future<Map<String, dynamic>?> getStream(String episodeId, {String type = 'sub', String server = 'hd-2'}) async {
    try {
      String cleanId = episodeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      
      final response = await _dio.get('/stream', queryParameters: {
        'id': cleanId,
        'type': type,
        'server': server,
      });
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error (stream): $e');
      return null;
    }
  }

  // ✅ STREAMING LINKS - wrapper for getStream
  Future<List<StreamLink>> getStreamingLinks(String episodeUrl) async {
    try {
      if (kDebugMode) print('\n🔥 FETCHING STREAMING LINKS: $episodeUrl');
      
      final streamData = await getStream(episodeUrl);
      if (streamData == null) return [];
      
      final List<StreamLink> allLinks = [];
      
      // Parse link object
      if (streamData['link'] is Map) {
        final link = streamData['link'];
        final videoUrl = link['proxyUrl']?.toString() ?? 
                        link['file']?.toString() ?? 
                        link['directUrl']?.toString() ?? '';
        
        if (videoUrl.isNotEmpty) {
          allLinks.add(StreamLink.fromJson({
            'provider': 'HiAnime ${streamData['server'] ?? 'HD-2'}',
            'url': videoUrl,
            'type': link['type']?.toString() ?? 'hls',
            'quality': 'auto',
            'source': 'hianime',
          }));
        }
      }
      
      if (kDebugMode) print('✅ Total links: ${allLinks.length}');
      return allLinks;
    } catch (e) {
      if (kDebugMode) print('❌ Error (streaming links): $e');
      return [];
    }
  }

  // ✅ PROXY - /proxy?url={url}&referer={referer}
  String getProxyUrl(String url, {String referer = 'https://megacloud.tv'}) {
    final encodedUrl = Uri.encodeComponent(url);
    final encodedReferer = Uri.encodeComponent(referer);
    return '$baseUrl/proxy?url=$encodedUrl&referer=$encodedReferer';
  }

  // ✅ EMBED URL - /embed?id={episodeId}&server={server}&type={type}
  String getEmbedUrl(String episodeId, {String server = 'hd-2', String type = 'sub'}) {
    return '$baseUrl/embed?id=$episodeId&server=$server&type=$type';
  }

  // ✅ Legacy methods for compatibility
  Future<List<Anime>> getAllAnimeList() async {
    final home = await getHome();
    return [...?home['ongoing'], ...?home['complete']];
  }

  Future<Map<String, dynamic>?> getEpisodeDetail(String episodeId) async {
    return await getStream(episodeId);
  }

  Future<List<Map<String, dynamic>>> getBatchList({int page = 1}) async => [];
  Future<Map<String, dynamic>?> getBatchDetail(String batchId) async => null;
  Future<String?> getServerUrl(String serverId) async => null;
}
