import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../providers/anime_provider.dart';
import 'package:provider/provider.dart';
import '../models/anime_model.dart';
import '../widgets/anime_video_player.dart';
import 'character_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

const double kBannerHeight = 380.0;

class DetailAnimeScreen extends StatefulWidget {
  final String animeId;

  const DetailAnimeScreen({super.key, required this.animeId});

  @override
  State<DetailAnimeScreen> createState() => _DetailAnimeScreenState();
}

class _DetailAnimeScreenState extends State<DetailAnimeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollNotifier = ValueNotifier(0.0);
  
  bool _isExpanded = false;
  String _epSearch = '';
  String _epSort = 'desc'; 
  int _epPage = 1;
  static const int _epsPerPage = 50;
  bool _isGridMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollNotifier.value = _scrollController.offset;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AnimeProvider>(context, listen: false);
      provider.fetchAnimeDetail(widget.animeId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AnimeProvider>(
        builder: (context, provider, _) {
          final anime = provider.currentAnime;
          final characters = provider.characters;
          
          // Sequential Loading Logic:
          // 1. Banner & General info is shown immediately with shimmer fallbacks
          // 2. Episodes list is shown as soon as anime metadata is available
          // 3. Characters have their own loading state

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: kBannerHeight,
                    pinned: false,
                    stretch: true,
                    backgroundColor: AppColors.background,
                    leading: const SizedBox(),
                    flexibleSpace: FlexibleSpaceBar(
                      background: _buildBanner(anime, provider.isLoading && anime == null),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Desktop Layout Threshold
                              if (constraints.maxWidth > 900) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column: Poster, Actions, Info
                                    SizedBox(
                                      width: 300,
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 60), // Space for floating poster
                                          if (anime != null) ...[
                                            _buildRatingBadge(anime.rating),
                                            const SizedBox(height: 16),
                                            _buildActionRow(anime, provider), // Vertical/Stack action row maybe?
                                            const SizedBox(height: 24),
                                            _buildInfoGridList(anime),
                                            const SizedBox(height: 24),
                                            Text('GENRES', style: _sectionLabelStyle),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: (anime.genres ?? []).map((g) => _buildGenreTag(g)).toList(),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 40),
                                    
                                    // Right Column: Title, Synopsis, Episodes
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 60),
                                            Text(
                                              anime?.title ?? '',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                _buildPill(anime?.type ?? 'TV'),
                                                _buildPill('${anime?.episodes.length ?? 0} Ep'),
                                                if (anime?.status != null) 
                                                  _buildPill(anime!.status!, isAiring: anime.status!.toLowerCase().contains('airing')),
                                              ],
                                            ),
                                            const SizedBox(height: 32),
                                            Text('SYNOPSIS', style: _sectionLabelStyle),
                                            const SizedBox(height: 12),
                                            if (anime == null)
                                              _buildShimmerBlock(height: 100, width: double.infinity)
                                            else
                                              _buildSynopsis(anime.synopsis),
                                            
                                            const SizedBox(height: 32),
                                            
                                            // Episodes Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                  Text('EPISODES (${anime?.episodes.length ?? 0})', style: _sectionLabelStyle),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            
                                            // Controls
                                            _buildEpisodeControls(anime),
                                            const SizedBox(height: 16),
                                            
                                            // For Desktop we might want to just show list here or Grid
                                            // But since sliver list is outside, we need to adapt structure.
                                            // To keep it simple in this refactor, we will put the list inside this column 
                                            // via ShrinkWrap or keep sliver structure but conditional?
                                            // Sliver inside Sliver only works with NestedScrollView.
                                            // Changing strategy: We are in SliverToBoxAdapter. We CANNOT put a SliverList here easily without CustomScrollView.
                                            // So we will use a ListView/GridView shrinkWrap for the desktop right column.
                                            
                                            _buildDesktopEpisodeList(anime, context),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              
                              // Mobile Layout (Existing)
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 60), // Space for floating poster
                                  
                                  // Title
                                  if (anime == null)
                                    _buildShimmerBlock(height: 32, width: 200)
                                  else
                                    Text(
                                      anime.title,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  
                                  // Badges Row
                                  if (anime == null)
                                    Row(children: [_buildShimmerBlock(height: 20, width: 60), const SizedBox(width: 8), _buildShimmerBlock(height: 20, width: 60)])
                                  else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildRatingBadge(anime.rating),
                                      _buildPill(anime.type ?? 'TV'),
                                      _buildPill('${anime.episodes.length} Ep'),
                                      if (anime.status != null) 
                                        _buildPill(anime.status!, isAiring: anime.status!.toLowerCase().contains('airing')),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Action Row
                                  if (anime == null)
                                     _buildActionRowShimmer()
                                  else
                                     _buildActionRow(anime, provider),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Information
                                  Text('INFORMATION', style: _sectionLabelStyle),
                                  const SizedBox(height: 16),
                                  _buildInfoGridList(anime),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Genres
                                  Text('GENRES', style: _sectionLabelStyle),
                                  const SizedBox(height: 16),
                                  if (anime == null)
                                    Wrap(spacing: 8, runSpacing: 8, children: List.generate(3, (_) => _buildShimmerBlock(height: 24, width: 70, radius: 12)))
                                  else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (anime.genres ?? []).map((g) => _buildGenreTag(g)).toList(),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Synopsis
                                  Text('SYNOPSIS', style: _sectionLabelStyle),
                                  const SizedBox(height: 12),
                                  if (anime == null)
                                    _buildShimmerBlock(height: 100, width: double.infinity)
                                  else
                                    _buildSynopsis(anime.synopsis),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Characters
                                  if (characters.isNotEmpty || provider.isLoadingCharacters) ...[
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Text('CHARACTERS', style: _sectionLabelStyle),
                                       ],
                                     ),
                                     const SizedBox(height: 16),
                                     SizedBox(
                                       height: 150,
                                       child: provider.isLoadingCharacters && characters.isEmpty
                                       ? ListView.separated(
                                           scrollDirection: Axis.horizontal,
                                           itemCount: 5,
                                           separatorBuilder: (_, __) => const SizedBox(width: 12),
                                           itemBuilder: (context, index) => _buildShimmerBlock(height: 150, width: 100, radius: 16),
                                         )
                                       : ListView.separated(
                                         scrollDirection: Axis.horizontal,
                                         itemCount: characters.length,
                                         separatorBuilder: (_, __) => const SizedBox(width: 12),
                                         itemBuilder: (context, index) => _buildCharacterCard(characters[index], context),
                                       ),
                                     ),
                                     const SizedBox(height: 32),
                                  ],
                                  
                                  // Studio/Aired Box
                                  Row(
                                    children: [
                                      Expanded(child: _buildInfoBox('STUDIO', anime?.studios)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildInfoBox('AIRED', anime?.aired)),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Episodes Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text('EPISODES (${anime?.episodes.length ?? 0})', style: _sectionLabelStyle),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Controls
                                  _buildEpisodeControls(anime),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lazy Episode List (Only for Mobile)
                  // For Desktop, we rendered it inside the column above
                  _buildMobileEpisodeSliver(anime, MediaQuery.of(context).size.width > 900),

                  // Bottom Padding & Pagination
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildPagination(anime),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
              
              _buildStickyHeader(anime),
              _buildFixedBackButton(context),
            ],
          );
        },
      ),
    );
  }

  // --- Components ---

  TextStyle get _sectionLabelStyle => GoogleFonts.poppins(
    color: AppColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  Widget _buildBanner(AnimeDetail? anime, bool isLoading) {
    if (anime == null || isLoading) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E2C),
        highlightColor: const Color(0xFF2A2A35),
        child: Container(color: Colors.white10),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Banner Image
        CachedNetworkImage(
          imageUrl: anime.bannerImage ?? anime.poster,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 500),
          httpHeaders: const {'Referer': 'https://hianime.to/', 'User-Agent': 'Mozilla/5.0'},
          errorWidget: (_,__,___) => Container(color: AppColors.cardBg),
        ),
        // Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.4), AppColors.background],
               stops: const [0.0, 0.6, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Poster Overlay (Bottom Left)
        Positioned(
          left: 24,
          bottom: 0,
          child: Transform.translate(
            offset: const Offset(0, 40),
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.background, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 12)),
                ],
                color: AppColors.cardBg,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                   imageUrl: anime.poster,
                   fit: BoxFit.cover,
                   fadeInDuration: const Duration(milliseconds: 500),
                   httpHeaders: const {'Referer': 'https://hianime.to/', 'User-Agent': 'Mozilla/5.0'},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBadge(String? rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            rating ?? 'N/A',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, {bool isAiring = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAiring ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAiring ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: isAiring ? AppColors.primary : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionRow(AnimeDetail anime, AnimeProvider provider) {
    return Row(
      children: [
        // Watch Button
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
                if(anime.episodes.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => 
                        AnimeVideoPlayer(
                            episodeToLoad: anime.episodes.first, 
                            animeId: anime.id,
                            animeTitle: anime.title,
                            allEpisodes: anime.episodes,
                            animePoster: anime.poster,
                        )));
                }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
                const SizedBox(width: 8),
                Text('Watch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Utility Buttons
        _buildUtilityBtn(Icons.add_rounded),
        const SizedBox(width: 12),
        _buildUtilityBtn(Icons.download_outlined),
        const SizedBox(width: 12),
        _buildUtilityBtn(Icons.share_outlined),
      ],
    );
  }

  Widget _buildUtilityBtn(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildInfoGridList(AnimeDetail? anime) {
    if (anime == null) {
      return _buildShimmerBlock(height: 200, width: double.infinity, radius: 16);
    }
    final items = [
      {'label': 'JAPANESE', 'value': anime.japanese ?? 'Unknown'},
      {'label': 'SYNONYMS', 'value': anime.synonyms ?? 'None'},
      {'label': 'AIRED', 'value': anime.aired ?? 'Unknown'},
      {'label': 'STATUS', 'value': anime.status ?? 'Unknown'},
      {'label': 'DURATION', 'value': anime.duration ?? '24m'},
      {'label': 'RATING', 'value': anime.rating ?? 'N/A'},
      {'label': 'STUDIOS', 'value': anime.studios ?? 'Unknown'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                    SizedBox(
                        width: 100,
                        child: Text(
                            item['label']!,
                            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                    ),
                    Expanded(
                        child: Text(
                            item['value']!,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                ],
              ),
            );
        }).toList(),
      ),
    );
  }

  Widget _buildGenreTag(String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        genre,
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildSynopsis(String text) {
      // Logic for show more handled by state
      final shortText = text.length > 300 ? '${text.substring(0, 300)}...' : text;
      final display = _isExpanded ? text : shortText;
      
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                  display,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.6),
              ),
              if(text.length > 300)
                  GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                              children: [
                                  Text(_isExpanded ? 'Show Less' : 'Read More', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.primary, size: 16),
                              ],
                          ),
                      ),
                  )
          ],
      );
  }

  Widget _buildCharacterCard(Character character, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CharacterDetailScreen(characterId: character.id, characterName: character.name))),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.cardBg,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
                imageUrl: character.image ?? '',
                fit: BoxFit.cover,
                errorWidget: (_,__,___) => Container(color: AppColors.cardBg),
            ),
            Container(decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87], 
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    stops: const [0.6, 1.0]
                )
            )),
            Positioned(
                bottom: 8, left: 8, right: 8,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(character.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1),
                        Text(character.role ?? 'Main', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10), maxLines: 1),
                    ],
                )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value ?? 'Unknown', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEpisodeControls(AnimeDetail? anime) {
    if (anime == null) return const SizedBox.shrink();
      return Row(
          children: [
              Expanded(
                  child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                          children: [
                              Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: TextField(
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                      decoration: InputDecoration(
                                          hintText: 'Search episode...',
                                          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                                          border: InputBorder.none,
                                          isDense: true,
                                      ),
                                      onChanged: (v) => setState(() { _epSearch = v; _epPage = 1; }),
                                  )
                              )
                          ],
                      ),
                  ),
              ),
              const SizedBox(width: 12),
              // Grid Toggle
              GestureDetector(
                onTap: () => setState(() => _isGridMode = !_isGridMode),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Icon(
                    _isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: () => setState(() => _epSort = _epSort == 'asc' ? 'desc' : 'asc'),
                  child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                          children: [
                              Icon(Icons.sort_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(_epSort == 'asc' ? 'Oldest' : 'Newest', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))
                          ],
                      ),
                  ),
              )
          ],
      );
  }

  Widget _buildDesktopEpisodeList(AnimeDetail? anime, BuildContext context) {
      if (anime == null) return const SizedBox.shrink();
      final filtered = _getFilteredEpisodes(anime);
      final visible = _getVisibleEpisodes(filtered);
      
      if (visible.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: Text('No episodes found', style: GoogleFonts.inter(color: AppColors.textMuted))),
        );
      }
      
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 80,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) => _buildEpisodeGridItem(visible[index], anime, context),
      );
  }

  Widget _buildMobileEpisodeSliver(AnimeDetail? anime, bool isDesktop) {
    if (isDesktop) return const SliverToBoxAdapter(child: SizedBox.shrink());

    if (anime == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: List.generate(3, (index) => _buildShimmerBlock(height: 80, width: double.infinity, radius: 12)),
          ),
        ),
      );
    }

    final filtered = _getFilteredEpisodes(anime);
    final visible = _getVisibleEpisodes(filtered);

    if (visible.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text('No episodes found', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: _isGridMode 
        ? SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEpisodeGridItem(visible[index], anime, context),
              childCount: visible.length,
            ),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEpisodeItem(visible[index], anime, context),
              childCount: visible.length,
            ),
          ),
    );
  }

  List<Episode> _getFilteredEpisodes(AnimeDetail anime) {
    List<Episode> filtered = anime.episodes.where((e) =>
      (e.number).toLowerCase().contains(_epSearch.toLowerCase()) ||
      (e.title ?? '').toLowerCase().contains(_epSearch.toLowerCase())
    ).toList();
    
    filtered.sort((a, b) {
      final nA = double.tryParse(a.number) ?? 0;
      final nB = double.tryParse(b.number) ?? 0;
      return _epSort == 'asc' ? nA.compareTo(nB) : nB.compareTo(nA);
    });
    
    return filtered;
  }

  List<Episode> _getVisibleEpisodes(List<Episode> filtered) {
    final start = (_epPage - 1) * _epsPerPage;
    final end = (start + _epsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  Widget _buildPagination(AnimeDetail? anime) {
    if (anime == null) return const SizedBox.shrink();
    
    final filtered = _getFilteredEpisodes(anime);
    final totalPages = (filtered.length / _epsPerPage).ceil();
    
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
            onPressed: _epPage > 1 ? () => setState(() => _epPage--) : null,
          ),
          Text(
            'Page $_epPage of $totalPages',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
            onPressed: _epPage < totalPages ? () => setState(() => _epPage++) : null,
          )
        ],
      ),
    );
  }

  Widget _buildEpisodeGridItem(Episode ep, AnimeDetail anime, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => 
          AnimeVideoPlayer(episodeToLoad: ep, animeId: anime.id, animeTitle: anime.title, allEpisodes: anime.episodes, animePoster: anime.poster))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: Text(
          ep.number,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(Episode ep, AnimeDetail anime, BuildContext context) {
      return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => 
             AnimeVideoPlayer(episodeToLoad: ep, animeId: anime.id, animeTitle: anime.title, allEpisodes: anime.episodes, animePoster: anime.poster))),
          child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                  children: [
                      // Episode Number (Circular or Box)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ep.number,
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(
                                    'Episode ${ep.number}', 
                                    style: GoogleFonts.inter(
                                      color: Colors.white, 
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w600
                                    ),
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  if (ep.title != null && ep.title!.isNotEmpty)
                                    Text(
                                      ep.title!, 
                                      style: GoogleFonts.inter(
                                        color: AppColors.textMuted, 
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w400
                                      ),
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                              ],
                          ),
                      ),
                      Icon(Icons.play_circle_outline_rounded, color: AppColors.textMuted, size: 20),
                  ],
              ),
          ),
      );
  }

  Widget _buildStickyHeader(AnimeDetail? anime) {
      if (anime == null) return const SizedBox.shrink();
      return ValueListenableBuilder<double>(
          valueListenable: _scrollNotifier,
          builder: (context, offset, child) {
              final opacity = (offset / 200).clamp(0.0, 1.0);
              // Title opacity kicks in later
              final titleOpacity = ((offset - 250) / 100).clamp(0.0, 1.0);
              
              return Container(
                  height: 90,
                  padding: const EdgeInsets.only(top: 30, left: 60, right: 60), // Space for back / share
                  color: AppColors.background.withValues(alpha: opacity * 0.95), // Glass-ish
                  alignment: Alignment.center,
                  child: Opacity(
                      opacity: titleOpacity,
                      child: Text(
                          anime.title,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                  ),
              );
          },
      );
  }

  Widget _buildFixedBackButton(BuildContext context) {
      return Positioned(
          top: 40,
          left: 20,
          child: ValueListenableBuilder<double>(
              valueListenable: _scrollNotifier,
              builder: (context, offset, child) {
                  final opacity = 1.0 - (offset / 50).clamp(0.0, 1.0);
                  
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  clipBehavior: Clip.antiAlias,
                                  child: Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.3 + (1-opacity)*0.7),
                                      ),
                                      child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                                      ),
                                  ),
                              ),
                          ),
                      ],
                  );
              }
          ),
      );
  }

  Widget _buildShimmerBlock({required double height, required double width, double radius = 8}) {
      return Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E2C),
          highlightColor: const Color(0xFF2A2A35),
          child: Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(radius),
              ),
          ),
      );
  }

  Widget _buildActionRowShimmer() {
      return Row(
          children: [
              Expanded(child: _buildShimmerBlock(height: 50, width: double.infinity, radius: 14)),
              const SizedBox(width: 12),
              _buildShimmerBlock(height: 50, width: 50, radius: 14),
          ],
      );
  }


}
