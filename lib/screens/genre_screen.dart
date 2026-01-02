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
    if (_scrollController.hasClients) {
      final threshold = MediaQuery.of(context).size.height * 0.8;
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - threshold) {
        _loadMore();
      }
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
          // Main Content
          Consumer<AnimeProvider>(
            builder: (context, provider, _) {
              return CustomScrollView(
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

                  // Genre Pills
                  if (provider.isLoadingGenres)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    )
                  else ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _GenreHeaderDelegate(
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0A0A).withOpacity(0.8),
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(0xFF1E293B).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            child: BackdropFilter(
                              filter: ColorFilter.mode(
                                Colors.black.withOpacity(0.2),
                                BlendMode.darken,
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                itemCount: provider.genres.length,
                                itemBuilder: (context, index) {
                                  final genre = provider.genres[index];
                                  final genreId = (genre['id'] ?? genre['genreId'] ?? '').toString();
                                  final genreName = (genre['name'] ?? genre['title'] ?? 'Unknown').toString();
                                  if (genreId.isEmpty) return const SizedBox();
                                  final isSelected = selectedGenre == genreId;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () => _selectGenre(genreId, genreName),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: isSelected ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]) : null,
                                          color: isSelected ? null : const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            genreName,
                                            style: GoogleFonts.poppins(
                                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (selectedGenre == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('Select a genre to browse', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                        ),
                      )
                    else ...[
                      // Pagination Info
                      if (provider.genreAnimes.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Text(
                              'Page ${provider.currentPage}/${provider.totalPages} • ${provider.genreAnimes.length} anime',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ),

                      if (provider.isLoading && provider.genreAnimes.isEmpty)
                        const SliverToBoxAdapter(child: LoadingShimmer())
                      else if (provider.genreAnimes.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('No anime found', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)))),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 20,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= provider.genreAnimes.length) {
                                  return const LoadingCard();
                                }
                                return AnimeCard(anime: provider.genreAnimes[index]);
                              },
                              childCount: provider.genreAnimes.length + (provider.isLoadingMore ? 2 : 0),
                            ),
                          ),
                        ),

                        // Footer and Load More status
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: provider.isLoadingMore
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
                                : !provider.hasMorePages
                                    ? Center(child: Text('All anime loaded', style: GoogleFonts.poppins(color: const Color(0xFF818CF8))))
                                    : const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              );
            },
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

class _GenreHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _GenreHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
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