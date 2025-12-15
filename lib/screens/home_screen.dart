// screens/home_screen.dart - Premium Enhanced UI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../providers/anime_provider.dart';
import '../models/anime_model.dart';
import '../widgets/anime_card.dart';
import '../widgets/search_screen.dart';
import '../widgets/continue_watching_section.dart';
import 'home_collection_screen.dart';
import 'watch_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _fadeController;
  late AnimationController _starController;
  late Animation<double> _fadeAnimation;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _starController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _controllersInitialized = true;
    _fadeController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnimeProvider>(context, listen: false).fetchHomeSections();
    });
  }

  Future<void> _refresh() async {
    AnimeCard.clearCache();
    await Provider.of<AnimeProvider>(context, listen: false).fetchHomeSections();
  }

  void _openSidebarCategory(HomeSidebarCategory category) {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    provider.fetchSidebarCategory(category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SidebarCategorySheet(category: category),
    );
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
    if (!_controllersInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF818CF8),
          ),
        ),
      );
    }
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: _buildSidebarDrawer(),
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
          RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF818CF8),
            backgroundColor: const Color(0xFF1A1A2E),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Enhanced App Bar
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
                        // Animated Gradient Orbs
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
                        Positioned(
                          bottom: -20,
                          left: -40,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF8B5CF6).withOpacity(0.15),
                                  const Color(0xFF6366F1).withOpacity(0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content - Aligned with AppBar
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 80, 12),
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
                                      Icons.play_circle_filled_rounded,
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
                                          'Sukinime',
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
                                          'Your anime universe',
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
                  actions: [
                    _buildAppBarAction(
                      icon: Icons.menu_rounded,
                      tooltip: 'Kategori Sidebar',
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    _buildAppBarAction(
                      icon: Icons.search_rounded,
                      tooltip: 'Search',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Consumer<AnimeProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildDiscoverHeader(provider),
                          if (provider.homeSectionsError != null)
                            _buildErrorBanner(provider.homeSectionsError!),
                          // Continue Watching Section
                          const ContinueWatchingSection(),
                          for (final section in [
                            {
                              'type': HomeCollectionType.recentEpisodes,
                              'items': provider.homeRecentEpisodes,
                            },
                            {
                              'type': HomeCollectionType.recentAdded,
                              'items': provider.homeRecentAdded,
                            },
                            {
                              'type': HomeCollectionType.topAiring,
                              'items': provider.homeTopAiring,
                            },
                            {
                              'type': HomeCollectionType.mostPopular,
                              'items': provider.homeMostPopular,
                            },
                            {
                              'type': HomeCollectionType.mostFavorite,
                              'items': provider.homeMostFavorite,
                            },
                          ])
                            _buildHomeSection(
                              type: section['type']! as HomeCollectionType,
                              items: section['items']! as List<Anime>,
                              isLoading: provider.isHomeSectionsLoading,
                            ),
                          _buildSidebarCTA(context),
                        ],
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: IconButton(
        onPressed: onTap,
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
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFFE2E8F0),
          ),
        ),
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildDiscoverHeader(AnimeProvider provider) {
    final total = provider.homeRecentEpisodes.length +
        provider.homeRecentAdded.length +
        provider.homeTopAiring.length +
        provider.homeMostPopular.length +
        provider.homeMostFavorite.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withOpacity(0.9),
            const Color(0xFF312E81).withOpacity(0.7),
            const Color(0xFF0A0A0A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFBFDBFE),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover your anime universe',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF8FAFC),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kurasi data dari recent episodes sampai most favorite.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFCBD5F5),
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    const Color(0xFF8B5CF6).withOpacity(0.25),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$total',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEEF2FF),
                    ),
                  ),
                  Text(
                    'anime',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC7D2FE),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeSection({
    required HomeCollectionType type,
    required List<Anime> items,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => _openSeeAll(type),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF475569),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCBD5F5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: _buildSectionList(items, isLoading),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildSectionList(List<Anime> items, bool isLoading) {
    if (isLoading && items.isEmpty) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
            backgroundColor: Colors.white.withOpacity(0.1),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return _buildSectionEmptyState();
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 20),
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: 160,
            child: AnimeCard(anime: items[index]),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemCount: items.length,
    );
  }

  Widget _buildSectionEmptyState() {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF111827),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada data',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEF4444).withOpacity(0.08),
            const Color(0xFF991B1B).withOpacity(0.12),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFCA5A5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFFFCA5A5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCTA(BuildContext context) {
    final bottomNavOverlap = MediaQuery.of(context).padding.bottom + 40;
    return Container(
      margin: EdgeInsets.fromLTRB(20, 8, 20, bottomNavOverlap),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cari koleksi Movies, ONA, OVA, Specials, atau TV?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
          'Buka sidebar untuk akses cepat ke kategori lengkap. Gunakan tombol ini jika bottom nav menutupi daftar.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_open_rounded),
              label: Text(
                'Buka Sidebar',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF111827),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koleksi Sidebar',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pilih kategori untuk menampilkan daftar lengkap.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    // Watch History Menu Item
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Color(0xFF818CF8),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Watch History',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const WatchHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.05),
                      height: 1,
                    ),
                    // Existing category items
                    Expanded(
                      child: ListView.separated(
                        itemCount: HomeSidebarCategory.values.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.05),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final category = HomeSidebarCategory.values[index];
                          return ListTile(
                            title: Text(
                              category.label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _openSidebarCategory(category);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
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
                    Icons.video_library_outlined,
                    size: 40,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'No anime available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCBD5E1),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pull down to refresh',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _starController.dispose();
    super.dispose();
  }
}

class _SidebarCategorySheet extends StatelessWidget {
  final HomeSidebarCategory category;

  const _SidebarCategorySheet({required this.category});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF06060D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Koleksi lengkap sesuai kategori',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: () {
                          Provider.of<AnimeProvider>(context, listen: false)
                              .fetchSidebarCategory(category, forceRefresh: true);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<AnimeProvider>(
                builder: (context, provider, _) {
                  final isLoading = provider.sidebarLoadingCategory == category;
                  final items = provider.getSidebarCollection(category);
                  final error = provider.sidebarErrorMessage;

                  if (isLoading && items.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                      ),
                    );
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off_rounded,
                              color: Colors.white.withOpacity(0.25),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error ?? 'Belum ada data pada kategori ini.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => AnimeCard(anime: items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Animated Starfield Background
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
      
      // Draw cross sparkle
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