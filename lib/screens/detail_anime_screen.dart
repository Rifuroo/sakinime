// screens/detail_anime_screen.dart - OPTIMIZED (Fetch inside video player)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/anime_provider.dart';
import '../models/anime_model.dart';
import '../widgets/anime_video_player.dart';
import 'character_detail_screen.dart';
import 'character_browser_screen.dart';

class DetailAnimeScreen extends StatefulWidget {
  final String animeId;

  const DetailAnimeScreen({super.key, required this.animeId});

  @override
  State<DetailAnimeScreen> createState() => _DetailAnimeScreenState();
}

class _DetailAnimeScreenState extends State<DetailAnimeScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 50;
  final TextEditingController _episodeSearchController = TextEditingController();
  
  int _displayedEpisodes = 20;
  bool _isLoadingMore = false;
  bool _isExpanded = false;
  bool _showTitle = false;
  String _episodeQuery = '';
  int _currentPage = 1;

  // ✅ Access to video player cache
  // ignore: unused_element
  static Map<String, List<dynamic>> get episodeCache => _internalCache;
  static final Map<String, List<dynamic>> _internalCache = {};

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      print('\n${'='*70}');
      print('DETAIL SCREEN INITIALIZED');
      print('   AnimeId: "${widget.animeId}"');
      print('${'='*70}\n');
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AnimeProvider>(context, listen: false);
      provider.fetchAnimeDetail(widget.animeId);
      provider.fetchCharacters(widget.animeId);
    });
    
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _episodeSearchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final showTitle = _scrollController.offset > 250;
      if (showTitle != _showTitle) {
        setState(() {
          _showTitle = showTitle;
        });
      }
    }
    
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    final shouldPaginate = _shouldUsePagination(provider.currentAnime?.episodes.length ?? 0);
    if (!shouldPaginate &&
        _scrollController.position.pixels >= 
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreEpisodes();
    }
  }

  void _loadMoreEpisodes() {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    final totalEpisodes = provider.currentAnime?.episodes.length ?? 0;
    
    if (_shouldUsePagination(totalEpisodes)) return;
    
    if (_isLoadingMore || _displayedEpisodes >= totalEpisodes) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _displayedEpisodes = (_displayedEpisodes + 20).clamp(0, totalEpisodes);
          _isLoadingMore = false;
        });
      }
    });
  }

  bool _shouldUsePagination(int totalEpisodes) => totalEpisodes > _pageSize;

  void _onEpisodeSearchChanged(String value) {
    setState(() {
      _episodeQuery = value.trim();
      _currentPage = 1;
    });
  }

  void _changePage(int delta, int totalPages) {
    if (totalPages <= 0) return;
    setState(() {
      _currentPage = (_currentPage + delta).clamp(1, totalPages);
    });
  }

  List<Episode> _filterEpisodes(List<Episode> episodes) {
    if (_episodeQuery.isEmpty) return episodes;
    final query = _episodeQuery.toLowerCase();
    return episodes.where((episode) {
      final number = _extractEpisodeNumber(episode).toLowerCase();
      final title = (episode.title ?? '').toLowerCase();
      return number.contains(query) || title.contains(query);
    }).toList();
  }

  // ✅ SIMPLIFIED: Navigate directly to video player
  Future<void> _playEpisode(Episode episode) async {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    
    if (!mounted) return;

    // ✅ Navigate immediately - let video player handle loading
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AnimeVideoPlayer(
          episodeToLoad: episode,
          animeId: provider.currentAnime?.id ?? '',
          animeTitle: provider.currentAnime?.title ?? '',
          allEpisodes: provider.currentAnime?.episodes ?? [],
          animePoster: provider.currentAnime?.poster,
        ),
      ),
    );
    
    // ✅ Refresh UI when returning to detail screen
    if (mounted) {
      setState(() {});
    }
  }

  String _extractEpisodeNumber(Episode episode) {
    // ✅ Priority 1: Use episodeNumber int if available
    if (episode.episodeNumber != null) {
      return episode.episodeNumber.toString();
    }
    
    // ✅ Priority 2: Extract from title or number string
    final text = episode.title ?? episode.number;
    final match = RegExp(r'Episode\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }
    
    // ✅ Fallback: try to parse number field directly
    final numParsed = int.tryParse(episode.number);
    if (numParsed != null) {
      return numParsed.toString();
    }
    
    return episode.number;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Consumer<AnimeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF6366F1),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.currentAnime == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 36,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Anime Not Found',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            provider.fetchAnimeDetail(widget.animeId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final anime = provider.currentAnime!;
          final allEpisodes = anime.episodes;
          final sortedEpisodes = allEpisodes.reversed.toList();
          final filteredEpisodes = _filterEpisodes(sortedEpisodes);
          final usePagination = _shouldUsePagination(filteredEpisodes.length);
          final totalPages = usePagination
              ? (filteredEpisodes.length / _pageSize).ceil().clamp(1, 9999)
              : 1;
          final currentPage = usePagination
              ? _currentPage.clamp(1, totalPages > 0 ? totalPages : 1)
              : 1;
          if (usePagination && currentPage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPage = currentPage;
                });
              }
            });
          }
          final episodesToShow = usePagination
              ? filteredEpisodes
                  .skip((currentPage - 1) * _pageSize)
                  .take(_pageSize)
                  .toList()
              : filteredEpisodes.take(
                  _displayedEpisodes.clamp(0, filteredEpisodes.length),
                ).toList();

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: const Color(0xFF1A1A1A),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _showTitle 
                        ? Colors.transparent 
                        : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                  ),
                ),
                title: AnimatedOpacity(
                  opacity: _showTitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    anime.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: anime.poster,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'Referer': 'https://hianime.to/',
                          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        },
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.white24,
                            size: 48,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.5),
                                const Color(0xFF0F0F0F).withValues(alpha: 0.9),
                                const Color(0xFF0F0F0F),
                              ],
                              stops: const [0.0, 0.5, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoSection(anime),
                      if (anime.genres != null && anime.genres!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildGenreSection(anime.genres!),
                      ],
                      _buildSyncDataSection(provider),
                      const SizedBox(height: 24),
                      Text(
                        'Synopsis',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSynopsisSection(anime.synopsis),
                      const SizedBox(height: 28),
                      _buildCharacterSection(provider, anime.title),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'Episodes',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${allEpisodes.length}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF818CF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (usePagination) ...[
                        _buildEpisodeSearchField(),
                        const SizedBox(height: 12),
                        _buildPaginationControls(
                          currentPage: currentPage,
                          totalPages: totalPages,
                          totalEpisodes: filteredEpisodes.length,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              
              if (episodesToShow.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _episodeQuery.isEmpty
                              ? 'Tidak ada episode pada halaman ini.'
                              : 'Episode dengan nomor "$_episodeQuery" tidak ditemukan.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < episodesToShow.length) {
                          final episode = episodesToShow[index];
                          final episodeNum = _extractEpisodeNumber(episode);
                          return _buildEpisodeCard(episode, episodeNum);
                        }
                        return null;
                      },
                      childCount: episodesToShow.length,
                    ),
                  ),
                ),
              
              if (_isLoadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF6366F1),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeSearchField() {
    return TextField(
      controller: _episodeSearchController,
      keyboardType: TextInputType.number,
      onChanged: _onEpisodeSearchChanged,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: 'Cari nomor episode...',
        hintStyle: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 13,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
        suffixIcon: _episodeQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                onPressed: () {
                  _episodeSearchController.clear();
                  _onEpisodeSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalEpisodes,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halaman $currentPage dari $totalPages',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalEpisodes episode tersedia',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: currentPage > 1 ? () => _changePage(-1, totalPages) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
            IconButton(
              onPressed: currentPage < totalPages ? () => _changePage(1, totalPages) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(AnimeDetail anime) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: anime.info.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSynopsisSection(String synopsis) {
    final maxLines = 4;
    final needsExpansion = synopsis.split('\n').length > maxLines || synopsis.length > 300;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          synopsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white70,
            height: 1.6,
            letterSpacing: -0.1,
          ),
          maxLines: _isExpanded ? null : maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (needsExpansion) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Text(
                  _isExpanded ? 'Show Less' : 'Read More',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF818CF8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF818CF8),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenreSection(List<String> genres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genres',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genres.map((genre) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                genre,
                style: GoogleFonts.inter(
                  color: const Color(0xFF818CF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCharacterSection(AnimeProvider provider, String animeTitle) {
    if (provider.isLoadingCharacters && provider.characters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.characters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'No character information available for this anime.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Characters',
          trailing: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CharacterBrowserScreen(
                    animeId: widget.animeId,
                    animeTitle: animeTitle,
                  ),
                ),
              );
            },
            child: Text(
              'View All',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF818CF8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: provider.characters.length > 10 ? 10 : provider.characters.length,
            itemBuilder: (context, index) {
              return _buildCharacterCard(provider.characters[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> character) {
    final name = character['name'] ?? 'Unknown';
    final String? image = character['imageUrl'] ?? character['image'] ?? character['poster'] ?? character['img'] ?? character['thumbnail'];
    final id = character['id'];
    final role = character['role'];

    return GestureDetector(
      onTap: () {
        if (id != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CharacterDetailScreen(
                characterId: id,
                characterName: name,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Icon(Icons.person, color: Color(0xFF475569)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E293B),
                        child: const Icon(Icons.person, color: Color(0xFF475569)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (role != null)
              Text(
                role,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF818CF8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDataSection(AnimeProvider provider) {
    if (provider.isSyncDataLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
        ),
      );
    }

    final syncData = provider.syncData;
    if (syncData == null || (syncData['mal_id'] == null && syncData['anilist_id'] == null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'External Links',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (syncData['mal_id'] != null)
              _buildExternalLinkChip(
                'MyAnimeList',
                'https://myanimelist.net/anime/${syncData['mal_id']}',
                const Color(0xFF2E51A2),
              ),
            if (syncData['mal_id'] != null && syncData['anilist_id'] != null)
              const SizedBox(width: 10),
            if (syncData['anilist_id'] != null)
              _buildExternalLinkChip(
                'AniList',
                'https://anilist.co/anime/${syncData['anilist_id']}',
                const Color(0xFF02A9FF),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildExternalLinkChip(String label, String url, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode, String episodeNum) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playEpisode(episode),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8), // ✅ Reduced from 10
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32, // ✅ Reduced from 36
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: const Color(0xFF818CF8),
                    size: 18, // ✅ Reduced from 20
                  ),
                ),
                const SizedBox(height: 6), // ✅ Reduced from 8
                Flexible( // ✅ Added Flexible
                  child: Text(
                    episodeNum,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12, // ✅ Reduced from 13
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1, // ✅ Added
                    overflow: TextOverflow.ellipsis, // ✅ Added
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // ✅ Check if episode is cached
  // ignore: unused_element
  bool _isEpisodeCached(String episodeUrl) {
    return _internalCache.containsKey(widget.animeId) && 
           _internalCache[widget.animeId]!.contains(episodeUrl);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}