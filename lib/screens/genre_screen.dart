// screens/genre_screen.dart - Modern UI with Pagination
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../providers/anime_provider.dart';
import '../widgets/anime_card.dart';
import '../widgets/loading_shimmer.dart';

class GenreScreen extends StatefulWidget {
  const GenreScreen({super.key});

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> with TickerProviderStateMixin {
  String? selectedGenre;
  String? selectedGenreName;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _starController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _starController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _fadeController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) print('GenreScreen: Fetching genres...');
      Provider.of<AnimeProvider>(context, listen: false).fetchGenres();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (selectedGenre == null) return;
    
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    if (!provider.isLoading && !provider.isLoadingMore && provider.hasMorePages) {
      if (kDebugMode) print('Loading more genre anime: page ${provider.currentPage + 1}');
      provider.fetchAnimeByGenre(selectedGenre!, page: provider.currentPage + 1);
    }
  }

  void _selectGenre(String genreId, String genreName) {
    if (kDebugMode) print('Selected genre: $genreName ($genreId)');
    setState(() {
      selectedGenre = genreId;
      selectedGenreName = genreName;
    });
    Provider.of<AnimeProvider>(context, listen: false)
        .fetchAnimeByGenre(genreId, page: 1);
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
          CustomScrollView(
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
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
                                  Icons.category_rounded,
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
                                      'Genres',
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
                                      'Browse by category',
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
                    ),
                  ],
                ),
              ),

              // Content
              Consumer<AnimeProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingGenres) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: const Color(0xFF818CF8),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Loading genres...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (provider.genres.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
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
                                      child: const Icon(
                                        Icons.category_outlined,
                                        size: 40,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'No genres available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFCBD5E1),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Unable to load genres',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Provider.of<AnimeProvider>(context, listen: false)
                                        .fetchGenres();
                                  },
                                  icon: const Icon(Icons.refresh, size: 20),
                                  label: Text(
                                    'Try Again',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Genre Pills
                        Container(
                          height: 80,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: provider.genres.length,
                            itemBuilder: (context, index) {
                              final genre = provider.genres[index];
                              
                              final genreId = (genre['id'] ?? genre['genreId'] ?? '').toString();
                              final genreName = (genre['name'] ?? genre['title'] ?? 'Unknown').toString();
                              
                              if (genreId.isEmpty) {
                                if (kDebugMode) print('Skipping genre with no ID: $genre');
                                return const SizedBox();
                              }
                              
                              final isSelected = selectedGenre == genreId;

                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => _selectGenre(genreId, genreName),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF6366F1),
                                                Color(0xFF8B5CF6),
                                              ],
                                            )
                                          : null,
                                      color: isSelected ? null : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF818CF8)
                                            : const Color(0xFF334155),
                                        width: 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF6366F1).withOpacity(0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        genreName,
                                        style: GoogleFonts.poppins(
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Pagination Info
                        if (selectedGenre != null && provider.genreAnimes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Page ${provider.currentPage}/${provider.totalPages} • ${provider.genreAnimes.length} anime',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (provider.hasMorePages)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF10B981).withOpacity(0.2),
                                          const Color(0xFF059669).withOpacity(0.15),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withOpacity(0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_downward,
                                          size: 12,
                                          color: const Color(0xFF34D399),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Scroll for more',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: const Color(0xFF34D399),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        
                        // Anime Grid
                        selectedGenre == null
                            ? SizedBox(
                                height: MediaQuery.of(context).size.height - 300,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        size: 64,
                                        color: const Color(0xFF475569),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Select a genre to browse',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : provider.isLoading && provider.genreAnimes.isEmpty
                                ? const LoadingShimmer()
                                : provider.genreAnimes.isEmpty
                                    ? SizedBox(
                                        height: MediaQuery.of(context).size.height - 300,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search_off,
                                                size: 64,
                                                color: const Color(0xFF475569),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No anime found',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Genre: $selectedGenreName',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        controller: _scrollController,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.65,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 20,
                                        ),
                                        itemCount: provider.genreAnimes.length + 
                                                  (provider.isLoadingMore ? 2 : 0),
                                        itemBuilder: (context, index) {
                                          if (index >= provider.genreAnimes.length) {
                                            return const LoadingCard();
                                          }
                                          return AnimeCard(
                                            anime: provider.genreAnimes[index],
                                          );
                                        },
                                      ),
                        
                        // Loading More / End Indicator
                        if (selectedGenre != null && provider.genreAnimes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: provider.isLoadingMore
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: const Color(0xFF818CF8),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'Loading page ${provider.currentPage + 1}...',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  )
                                : !provider.hasMorePages
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF6366F1).withOpacity(0.15),
                                              const Color(0xFF8B5CF6).withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFF6366F1).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              color: const Color(0xFF818CF8),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'All anime loaded (${provider.genreAnimes.length} total)',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: const Color(0xFF818CF8),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(),
                          ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _starController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E293B),
      ),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: const Color(0xFF818CF8),
          ),
        ),
      ),
    );
  }
}

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