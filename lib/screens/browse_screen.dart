import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/anime_model.dart';
import '../widgets/anime_card.dart';
import '../constants/app_colors.dart';
import 'detail_anime_screen.dart';

class BrowseScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialGenre;

  const BrowseScreen({
    super.key,
    this.initialCategory,
    this.initialGenre,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> with SingleTickerProviderStateMixin {
  // Constants
  static const List<String> genres = [
    'Action', 'Adventure', 'Cars', 'Comedy', 'Dementia', 'Demons', 'Mystery', 'Drama', 'Ecchi',
    'Fantasy', 'Game', 'Historical', 'Horror', 'Kids', 'Magic', 'Martial Arts', 'Mecha', 'Music',
    'Parody', 'Samurai', 'Romance', 'School', 'Sci-Fi', 'Shoujo', 'Shoujo Ai', 'Shounen',
    'Shounen Ai', 'Space', 'Sports', 'Super Power', 'Vampire', 'Harem', 'Slice of Life',
    'Supernatural', 'Military', 'Police', 'Psychological', 'Thriller', 'Seinen', 'Josei', 'Isekai'
  ];

  static const List<String> types = ['all', 'movie', 'tv', 'ova', 'special', 'music', 'ona'];

  static const List<Map<String, String>> categories = [
    {'id': 'most-popular', 'name': 'Most Popular'},
    {'id': 'recently-updated', 'name': 'Recently Updated'},
    {'id': 'recently-added', 'name': 'Recently Added'},
    {'id': 'top-airing', 'name': 'Top Airing'},
    {'id': 'top-upcoming', 'name': 'Top Upcoming'},
    {'id': 'most-favorite', 'name': 'Most Favorite'},
    {'id': 'completed', 'name': 'Completed'},
    {'id': 'subbed-anime', 'name': 'Subbed'},
    {'id': 'dubbed-anime', 'name': 'Dubbed'},
  ];

  // State
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Anime> _animeList = [];
  int _currentPage = 1;
  bool _hasNextPage = true;

  // Filters
  String _selectedCategory = 'most-popular';
  String? _selectedGenre;
  String _selectedType = 'all';
  bool _showFilters = false;

  // Animation
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  // Scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Initialize from params
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
      _selectedGenre = null;
    }
    if (widget.initialGenre != null) {
      _selectedGenre = widget.initialGenre;
      _selectedCategory = '';
    }

    // Animation
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );

    // Scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Initial fetch
    _fetchData(1, reset: true);
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasNextPage) {
        _fetchData(_currentPage + 1);
      }
    }
  }

  Future<void> _fetchData(int page, {bool reset = false}) async {
    if (page > 1 && !_hasNextPage) return;

    setState(() {
      if (page == 1) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      const baseUrl = 'https://api.animo.qzz.io/api/v1/animes';
      String url;

      if (_selectedGenre != null && _selectedGenre!.isNotEmpty) {
        String genrePath = _selectedGenre!.toLowerCase().replaceAll(' ', '-');
        if (genrePath == 'martial-arts') genrePath = 'marial-arts';
        url = '$baseUrl/genre/$genrePath';
      } else if (_selectedCategory.isNotEmpty) {
        url = '$baseUrl/$_selectedCategory';
      } else {
        url = '$baseUrl/most-popular';
      }

      final fetchUrl = '$url?page=$page${_selectedType != 'all' ? '&type=$_selectedType' : ''}';
      final response = await http.get(Uri.parse(fetchUrl));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final realData = json['data'] ?? json;

        if (realData['response'] != null) {
          final List<dynamic> animeData = realData['response'];
          final List<Anime> newAnime = animeData
              .map((item) => _mapAnimeCard(item))
              .where((anime) => anime != null)
              .cast<Anime>()
              .toList();

          setState(() {
            if (reset) {
              _animeList = newAnime;
            } else {
              _animeList.addAll(newAnime);
            }
            _hasNextPage = realData['pageInfo']?['hasNextPage'] ?? false;
            _currentPage = page;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching browse data: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Anime? _mapAnimeCard(Map<String, dynamic> item) {
    try {
      return Anime(
        id: item['id'] ?? '',
        title: item['name'] ?? item['title'] ?? 'Unknown',
        poster: item['poster'] ?? '',
        rating: item['rating']?.toString(),
        type: item['type'],
        status: item['status'],
      );
    } catch (e) {
      return null;
    }
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
    if (_showFilters) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _selectedGenre = null;
    });
    _fetchData(1, reset: true);
  }

  void _onGenreSelected(String genre) {
    setState(() {
      _selectedGenre = genre;
      _selectedCategory = '';
    });
    _fetchData(1, reset: true);
  }

  void _onTypeSelected(String type) {
    setState(() => _selectedType = type);
    _fetchData(1, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Category Tabs
                _buildCategoryTabs(),
                
                // Filter Panel
                _buildFilterPanel(),
                
                // Anime Grid
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _animeList.isEmpty
                          ? _buildEmptyState()
                          : _buildAnimeGrid(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Browse Anime',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: _toggleFilters,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _showFilters ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.tune,
                color: _showFilters ? Colors.black : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['id'] && _selectedGenre == null;
          
          return GestureDetector(
            onTap: () => _onCategorySelected(category['id']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  category['name']!,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    return SizeTransition(
      sizeFactor: _filterAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Genre Filter
            Text(
              'Genre',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final isSelected = _selectedGenre == genre;
                  
                  return GestureDetector(
                    onTap: () => _onGenreSelected(genre),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        genre,
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Type Filter
            Text(
              'Type',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected = _selectedType == type;
                  
                  return GestureDetector(
                    onTap: () => _onTypeSelected(type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _animeList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _animeList.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final anime = _animeList[index];
        return AnimeCard(
          anime: anime,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailAnimeScreen(animeId: anime.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No anime found',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different filters',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
