import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../providers/anime_provider.dart';
import '../screens/detail_anime_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

// ✅ Poster Cache Manager untuk Schedule
class SchedulePosterCache {
  static final Map<String, String?> _cache = {};
  static final Map<String, int> _failureCount = {};
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://anime-backend-production-8f83.up.railway.app/anime/',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Sukinime/2.0',
    },
  ));

  static DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(milliseconds: 800);
  static int _concurrentRequests = 0;
  static const _maxConcurrentRequests = 3;

  static void clearCache() {
    _cache.clear();
    _failureCount.clear();
    _lastRequestTime = null;
  }

  static String _cleanPosterUrl(String url) {
    if (url.isEmpty || !url.contains('samehadaku')) return url;
    try {
      return url.replaceAll(RegExp(r'-Episode-\d+(\.[a-z]+)$'), r'$1');
    } catch (e) {
      return url;
    }
  }

  static Future<void> _waitForThrottle() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        final waitTime = _minRequestInterval - elapsed;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  static Future<String?> fetchPoster(String animeId) async {
    if (animeId.isEmpty || animeId.trim().isEmpty) return null;

    if (_cache.containsKey(animeId)) {
      return _cache[animeId];
    }

    final failures = _failureCount[animeId] ?? 0;
    if (failures >= 2) {
      _cache[animeId] = null;
      return null;
    }

    while (_concurrentRequests >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _concurrentRequests++;
      await _waitForThrottle();

      final response = await _dio.get('anime/$animeId');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map && responseData['data'] != null) {
          final animeData = responseData['data'];
          String? posterUrl = animeData['poster']?.toString();
          
          if (posterUrl != null && posterUrl.isNotEmpty) {
            posterUrl = _cleanPosterUrl(posterUrl);
            
            if (posterUrl.startsWith('http') && !posterUrl.contains('placehold.co')) {
              _cache[animeId] = posterUrl;
              _failureCount.remove(animeId);
              return posterUrl;
            }
          }
        }
      }
      
      _failureCount[animeId] = failures + 1;
      _cache[animeId] = null;
      return null;
      
    } catch (e) {
      _failureCount[animeId] = failures + 1;
      _cache[animeId] = null;
      if (kDebugMode) print('Schedule poster error for $animeId: $e');
      return null;
    } finally {
      _concurrentRequests--;
    }
  }
}

class _ScheduleScreenState extends State<ScheduleScreen> with TickerProviderStateMixin {
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
      Provider.of<AnimeProvider>(context, listen: false).fetchSchedule();
    });
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
                                  Icons.calendar_today_rounded,
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
                                      'Schedule',
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
                                      'Weekly releases',
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
                  if (provider.isLoading) {
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
                              'Loading schedule...',
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

                  if (provider.schedule.isEmpty) {
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
                                            const Color(0xFFF59E0B).withOpacity(0.15),
                                            const Color(0xFFF59E0B).withOpacity(0.08),
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
                                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.info_outline,
                                        size: 40,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Schedule Unavailable',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF8FAFC),
                                    letterSpacing: -0.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'The schedule data is not available at this time.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                    height: 1.5,
                                    letterSpacing: 0.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Check Home for latest anime',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF475569),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final dayOrder = [
                    'Senin', 'Selasa', 'Rabu', 'Kamis',
                    'Jumat', 'Sabtu', 'Minggu', 'Random'
                  ];

                  final sortedDays = dayOrder
                      .where((day) => provider.schedule.containsKey(day))
                      .toList();

                  if (sortedDays.isEmpty) {
                    final availableDays = provider.schedule.keys.toList();
                    
                    if (availableDays.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No schedule data',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final day = availableDays[index];
                          final animes = provider.schedule[day] ?? [];
                          return _buildDaySection(context, day, animes);
                        },
                        childCount: availableDays.length,
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final day = sortedDays[index];
                        final animes = provider.schedule[day] ?? [];
                        return _buildDaySection(context, day, animes);
                      },
                      childCount: sortedDays.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(BuildContext context, String day, dynamic animes) {
    List animeList = [];
    
    if (animes is List) {
      animeList = animes;
    } else if (animes is Map) {
      if (animes['anime_list'] is List) {
        animeList = animes['anime_list'];
      }
    }

    if (animeList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Header
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 32,
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF8FAFC),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
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
                  '${animeList.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF818CF8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Anime List
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: animeList.length,
            itemBuilder: (context, index) {
              final anime = animeList[index];
              return ScheduleAnimeCard(anime: anime);
            },
          ),
        ),
        
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  void dispose() {
    _starController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

// ✅ Schedule Anime Card dengan Poster Support
class ScheduleAnimeCard extends StatefulWidget {
  final dynamic anime;

  const ScheduleAnimeCard({super.key, required this.anime});

  @override
  State<ScheduleAnimeCard> createState() => _ScheduleAnimeCardState();
}

class _ScheduleAnimeCardState extends State<ScheduleAnimeCard> {
  String? _posterUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  @override
  void didUpdateWidget(ScheduleAnimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSlug = oldWidget.anime['slug']?.toString() ?? '';
    final newSlug = widget.anime['slug']?.toString() ?? '';
    if (oldSlug != newSlug) {
      _loadPoster();
    }
  }

  Future<void> _loadPoster() async {
    final slug = widget.anime['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    if (SchedulePosterCache._cache.containsKey(slug)) {
      if (mounted) {
        setState(() {
          _posterUrl = SchedulePosterCache._cache[slug];
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final posterUrl = await SchedulePosterCache.fetchPoster(slug);

    if (mounted) {
      setState(() {
        _posterUrl = posterUrl;
        _isLoading = false;
      });
    }
  }

  bool _isValidPoster(String? url) {
    return url != null && 
           url.isNotEmpty && 
           url.startsWith('http') &&
           !url.contains('placehold.co') &&
           !url.contains('placeholder');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.anime['anime_name']?.toString() ?? 
                  widget.anime['title']?.toString() ?? 
                  'Unknown';
    
    final slug = widget.anime['slug']?.toString() ?? 
                 widget.anime['animeId']?.toString() ?? 
                 widget.anime['id']?.toString() ?? '';
    
    final hasValidPoster = _isValidPoster(_posterUrl);
    final isCached = SchedulePosterCache._cache.containsKey(slug);

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: slug.isNotEmpty
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DetailAnimeScreen(animeId: slug),
                    ),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasValidPoster)
                        CachedNetworkImage(
                          imageUrl: _posterUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildPlaceholder(false),
                          errorWidget: (context, url, error) => _buildPlaceholder(false),
                        )
                      else
                        _buildPlaceholder(_isLoading && !isCached),
                      
                      // Gradient Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Title
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFF8FAFC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool showLoading) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: showLoading
            ? SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF818CF8),
                  ),
                ),
              )
            : Icon(
                Icons.image_not_supported_rounded,
                size: 36,
                color: Colors.white.withOpacity(0.15),
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