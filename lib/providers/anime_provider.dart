import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_model.dart';
import '../services/anime_service.dart';
import '../services/indo_anime_service.dart';
import '../services/bookmark_service.dart';
import '../providers/source_provider.dart';

enum HomeSidebarCategory { movies, ona, ova, specials, tv }

enum HomeCollectionType {
  recentEpisodes,
  recentAdded,
  topAiring,
  mostPopular,
  mostFavorite,
  ongoing,
  completed,
  movies,
}

extension HomeSidebarCategoryX on HomeSidebarCategory {
  String get label {
    switch (this) {
      case HomeSidebarCategory.movies:
        return 'Movies';
      case HomeSidebarCategory.ona:
        return 'ONA';
      case HomeSidebarCategory.ova:
        return 'OVA';
      case HomeSidebarCategory.specials:
        return 'Specials';
      case HomeSidebarCategory.tv:
        return 'TV Series';
    }
  }
}

extension HomeCollectionTypeX on HomeCollectionType {
  String get title {
    switch (this) {
      case HomeCollectionType.recentEpisodes:
        return 'Recent Episodes';
      case HomeCollectionType.recentAdded:
        return 'Recent Added';
      case HomeCollectionType.topAiring:
        return 'Top Airing';
      case HomeCollectionType.mostPopular:
        return 'Most Popular';
      case HomeCollectionType.mostFavorite:
        return 'Most Favorite';
      case HomeCollectionType.ongoing:
        return 'Ongoing Anime';
      case HomeCollectionType.completed:
        return 'Completed';
      case HomeCollectionType.movies:
        return 'Movies';
    }
  }

  String get description {
    switch (this) {
      case HomeCollectionType.recentEpisodes:
        return 'Update terbaru dari zoro';
      case HomeCollectionType.recentAdded:
        return 'Rilisan terbaru di katalog';
      case HomeCollectionType.topAiring:
        return 'Anime ongoing terpopuler';
      case HomeCollectionType.mostPopular:
        return 'Pilihan terbaik minggu ini';
      case HomeCollectionType.mostFavorite:
        return 'Serial dengan favorit terbanyak';
      case HomeCollectionType.ongoing:
        return 'Belum tamat';
      case HomeCollectionType.completed:
        return 'Sudah tamat';
      case HomeCollectionType.movies:
        return 'Film layar lebar';
    }
  }
}

class AnimeProvider extends ChangeNotifier {
  final AnimeService _service = AnimeService();
  SourceProvider? _sourceProvider;

  // Indo source specific service
  IndoAnimeService? _indoService;

  AnimeSource? _lastSource;

  // New Update method for ProxyProvider
  void update(SourceProvider sourceProvider) {
    if (_lastSource != sourceProvider.currentSource) {
      if (kDebugMode)
        print(
            '🔄 PROVIDER: Source switching from $_lastSource to ${sourceProvider.currentSource}');
      _lastSource = sourceProvider.currentSource;
      _sourceProvider = sourceProvider;
      if (sourceProvider.currentSource != AnimeSource.hianime) {
        _indoService = IndoAnimeService(
          baseUrl: sourceProvider.baseUrl,
          source: sourceProvider.currentSource,
        );
      } else {
        _indoService = null;
      }
      // Clear home data when source changes
      homeOngoing = [];
      homeComplete = [];
      homeMovie = [];
      homeRecentEpisodes = [];
      homeRecentAdded = [];
      homeTopAiring = [];
      homeMostPopular = [];
      homeMostFavorite = [];
      searchResults = [];
      allAnimes = [];
      homeSectionsError = null;
      errorMessage = null;
      notifyListeners();
    }
  }

  bool get isHiAnime => _sourceProvider?.currentSource == AnimeSource.hianime;

  // Lists
  List<Anime> homeOngoing = [];
  List<Anime> homeComplete = [];
  List<Anime> homeMovie = []; // For Kuramanime
  List<Anime> recentAnimes = [];
  List<Anime> ongoingAnimes = [];
  List<Anime> completedAnimes = [];
  List<Anime> popularAnimes = [];
  List<Anime> movieAnimes = [];
  List<Anime> allAnimes = [];
  List<Anime> searchResults = [];
  List<Anime> genreAnimes = [];
  List<Anime> homeRecentEpisodes = [];
  List<Anime> homeRecentAdded = [];
  List<Anime> homeTopAiring = [];
  List<Anime> homeMostPopular = [];
  List<Anime> homeMostFavorite = [];
  List<Anime> bookmarkedAnimes = [];
  final Map<HomeSidebarCategory, List<Anime>> sidebarCollections = {
    for (final category in HomeSidebarCategory.values) category: <Anime>[],
  };

