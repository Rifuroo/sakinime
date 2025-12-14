// screens/all_anime_screen.dart - Modern Clean UI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../providers/anime_provider.dart';
import '../widgets/anime_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/loading_shimmer.dart';

class AllAnimeScreen extends StatefulWidget {
  const AllAnimeScreen({super.key});

  @override
  State<AllAnimeScreen> createState() => _AllAnimeScreenState();
}

class _AllAnimeScreenState extends State<AllAnimeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _starController;
  bool _isSearching = false;
  int _currentPage = 1;
  static const int _batchSize = 50;
  int _displayedItems = _batchSize;

  @override
  void initState() {
    super.initState();
    
    _starController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AnimeProvider>(context, listen: false);
      if (provider.allAnimes.isEmpty) {
        provider.fetchAllAnimes(page: 1);
      }
    });
  }

  void _loadMoreItems() {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    final displayList = _isSearching ? provider.searchResults : provider.allAnimes;
    
    if (_displayedItems < displayList.length) {
      setState(() {
        _displayedItems = (_displayedItems + _batchSize).clamp(0, displayList.length);
      });
    } else if (provider.hasMorePages && !provider.isLoadingMore) {
      _loadMoreFromAPI();
    }
  }

  void _loadMoreFromAPI() {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    
    if (_isSearching && _searchController.text.isNotEmpty) {
      provider.searchAnimes(
        _searchController.text.trim(),
        page: _currentPage + 1,
      );
    } else {
      provider.fetchAllAnimes(page: _currentPage + 1);
    }
    setState(() => _currentPage++);
  }

  Future<void> _onSearch(String query) async {
    setState(() {
      _isSearching = query.trim().isNotEmpty;
      _currentPage = 1;
      _displayedItems = _batchSize;
    });
    
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    if (query.trim().isEmpty) {
      await provider.fetchAllAnimes(page: 1);
    } else {
      await provider.searchAnimes(query.trim(), page: 1);
    }
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _currentPage = 1;
      _displayedItems = _batchSize;
    });
    Provider.of<AnimeProvider>(context, listen: false).fetchAllAnimes(page: 1);
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _displayedItems = _batchSize;
    });
    AnimeCard.clearCache();
    await Provider.of<AnimeProvider>(context, listen: false).fetchAllAnimes(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Animated Background Stars
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                return CustomPaint(
                  painter: StarfieldPainter(_starController.value),
                );
              },
            ),
          ),

          // Main Content
          Consumer<AnimeProvider>(
            builder: (context, provider, _) {
              final displayList = _isSearching 
                  ? provider.searchResults 
                  : provider.allAnimes;
              
              final itemsToShow = displayList.take(_displayedItems).toList();
              final hasMoreToDisplay = _displayedItems < displayList.length;
              
              return RefreshIndicator(
                onRefresh: _refresh,
                color: const Color(0xFF818CF8),
                backgroundColor: const Color(0xFF1A1A2E),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Modern App Bar
                    SliverAppBar(
                      floating: false,
                      pinned: true,
                      backgroundColor: const Color(0xFF0A0A0A),
                      elevation: 0,
                      toolbarHeight: 80,
                      flexibleSpace: Stack(
                        children: [
                          // Gradient Background
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF6366F1).withOpacity(0.12),
                                  const Color(0xFF8B5CF6).withOpacity(0.08),
                                  const Color(0xFF0A0A0A),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          // Gradient Orbs
                          Positioned(
                            top: -40,
                            right: -40,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF818CF8).withOpacity(0.2),
                                    const Color(0xFF6366F1).withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Content
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 80, 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF818CF8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.video_library,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'All Anime',
                                          style: GoogleFonts.poppins(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.8,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Complete collection',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          child: IconButton(
                            onPressed: _refresh,
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),

                    // Search Section
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomSearchBar(
                              controller: _searchController,
                              onChanged: _onSearch,
                              onClear: _clearSearch,
                            ),
                            const SizedBox(height: 16),
                            
                            // Info Bar
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_isSearching) ...[
                                  Expanded(
                                    child: Text(
                                      'Found ${displayList.length} results',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF8FAFC),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _clearSearch,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Clear',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Anime Library',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFF8FAFC),
                                            letterSpacing: -0.3,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Showing ${itemsToShow.length} of ${displayList.length}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (displayList.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF6366F1).withOpacity(0.2),
                                            const Color(0xFF8B5CF6).withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF6366F1).withOpacity(0.4),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1).withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${displayList.length}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF818CF8),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Error Message
                    if (provider.errorMessage != null)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFEF4444).withOpacity(0.1),
                                const Color(0xFFDC2626).withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.warning_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  provider.errorMessage!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFCA5A5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Anime Grid
                    provider.isLoading && displayList.isEmpty
                        ? const SliverToBoxAdapter(child: LoadingShimmer())
                        : displayList.isEmpty
                            ? SliverFillRemaining(child: _buildEmptyState())
                            : SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.65,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 20,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return AnimeCard(anime: itemsToShow[index]);
                                    },
                                    childCount: itemsToShow.length,
                                  ),
                                ),
                              ),

                    // Load More Button
                    if ((hasMoreToDisplay || provider.hasMorePages) && displayList.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: provider.isLoadingMore
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF818CF8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          'Loading more...',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loadMoreItems,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: const Color(0xFF6366F1).withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      hasMoreToDisplay
                                          ? 'Show ${(displayList.length - _displayedItems).clamp(0, _batchSize)} More'
                                          : 'Load More',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.15),
                      const Color(0xFF8B5CF6).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isSearching ? Icons.search_off_rounded : Icons.video_library_outlined,
                  size: 40,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            _isSearching ? 'No results found' : 'No anime available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFCBD5E1),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isSearching 
                ? 'Try a different search term'
                : 'Pull down to refresh',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View All Anime',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _starController.dispose();
    super.dispose();
  }
}

// Starfield Painter
class StarfieldPainter extends CustomPainter {
  final double animation;
  final List<Star> stars = [];

  StarfieldPainter(this.animation) {
    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      stars.add(Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 0.5,
        speed: random.nextDouble() * 0.5 + 0.3,
        opacity: random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var star in stars) {
      final twinkle = (math.sin(animation * math.pi * 2 * star.speed) + 1) / 2;
      final opacity = star.opacity * twinkle * 0.4;
      
      paint.color = const Color(0xFF818CF8).withOpacity(opacity);
      
      final x = star.x * size.width;
      final y = star.y * size.height;
      
      canvas.drawCircle(Offset(x, y), star.size, paint);
      
      if (star.size > 1.5) {
        paint.color = const Color(0xFF6366F1).withOpacity(opacity * 0.6);
        canvas.drawLine(
          Offset(x - star.size * 2, y),
          Offset(x + star.size * 2, y),
          paint..strokeWidth = 0.5,
        );
        canvas.drawLine(
          Offset(x, y - star.size * 2),
          Offset(x, y + star.size * 2),
          paint..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) => true;
}

class Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}