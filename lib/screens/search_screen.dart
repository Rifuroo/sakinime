import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/anime_model.dart';
import '../widgets/anime_card.dart';
import '../constants/app_colors.dart';
import '../providers/anime_provider.dart';
import 'detail_anime_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialGenre;

  const SearchScreen({super.key, this.initialGenre});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Anime> _results = [];
  int _currentPage = 1;
  bool _hasNextPage = false;

  // Filters
  String? _selectedGenre;
  String _selectedType = 'all';
  bool _showFilters = false;

  // Animation
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  static const List<String> genres = [
    'Action',
    'Adventure',
    'Cars',
    'Comedy',
    'Dementia',
    'Demons',
    'Mystery',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Game',
    'Historical',
    'Horror',
    'Kids',
    'Magic',
    'Martial Arts',
    'Mecha',
    'Music',
    'Parody',
    'Samurai',
    'Romance',
    'School',
    'Sci-Fi',
    'Shoujo',
    'Shoujo Ai',
    'Shounen',
    'Shounen Ai',
    'Space',
    'Sports',
    'Super Power',
    'Vampire',
    'Harem',
    'Slice of Life',
    'Supernatural',
    'Military',
    'Police',
    'Psychological',
    'Thriller',
    'Seinen',
    'Josei',
    'Isekai'
  ];

  static const List<String> types = [
    'all',
    'movie',
    'tv',
    'ova',
    'special',
    'music',
    'ona'
  ];

  @override
  void initState() {
    super.initState();

    // Filter animation
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

    // Auto-focus search
    Future.delayed(const Duration(milliseconds: 150), () {
      _focusNode.requestFocus();
    });

    // Initial genre if provided
    if (widget.initialGenre != null) {
      _selectedGenre = widget.initialGenre;
      _searchController.text = widget.initialGenre!;
      _performSearch(widget.initialGenre!, 1);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasNextPage) {
        _performSearch(_searchController.text, _currentPage + 1, isMore: true);
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous debounce
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Clear results if empty
    if (query.trim().isEmpty) {
      final animeProvider = Provider.of<AnimeProvider>(context, listen: false);
      animeProvider.clearSearch();
      setState(() {
        _results = [];
        _hasNextPage = false;
      });
      return;
    }

    // Debounce search (500ms)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query, 1);
    });
  }

  Future<void> _performSearch(String query, int page,
      {bool isMore = false}) async {
    if (query.trim().isEmpty) return;

    final animeProvider = Provider.of<AnimeProvider>(context, listen: false);

    setState(() {
      if (isMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      await animeProvider.searchAnimes(query, page: page);

      setState(() {
        if (isMore) {
          _results = List.from(animeProvider.searchResults);
        } else {
          _results = animeProvider.searchResults;
        }
        _hasNextPage = animeProvider.hasMorePages;
        _currentPage = animeProvider.currentPage;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
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

  void _clearSearch() {
    _searchController.clear();
    final animeProvider = Provider.of<AnimeProvider>(context, listen: false);
    animeProvider.clearSearch();
    setState(() {
      _results = [];
      _hasNextPage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterPanel(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child:
                      _isLoading ? _buildLoadingState() : _buildResultsGrid(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Search bar
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search Anime...',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (query) => _performSearch(query, 1),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filter toggle
          GestureDetector(
            onTap: _toggleFilters,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _showFilters ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showFilters ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
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

  Widget _buildFilterPanel() {
    return SizeTransition(
      sizeFactor: _filterAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GENRE',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final isSelected = _selectedGenre == genre;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedGenre = genre),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        genre,
                        style: GoogleFonts.inter(
                          color:
                              isSelected ? Colors.black : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TYPE',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected = _selectedType == type;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: GoogleFonts.inter(
                          color:
                              isSelected ? Colors.black : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Summoning Results...',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: AppColors.cardBg,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Explore the Multiverse'
                  : 'No Portals Found',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchController.text.isEmpty
                  ? 'Search for your favorite series'
                  : 'Try a different keyword',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final anime = _results[index];
        return AnimeCard(
          anime: anime,
          onTap: () {
            final animeProvider =
                Provider.of<AnimeProvider>(context, listen: false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailAnimeScreen(
                  animeId: anime.id,
                  forceHiAnime: animeProvider.isHiAnime,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