  // Status
  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingGenres = false;
  bool isHomeSectionsLoading = false;
  HomeSidebarCategory? sidebarLoadingCategory;
  String? errorMessage;
  String? homeSectionsError;
  String? sidebarErrorMessage;
  List<Character> characters = [];
  List<Map<String, dynamic>> news = [];
  bool isLoadingCharacters = false;
  bool isLoadingNews = false;
  bool hasMoreNews = true;
  bool hasMoreCharacters = true;

  // Pagination
  int currentPage = 1;
  bool hasMorePages = true;
  int totalPages = 1; // ✅ NEW: Track total pages

  // Current data
  AnimeDetail? currentAnime;
  List<StreamLink> currentStreamLinks = [];
  Map<String, List<ScheduleItem>> schedules = {};
  List<Watch2GetherRoom> watch2GetherRooms = [];
  List<Map<String, dynamic>> genres = [];
  List<Map<String, dynamic>> batchList = [];
  Map<String, dynamic>? currentEpisodeData;
  Map<String, dynamic>? syncData;
  bool isSyncDataLoading = false;

  // Search
  Timer? _searchDebounce;
  String _lastSearchQuery = '';
  final Map<HomeSidebarCategory, Timer> _sidebarCollectionTimers = {};

  // HOME
  Future<void> fetchHome() async {
    isLoading = true;
    errorMessage = null;
    if (kDebugMode)
      print(
          '📡 fetchHome starting. isHiAnime=$isHiAnime, source=${_sourceProvider?.currentSource}');
    scheduleMicrotask(() => notifyListeners());

    try {
      if (isHiAnime) {
        if (kDebugMode) print('📡 Fetching HiAnime Home...');
        final homeData = await _service.getHome();
        homeOngoing = homeData['ongoing'] ?? [];
        homeComplete = homeData['complete'] ?? [];
      } else if (_indoService != null) {
        if (kDebugMode)
          print('📡 Fetching Indo Home (${_sourceProvider?.currentSource})...');
        final homeData = await _indoService!.getHome();
        if (homeData != null) {
          homeOngoing = homeData.ongoing;
          homeComplete = homeData.completed;
          homeMovie = homeData.movies ?? [];
          if (kDebugMode)
            print(
                '✅ Loaded Indo Home: Ongoing=${homeOngoing.length}, Complete=${homeComplete.length}, Movies=${homeMovie.length}');
        } else {
          if (kDebugMode) print('⚠️ Indo Home Data is NULL');
        }
      }

      if (homeOngoing.isEmpty && homeComplete.isEmpty) {
        errorMessage = 'Tidak ada data home';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchHome: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // ✅ DYNAMIC THEME
  Color _primaryColor = const Color(0xFF6366F1);
  Color get primaryColor => _primaryColor;

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_color', color.toARGB32());
    HapticFeedback.mediumImpact();
  }

  Future<void> loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('app_theme_color');
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
      notifyListeners();
    }
  }

