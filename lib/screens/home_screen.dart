import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/anime_provider.dart';
import '../providers/source_provider.dart';
import '../models/anime_model.dart';
import '../widgets/anime_card.dart';
import '../widgets/continue_watching_section.dart';
import 'search_screen.dart';
import '../widgets/hero_banner_carousel.dart';
import 'home_collection_screen.dart';
import '../constants/app_colors.dart';
import '../utils/platform_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _headerOpacity = ValueNotifier(0.0);
  bool _isLoading = true;

  // Desktop detection for layout adjustments
  bool get _isDesktop => PlatformUtils.isDesktop;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 🆕 LISTEN FOR SOURCE CHANGES
    _setupSourceListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _setupSourceListener() {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    provider.addListener(() {
      // Check if data was just cleared (source changed)
      if (provider.homeRecentEpisodes.isEmpty &&
          provider.homeOngoing.isEmpty &&
          !_isLoading) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
            });
            // Scroll to top
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            _fetchData();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerOpacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Interpolate opacity 0->1 between scroll offset 0 and 100
    double offset = _scrollController.offset;
    double opacity = (offset / 100).clamp(0.0, 1.0);
    if (_headerOpacity.value != opacity) {
      _headerOpacity.value = opacity;
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Provider.of<AnimeProvider>(context, listen: false)
        .fetchHomeSections();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    // Force refresh on pull-to-refresh
    await Provider.of<AnimeProvider>(context, listen: false)
        .fetchHomeSections(forceRefresh: true);
    if (mounted) setState(() => _isLoading = false);
  }

  void _openSeeAll(HomeCollectionType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HomeCollectionScreen(type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Constants matching HomeScreen.js
    // Using AppColors.background

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer:
          _buildSidebarDrawer(), // Keeping existing drawer logic if available, or placeholder
      body: Stack(
        children: [
          // Content
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: AppColors.cardBg,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 16,
                            bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Header
                            _buildMainHeader(),

                            // Data Sections
                            Consumer<AnimeProvider>(
                              builder: (context, provider, _) {
                                if (_isLoading &&
                                    provider.homeRecentEpisodes.isEmpty) {
                                  return _buildSkeletonLoader();
                                }

                                return Column(
                                  children: [
                                    // 🆕 Source Switcher
                                    _buildSourceSwitcher(),

                                    // Hero Banner Carousel
                                    if (provider.isHiAnime &&
                                        provider.homeMostFavorite.isNotEmpty)
                                      HeroBannerCarousel(
                                        heroAnime: provider.homeMostFavorite
                                            .take(5)
                                            .toList(),
                                      ),
                                    if (!provider.isHiAnime &&
                                        provider.homeOngoing.isNotEmpty)
                                      HeroBannerCarousel(
                                        heroAnime: provider.homeOngoing
                                            .take(5)
                                            .toList(),
                                      ),

                                    // Hero Discover Card
                                    _buildHeroCard(),

                                    // Continue Watching
                                    const ContinueWatchingSection(),

                                    // HiAnime Sections
                                    if (provider.isHiAnime) ...[
                                      if (provider.homeMostFavorite.isNotEmpty)
                                        _buildSection(
                                          title: '🎯 Spotlight',
                                          subtitle: 'Top pinned anime',
                                          data: provider.homeMostFavorite,
                                          type: HomeCollectionType.mostFavorite,
                                        ),
                                      if (provider.homeTopAiring.isNotEmpty)
                                        _buildSection(
                                          title: '🔥 Trending Now',
                                          subtitle: 'Currently popular',
                                          data: provider.homeTopAiring,
                                          type: HomeCollectionType.topAiring,
                                        ),
                                      if (provider
                                          .homeRecentEpisodes.isNotEmpty)
                                        _buildSection(
                                          title: '⚡ Latest Episodes',
                                          subtitle: 'Freshly updated',
                                          data: provider.homeRecentEpisodes,
                                          type:
                                              HomeCollectionType.recentEpisodes,
                                        ),
                                      if (provider.homeRecentAdded.isNotEmpty)
                                        _buildSection(
                                          title: '✨ New Added',
                                          subtitle: 'Just arrived',
                                          data: provider.homeRecentAdded,
                                          type: HomeCollectionType.recentAdded,
                                        ),
                                      if (provider.homeMostPopular.isNotEmpty)
                                        _buildSection(
                                          title: '👑 Most Popular',
                                          subtitle: 'Community favorites',
                                          data: provider.homeMostPopular,
                                          type: HomeCollectionType.mostPopular,
                                        ),
                                    ] else ...[
                                      // Indo Sections
                                      if (provider.homeOngoing.isNotEmpty)
                                        _buildSection(
                                          title: '🔥 Ongoing Anime',
                                          subtitle: 'Recently aired episodes',
                                          data: provider.homeOngoing,
                                          type:
                                              HomeCollectionType.recentEpisodes,
                                        ),
                                      if (provider.homeComplete.isNotEmpty)
                                        _buildSection(
                                          title: '✅ Completed',
                                          subtitle: 'Finished series',
                                          data: provider.homeComplete,
                                          type: HomeCollectionType.recentAdded,
                                        ),
                                      if (provider.homeMovie.isNotEmpty)
                                        _buildSection(
                                          title: '🎬 Movies',
                                          subtitle: 'Anime feature films',
                                          data: provider.homeMovie,
                                          type: HomeCollectionType.recentAdded,
                                        ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Blur Header (Mobile Only - Desktop has sidebar)
          if (!_isDesktop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _headerOpacity,
                builder: (context, opacity, child) {
                  if (opacity == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: opacity,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: AppColors.background.withValues(alpha: 0.7),
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 8,
                            bottom: 12,
                            left: 20,
                            right: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Builder(
                                builder: (headerContext) => GestureDetector(
                                  onTap: () =>
                                      Scaffold.of(headerContext).openDrawer(),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.menu,
                                            size: 18, color: Colors.white),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Sakinime',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SearchScreen())),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.search,
                                      size: 20, color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0)
          .copyWith(bottom: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Badge Glow
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]),
                  ),
                  const Icon(Icons.menu_rounded, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sukinime',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // liveDot
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'Your anime universe',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.search_rounded,
                  size: 22, color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0)
          .copyWith(bottom: 24),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            const Color(0xFFF97316),
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Pattern Circles
          Positioned(
            top: -20,
            right: -20,
            child: _buildPatternCircle(),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: _buildPatternCircle(),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 28, color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Curated anime collection crafted just for you',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 18, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCircle() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Anime> data,
    required HomeCollectionType type,
    bool isLoading = false,
  }) {
    if (!isLoading && data.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0)
                .copyWith(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (!isLoading)
                  GestureDetector(
                    onTap: () => _openSeeAll(type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'See All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 210, // Match AnimeCard height
            child: isLoading
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _buildCardShimmer(),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return AnimeCard(anime: data[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E2C),
      highlightColor: const Color(0xFF2A2A35),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildCarouselShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E2C),
        highlightColor: const Color(0xFF2A2A35),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
            3,
            (index) => Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  height: 200,
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFF1E1E2C),
                    highlightColor: const Color(0xFF2A2A35),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                )),
      ),
    );
  }

  // Placeholder for Drawer - assuming it exists or handled by framework
  Widget _buildSourceSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0)
          .copyWith(bottom: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Consumer<SourceProvider>(
        builder: (context, sourceProvider, _) {
          return Row(
            children: [
              _buildSourceChip('HiAnime', AnimeSource.hianime, sourceProvider),
              _buildSourceChip(
                  'OtakuDesu', AnimeSource.otakudesu, sourceProvider),
              _buildSourceChip(
                  'Kuramanime', AnimeSource.kuramanime, sourceProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSourceChip(
      String label, AnimeSource source, SourceProvider provider) {
    final isSelected = provider.currentSource == source;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setSource(source);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSidebarDrawer() {
    // Return null if handled by a parent scaffold or if we want default drawer
    // The original file had logic for this. For now returning null to avoid errors
    // if dependencies missing, but using existing openDrawer calls.
    return null;
  }
}