  // LATEST ANIMES - Optimized Progressive Loading (Balanced Speed)
  Future<void> fetchHomeSections({bool forceRefresh = false}) async {
    if (kDebugMode)
      print(
          '📡 fetchHomeSections starting. isHiAnime=$isHiAnime, source=${_sourceProvider?.currentSource}');
    // 🆕 REDIRECT FOR INDO SOURCES
    if (!isHiAnime) {
      if (kDebugMode)
        print(
            '📡 fetchHomeSections: Redirecting to fetchHome() for Indo source');
      await fetchHome();
      return;
    }

    // Prevent concurrent calls
    if (isHomeSectionsLoading) return;

    // If not forcing refresh and we have data, skip to avoid "massive" requests
    if (!forceRefresh &&
        homeMostFavorite.isNotEmpty &&
        homeRecentEpisodes.isNotEmpty) {
      if (kDebugMode) print('Home data exists, skipping fetch (Lazy Mode)');
      return;
    }

    isHomeSectionsLoading = true;
    homeSectionsError = null;
    scheduleMicrotask(() => notifyListeners());

    try {
      // 🚀 BATCH 1: Critical "Above the Fold" Content (Parallel)
      await Future.wait([
        if (forceRefresh || homeMostFavorite.isEmpty)
          (() async {
            try {
              homeMostFavorite = await _service.getMostFavorite(page: 1);
            } catch (e) {
              if (kDebugMode) print('⚠️ Batch 1 Error: $e');
            }
          })(),
        if (forceRefresh || homeRecentEpisodes.isEmpty)
          (() async {
            try {
              homeRecentEpisodes = await _service.getRecentAnime(page: 1);
            } catch (e) {
              if (kDebugMode) print('⚠️ Batch 1 Error: $e');
            }
          })(),
      ]);
      notifyListeners();

      // ⏳ SHORT DELAY (Safe but Fast)
      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 BATCH 2: Trending & New Additions (Parallel)
      await Future.wait([
        if (forceRefresh || homeTopAiring.isEmpty)
          (() async {
            try {
              homeTopAiring = await _service.getTopAiring(page: 1);
            } catch (e) {
              if (kDebugMode) print('⚠️ Batch 2 Error: $e');
            }
          })(),
        if (forceRefresh || homeRecentAdded.isEmpty)
          (() async {
            try {
              homeRecentAdded = await _service.getRecentAdded(page: 1);
            } catch (e) {
              if (kDebugMode) print('⚠️ Batch 2 Error: $e');
            }
          })(),
      ]);
      notifyListeners();

      // ⏳ SHORT DELAY
      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 BATCH 3: Most Popular
      try {
        if (forceRefresh || homeMostPopular.isEmpty) {
          homeMostPopular = await _service.getPopularAnime(page: 1);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Batch 3 Error: $e');
      }

      if (homeRecentEpisodes.isEmpty &&
          homeRecentAdded.isEmpty &&
          homeTopAiring.isEmpty &&
          homeMostPopular.isEmpty &&
          homeMostFavorite.isEmpty) {
        homeSectionsError = 'Tidak ada data untuk ditampilkan.';
      }
    } catch (e) {
      homeSectionsError = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchHomeSections: $e');
    }

    isHomeSectionsLoading = false;
    notifyListeners();
  }

  Future<void> fetchSidebarCategory(
    HomeSidebarCategory category, {
    bool forceRefresh = false,
  }) async {
    final existing = sidebarCollections[category];
    if (!forceRefresh && existing != null && existing.isNotEmpty) {
      sidebarErrorMessage = null;
      notifyListeners();
      return;
    }

    sidebarLoadingCategory = category;
    sidebarErrorMessage = null;
    notifyListeners();

    try {
      List<Anime> data;
      switch (category) {
        case HomeSidebarCategory.movies:
          data = await _service.getMovies(page: 1);
          break;
        case HomeSidebarCategory.ona:
          data = await _service.getOna(page: 1);
          break;
        case HomeSidebarCategory.ova:
          data = await _service.getOva(page: 1);
          break;
        case HomeSidebarCategory.specials:
          data = await _service.getSpecials(page: 1);
          break;
        case HomeSidebarCategory.tv:
          data = await _service.getTv(page: 1);
          break;
      }

      sidebarCollections[category] = data;

      if (data.isEmpty) {
        sidebarErrorMessage = 'Data ${category.label} kosong.';
      }
    } catch (e) {
      sidebarErrorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchSidebarCategory: $e');
    }

    sidebarLoadingCategory = null;
    notifyListeners();
  }

  List<Anime> getSidebarCollection(HomeSidebarCategory category) {
    return sidebarCollections[category] ?? [];
  }

  List<Anime> getHomeCollectionSnapshot(HomeCollectionType type) {
    switch (type) {
      case HomeCollectionType.recentEpisodes:
        return List<Anime>.from(homeRecentEpisodes);
      case HomeCollectionType.recentAdded:
        return List<Anime>.from(homeRecentAdded);
      case HomeCollectionType.topAiring:
        return List<Anime>.from(homeTopAiring);
      case HomeCollectionType.mostPopular:
        return List<Anime>.from(homeMostPopular);
      case HomeCollectionType.mostFavorite:
        return List<Anime>.from(homeMostFavorite);
      case HomeCollectionType.ongoing:
        return List<Anime>.from(homeOngoing);
      case HomeCollectionType.completed:
        return List<Anime>.from(homeComplete);
      case HomeCollectionType.movies:
        return List<Anime>.from(homeMovie);
    }
  }

  Future<Map<String, dynamic>> fetchHomeCollectionPage(
    HomeCollectionType type, {
    int page = 1,
  }) async {
    if (!isHiAnime && _indoService != null) {
      switch (type) {
        case HomeCollectionType.ongoing:
          return _indoService!.getOngoingPaginated(page);
        case HomeCollectionType.completed:
          return _indoService!.getCompletedPaginated(page);
        case HomeCollectionType.movies:
          if (page == 1) {
            return {
              'animes': homeMovie,
              'pagination': {
                'currentPage': 1,
                'hasNextPage': false,
                'totalPages': 1
              }
            };
          }
          return {
            'animes': <Anime>[],
            'pagination': {
              'currentPage': page,
              'hasNextPage': false,
              'totalPages': page
            },
          };
        default:
          if (page > 1) {
            return {
              'animes': <Anime>[],
              'pagination': {
                'currentPage': page,
                'hasNextPage': false,
                'totalPages': page
              },
            };
          }
          return {
            'animes': getHomeCollectionSnapshot(type),
            'pagination': {
              'currentPage': 1,
              'hasNextPage': false,
              'totalPages': 1
            }
          };
      }
    }

    if (!isHiAnime) {
      if (page > 1) {
        return {
          'animes': <Anime>[],
          'pagination': {
            'currentPage': page,
            'hasNextPage': false,
            'totalPages': 1
          },
        };
      }
      return {
        'animes': getHomeCollectionSnapshot(type),
        'pagination': {'currentPage': 1, 'hasNextPage': false, 'totalPages': 1}
      };
    }

    switch (type) {
      case HomeCollectionType.recentEpisodes:
        return _service.getRecentAnimeWithPagination(page: page);
      case HomeCollectionType.recentAdded:
        return _service.getRecentAddedWithPagination(page: page);
      case HomeCollectionType.topAiring:
        return _service.getTopAiringWithPagination(page: page);
      case HomeCollectionType.mostPopular:
        return _service.getMostPopularWithPagination(page: page);
      case HomeCollectionType.mostFavorite:
        return _service.getMostFavoriteWithPagination(page: page);
      case HomeCollectionType.ongoing:
      case HomeCollectionType.completed:
      case HomeCollectionType.movies:
        return {
          'animes': <Anime>[],
          'pagination': {
            'currentPage': page,
            'hasNextPage': false,
            'totalPages': 1
          },
        };
    }
  }

  // RECENT
  Future<void> fetchRecentAnimes({int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      recentAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getRecentAnimeWithPagination(page: page);
      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;

      if (page == 1) {
        recentAnimes = animes;
      } else {
        final existingIds = recentAnimes.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        recentAnimes.addAll(newAnimes);
      }

      if (recentAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime recent';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchRecentAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // SEARCH
  void searchAnimesDebounced(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      searchResults = [];
      _lastSearchQuery = '';
      notifyListeners();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      searchAnimes(query);
    });
  }

  Future<void> searchAnimes(String query, {int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      searchResults = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    _lastSearchQuery = query;
    notifyListeners();

    try {
      final List<Anime> animes;
      final int respCurrentPage;
      final bool respHasMorePages;
      final int respTotalPages;

      if (isHiAnime) {
        final result =
            await _service.searchAnimeWithPagination(query, page: page);
        animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;
        respCurrentPage = pagination['currentPage'] ?? page;
        respHasMorePages = pagination['hasNextPage'] ?? false;
        respTotalPages = pagination['totalPages'] ?? 1;
      } else if (_indoService != null) {
        final result = await _indoService!.search(query, page: page);
        animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;
        respCurrentPage = pagination['currentPage'] ?? page;
        respHasMorePages = pagination['hasNextPage'] ?? false;
        respTotalPages = pagination['totalPages'] ?? 1;
      } else {
        animes = [];
        respCurrentPage = page;
        respHasMorePages = false;
        respTotalPages = 1;
      }

      currentPage = respCurrentPage;
      hasMorePages = respHasMorePages;
      totalPages = respTotalPages;

      if (page == 1) {
        searchResults = animes;
      } else {
        final existingIds = searchResults.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        searchResults.addAll(newAnimes);
      }

      if (searchResults.isEmpty) {
        errorMessage = 'Anime "$query" tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in searchAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  void clearSearch() {
    searchResults = [];
    errorMessage = null;
    currentPage = 1;
    hasMorePages = true;
    totalPages = 1;
    notifyListeners();
  }

  // ONGOING
  Future<void> fetchOngoingAnimes(
      {int page = 1, String order = 'popular'}) async {
    if (page == 1) {
      isLoading = true;
      ongoingAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      if (isHiAnime) {
        final result = await _service.getOngoingAnimeWithPagination(
            page: page, order: order);
        final animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;

        currentPage = pagination['currentPage'] ?? page;
        hasMorePages = pagination['hasNextPage'] ?? false;
        totalPages = pagination['totalPages'] ?? 1;

        if (page == 1) {
          ongoingAnimes = animes;
        } else {
          final existingIds = ongoingAnimes.map((a) => a.id).toSet();
          final newAnimes =
              animes.where((a) => !existingIds.contains(a.id)).toList();
          ongoingAnimes.addAll(newAnimes);
        }
      } else if (_indoService != null) {
        final result = await _indoService!.getOngoingPaginated(page);
        final animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;

        currentPage = pagination['currentPage'] ?? page;
        hasMorePages = pagination['hasNextPage'] ?? false;
        totalPages = pagination['totalPages'] ?? 1;

        if (page == 1) {
          ongoingAnimes = animes;
        } else {
          final existingIds = ongoingAnimes.map((a) => a.id).toSet();
          final newAnimes =
              animes.where((a) => !existingIds.contains(a.id)).toList();
          ongoingAnimes.addAll(newAnimes);
        }
      }

      if (ongoingAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime ongoing';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchOngoingAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // COMPLETED
  Future<void> fetchCompletedAnimes(
      {int page = 1, String order = 'latest'}) async {
    if (page == 1) {
      isLoading = true;
      completedAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      if (isHiAnime) {
        final result = await _service.getCompletedAnimeWithPagination(
            page: page, order: order);
        final animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;

        currentPage = pagination['currentPage'] ?? page;
        hasMorePages = pagination['hasNextPage'] ?? false;
        totalPages = pagination['totalPages'] ?? 1;

        if (page == 1) {
          completedAnimes = animes;
        } else {
          final existingIds = completedAnimes.map((a) => a.id).toSet();
          final newAnimes =
              animes.where((a) => !existingIds.contains(a.id)).toList();
          completedAnimes.addAll(newAnimes);
        }
      } else if (_indoService != null) {
        final result = await _indoService!.getCompletedPaginated(page);
        final animes = result['animes'] as List<Anime>;
        final pagination = result['pagination'] as Map<String, dynamic>;

        currentPage = pagination['currentPage'] ?? page;
        hasMorePages = pagination['hasNextPage'] ?? false;
        totalPages = pagination['totalPages'] ?? 1;

        if (page == 1) {
          completedAnimes = animes;
        } else {
          final existingIds = completedAnimes.map((a) => a.id).toSet();
          final newAnimes =
              animes.where((a) => !existingIds.contains(a.id)).toList();
          completedAnimes.addAll(newAnimes);
        }
      }

      if (completedAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime completed';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchCompletedAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // POPULAR
  Future<void> fetchPopularAnimes({int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      popularAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getPopularAnimeWithPagination(page: page);
      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;

      if (page == 1) {
        popularAnimes = animes;
      } else {
        final existingIds = popularAnimes.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        popularAnimes.addAll(newAnimes);
      }

      if (popularAnimes.isEmpty) {
        errorMessage = 'Tidak ada anime popular';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchPopularAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // MOVIES
  Future<void> fetchMovies({int page = 1, String order = 'update'}) async {
    if (page == 1) {
      isLoading = true;
      movieAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final result =
          await _service.getMoviesWithPagination(page: page, order: order);
      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;

      if (page == 1) {
        movieAnimes = animes;
      } else {
        final existingIds = movieAnimes.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        movieAnimes.addAll(newAnimes);
      }

      if (movieAnimes.isEmpty) {
        errorMessage = 'Tidak ada movie';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchMovies: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // ALL ANIME LIST
  Future<void> fetchAllAnimes({int page = 1, String? query}) async {
    if (page == 1) {
      isLoading = true;
      allAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      Map<String, dynamic> result;

      if (query != null && query.trim().isNotEmpty) {
        result = await _service.searchAnimeWithPagination(query, page: page);
      } else {
        result = await _service.getRecentAnimeWithPagination(page: page);
      }

      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;

      if (page == 1) {
        allAnimes = animes;
      } else {
        final existingIds = allAnimes.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        allAnimes.addAll(newAnimes);
      }

      if (allAnimes.isEmpty) {
        errorMessage = query != null
            ? 'Anime "$query" tidak ditemukan'
            : 'Tidak ada data anime';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchAllAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // SCHEDULE
  Future<void> fetchSchedule({String? date}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _service.getSchedule();

      // Clear existing schedules
      schedules = {};

      // Safely parse the schedule data
      data.forEach((key, value) {
        try {
          if (value is List) {
            final list = value
                .map((i) {
                  if (i is Map) {
                    return ScheduleItem.fromJson(Map<String, dynamic>.from(i));
                  }
                  return null;
                })
                .whereType<ScheduleItem>()
                .toList();

            if (list.isNotEmpty) {
              schedules[key.toString()] = list;
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Error parsing schedule for $key: $e');
        }
      });

      if (schedules.isEmpty) {
        errorMessage = 'Jadwal tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchSchedule: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // SURPRISE ME (Randomizer)
  Future<Anime?> fetchRandomAnime() async {
    try {
      HapticFeedback.heavyImpact();
      // Fetch most popular list (usually has many items)
      if (homeMostPopular.isEmpty) {
        await fetchHome();
      }

      final list = homeMostPopular.isNotEmpty ? homeMostPopular : popularAnimes;
      if (list.isNotEmpty) {
        final random = DateTime.now().millisecond % list.length;
        return list[random];
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error in Surprise Me: $e');
    }
    return null;
  }

  // WATCH2GETHER
  Future<void> fetchWatch2GetherRooms({String room = 'all'}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _service.getWatch2GetherRooms(room: room);
      watch2GetherRooms =
          data.map((i) => Watch2GetherRoom.fromJson(i)).toList();

      if (watch2GetherRooms.isEmpty) {
        errorMessage = 'Tidak ada room aktif';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchWatch2GetherRooms: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // SYNC DATA
  Future<void> fetchSyncData(String id) async {
    isSyncDataLoading = true;
    syncData = null;
    notifyListeners();

    try {
      syncData = await _service.getSyncData(id);
    } catch (e) {
      if (kDebugMode) print('❌ Error in fetchSyncData: $e');
    }

    isSyncDataLoading = false;
    notifyListeners();
  }

  // GENRES
  Future<void> fetchGenres() async {
    isLoadingGenres = true;
    errorMessage = null;
    notifyListeners();

    try {
      genres = await _service.getGenres();

      if (genres.isEmpty) {
        errorMessage = 'Genre tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchGenres: $e');
    }

    isLoadingGenres = false;
    notifyListeners();
  }

  // ✅ IMPROVED: Anime by Genre with Pagination Support
  Future<void> fetchAnimeByGenre(String genreId, {int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      genreAnimes = [];
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      // ✅ Use new method that returns pagination info
      final result =
          await _service.getAnimeByGenreWithPagination(genreId, page: page);

      final animes = result['animes'] as List<Anime>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      // ✅ Update pagination state
      currentPage = pagination['currentPage'] ?? page;
      hasMorePages = pagination['hasNextPage'] ?? false;
      totalPages = pagination['totalPages'] ?? 1;

      if (kDebugMode) {
        print('📄 Provider pagination state:');
        print('   Current: $currentPage/$totalPages');
        print('   Has more: $hasMorePages');
        print('   Anime count: ${animes.length}');
      }

      if (page == 1) {
        genreAnimes = animes;
      } else {
        final existingIds = genreAnimes.map((a) => a.id).toSet();
        final newAnimes =
            animes.where((a) => !existingIds.contains(a.id)).toList();
        genreAnimes.addAll(newAnimes);
      }

      if (genreAnimes.isEmpty) {
        errorMessage = 'Anime genre tidak ditemukan';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchAnimeByGenre: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // BATCH
  Future<void> fetchBatchList({int page = 1}) async {
    if (page == 1) {
      isLoading = true;
      batchList = [];
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final batches = await _service.getBatchList(page: page);

      if (page == 1) {
        batchList = batches;
      } else {
        batchList.addAll(batches);
      }

      currentPage = page;
      hasMorePages = batches.length >= 16; // Changed from 20 to 16

      if (batchList.isEmpty) {
        errorMessage = 'Tidak ada batch';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchBatchList: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // ANIME DETAIL
  Future<void> fetchAnimeDetail(String animeId,
      {bool forceHiAnime = false}) async {
    isLoading = true;
    errorMessage = null;
    currentAnime = null;
    notifyListeners();

    try {
      if (kDebugMode)
        print(
            '🔍 PROVIDER: Fetching anime detail for $animeId (forceHiAnime=$forceHiAnime, isHiAnime=$isHiAnime)');

      final useHiAnime = forceHiAnime || isHiAnime;

      if (useHiAnime) {
        currentAnime = await _service.getAnimeDetail(animeId);
      } else {
        currentAnime = await _indoService?.getDetail(animeId);
      }

      if (currentAnime == null) {
        errorMessage = 'Anime tidak ditemukan';
        if (kDebugMode) print('❌ PROVIDER: currentAnime is null');
      } else {
        if (kDebugMode) {
          print('✅ PROVIDER: Anime loaded successfully');
          print('   Title: ${currentAnime!.title}');
          print('   Episodes count: ${currentAnime!.episodes.length}');
        }
        // Automaticaly fetch characters for the detail screen (HiAnime only)
        if (useHiAnime) {
          fetchCharacters(animeId);
        }
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ PROVIDER Error in fetchAnimeDetail: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // STREAMING LINKS
  Future<void> fetchStreamingLinks(String episodeId) async {
    currentStreamLinks = [];
    currentEpisodeData = null; // ✅ Reset episode data
    errorMessage = null;

    try {
      if (kDebugMode) print('🔥 PROVIDER: Requesting streaming for $episodeId');

      if (isHiAnime) {
        // ✅ Get full episode data from service
        final episodeData = await _service.getEpisodeDetail(episodeId);

        if (episodeData != null) {
          currentEpisodeData = episodeData;

          // ✅ Extract streaming links from episode data
          if (episodeData['link'] is Map) {
            final link = episodeData['link'];
            final videoUrl = link['proxyUrl']?.toString() ??
                link['file']?.toString() ??
                link['directUrl']?.toString() ??
                '';

            if (videoUrl.isNotEmpty) {
              currentStreamLinks = [
                StreamLink.fromJson({
                  'provider': 'HiAnime ${episodeData['server'] ?? 'HD-2'}',
                  'url': videoUrl,
                  'type': link['type']?.toString() ?? 'hls',
                  'quality': 'auto',
                  'source': 'hianime',
                  if (episodeData['tracks'] != null)
                    'tracks': episodeData['tracks'],
                })
              ];
            }
          } else if (episodeData['resolved_links'] != null) {
            final links = episodeData['resolved_links'] as List;
            currentStreamLinks =
                links.map((l) => StreamLink.fromJson(l)).toList();
          }
        }
      } else if (_indoService != null) {
        currentStreamLinks = await _indoService!.getStreamLinks(episodeId);
      }

      if (currentStreamLinks.isEmpty) {
        errorMessage = 'Streaming link tidak ditemukan';
        if (kDebugMode) print('⚠️ No streaming links found: $episodeId');
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchStreamingLinks: $e');
    }

    notifyListeners();
  }

  // BATCH DETAIL
  Future<Map<String, dynamic>?> fetchBatchDetail(String batchId) async {
    try {
      final batchDetail = await _service.getBatchDetail(batchId);
      return batchDetail;
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchBatchDetail: $e');
      return null;
    }
  }

  // SERVER URL
  Future<String?> fetchServerUrl(String serverId) async {
    try {
      if (!isHiAnime && _indoService != null) {
        return await _indoService!.getServerUrl(serverId);
      }
      final url = await _service.getServerUrl(serverId);
      return url;
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchServerUrl: $e');
      return null;
    }
  }

  Map<String, String>? getHeadersForUrl(String url) {
    if (!isHiAnime && _indoService != null) {
      return _indoService!.getHeadersForUrl(url);
    }
    return {
      'User-Agent': 'Sukinime/2.0',
      'Referer': isHiAnime ? 'https://hianime.to/' : ''
    };
  }

  // HELPERS
  String get lastSearchQuery => _lastSearchQuery;

  void clearSearchResults() {
    searchResults = [];
    _lastSearchQuery = '';
    errorMessage = null;
    currentPage = 1;
    hasMorePages = true;
    notifyListeners();
  }

  // CHARACTERS
  Future<void> fetchCharacters(String animeId, {int page = 1}) async {
    if (page == 1) {
      isLoadingCharacters = true;
      characters = [];
      hasMoreCharacters = true;
    } else {
      isLoadingMore = true;
    }
    notifyListeners();

    try {
      final result = await _service.getCharacters(animeId, page: page);
      if (kDebugMode)
        print(
            '👥 Provider.fetchCharacters result: ${result.length} items for $animeId');

      final mappedChars = result.map((c) => Character.fromJson(c)).toList();

      if (page == 1) {
        characters = mappedChars;
      } else {
        characters.addAll(mappedChars);
      }
      hasMoreCharacters = result.length >= 10;
    } catch (e) {
      if (kDebugMode) print('❌ Error in fetchCharacters: $e');
    } finally {
      isLoadingCharacters = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  // NEWS
  Future<void> fetchNews({int page = 1}) async {
    if (page == 1) {
      isLoadingNews = true;
      news = [];
      hasMoreNews = true;
    } else {
      isLoadingMore = true; // Use shared isLoadingMore flag
    }
    notifyListeners();

    try {
      final result = await _service.getNews(page: page);
      if (kDebugMode)
        print('📰 Provider.fetchNews result: ${result.length} items');
      if (page == 1) {
        news = result;
      } else {
        news.addAll(result);
      }
      notifyListeners();
      hasMoreNews = result.length >= 10;
    } catch (e) {
      if (kDebugMode) print('❌ Error in fetchNews: $e');
    } finally {
      isLoadingNews = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void reset() {
    _searchDebounce?.cancel();
    homeOngoing = [];
    homeComplete = [];
    recentAnimes = [];
    ongoingAnimes = [];
    completedAnimes = [];
    popularAnimes = [];
    movieAnimes = [];
    allAnimes = [];
    searchResults = [];
    genreAnimes = [];
    homeRecentEpisodes = [];
    homeRecentAdded = [];
    homeTopAiring = [];
    homeMostPopular = [];
    homeMostFavorite = [];
    for (final category in HomeSidebarCategory.values) {
      sidebarCollections[category] = [];
    }
    currentAnime = null;
    currentStreamLinks = [];
    schedules = {};
    genres = [];
    batchList = [];
    characters = [];
    news = [];
    errorMessage = null;
    homeSectionsError = null;
    sidebarErrorMessage = null;
    isHomeSectionsLoading = false;
    sidebarLoadingCategory = null;
    _lastSearchQuery = '';
    hasMorePages = true;
    currentPage = 1;
    totalPages = 1;
    notifyListeners();
  }

  // ✅ Bookmarks
  Future<void> fetchBookmarks() async {
    bookmarkedAnimes = await BookmarkService.getBookmarks();
    notifyListeners();
  }

  Future<void> toggleBookmark(Anime anime) async {
    final exists = bookmarkedAnimes.any((item) => item.id == anime.id);
    if (exists) {
      await BookmarkService.removeBookmark(anime.id);
    } else {
      await BookmarkService.addBookmark(anime);
    }
    await fetchBookmarks();
  }

  bool isBookmarked(String animeId) {
    return bookmarkedAnimes.any((item) => item.id == animeId);
  }

  Future<void> fetchBrowseAnimes({
    String? category,
    String? genre,
    String? type,
    int page = 1,
  }) async {
    if (page == 1) {
      isLoading = true;
      allAnimes = []; // Using allAnimes as a general buffer for browse
      currentPage = 1;
      hasMorePages = true;
      totalPages = 1;
    } else {
      isLoadingMore = true;
    }

    errorMessage = null;
    notifyListeners();

    try {
      if (isHiAnime) {
        if (genre != null && genre.isNotEmpty) {
          final result = await _service.getAnimeByGenreWithPagination(
            genre.toLowerCase().replaceAll(' ', '-'),
            page: page,
          );
          _updateBrowseResults(result, page);
        } else {
          final result = await _service.filterAnimeWithPagination(
            keyword: null,
            genres: null,
            type: type != 'all' ? type : null,
            page: page,
            category: category,
          );
          _updateBrowseResults(result, page);
        }
      } else if (_indoService != null) {
        if (genre != null && genre.isNotEmpty) {
          final result = await _indoService!.search(genre, page: page);
          _updateBrowseResults(result, page);
        } else {
          Map<String, dynamic> result;
          if (category == 'completed') {
            result = await _indoService!.getCompletedPaginated(page);
          } else {
            result = await _indoService!.getOngoingPaginated(page);
          }
          _updateBrowseResults(result, page);
        }
      }
    } catch (e) {
      errorMessage = 'Error: $e';
      if (kDebugMode) print('❌ Error in fetchBrowseAnimes: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  void _updateBrowseResults(Map<String, dynamic> result, int page) {
    final List<Anime> animes =
        result['animes'] is List ? List<Anime>.from(result['animes']) : [];
    final pagination = result['pagination'] as Map<String, dynamic>;

    currentPage = pagination['currentPage'] ?? page;
    hasMorePages = pagination['hasNextPage'] ?? false;
    totalPages = pagination['totalPages'] ?? 1;

    if (page == 1) {
      allAnimes = animes;
    } else {
      final existingIds = allAnimes.map((a) => a.id).toSet();
      final newAnimes =
          animes.where((a) => !existingIds.contains(a.id)).toList();
      allAnimes.addAll(newAnimes);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _sidebarCollectionTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }
}
