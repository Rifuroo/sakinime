// widgets/continue_watching_section.dart - Continue Watching Section
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/watch_history_service.dart';
import '../services/anime_service.dart';
import '../screens/watch_history_screen.dart';
import '../widgets/anime_video_player.dart';
import '../models/anime_model.dart';

class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({super.key});

  @override
  State<ContinueWatchingSection> createState() => _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  List<WatchHistoryItem> _continueWatching = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContinueWatching();
  }

  Future<void> _loadContinueWatching() async {
    try {
      final continueWatching = await WatchHistoryService.getContinueWatching(limit: 10);
      if (mounted) {
        setState(() {
          _continueWatching = continueWatching;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resumeWatching(WatchHistoryItem item) async {
    try {
      // Create a temporary episode object from history
      final initialEpisode = Episode(
        url: item.episodeId,
        title: item.episodeTitle,
        number: item.episodeNumber.toString(),
        date: DateTime.now().toIso8601String(),
        episodeNumber: item.episodeNumber,
      );

      // Fetch full details to get all episodes for the player
      final animeService = AnimeService();
      var fullDetail = await animeService.getAnimeDetail(item.animeId);
      
      // Fallback: If detail fetch fails by ID (common in old history), try searching by title
      if ((fullDetail == null || fullDetail.episodes.isEmpty) && item.animeTitle.isNotEmpty) {
        if (kDebugMode) print('🔍 History fallback: searching for "${item.animeTitle}"');
        final searchResult = await animeService.searchAnime(item.animeTitle);
        if (searchResult.isNotEmpty) {
           // Get detail for the first search result
           final animeId = searchResult[0].id;
           await WatchHistoryService.migrateAnimeId(item.animeId, animeId);
           fullDetail = await animeService.getAnimeDetail(animeId);
        }
      }
      
      List<Episode> allEpisodes = [initialEpisode];
      if (fullDetail != null && fullDetail.episodes.isNotEmpty) {
        allEpisodes = fullDetail.episodes;
      }

      // Find the specific episode in the full list if possible
      Episode episodeToLoad = initialEpisode;
      try {
        episodeToLoad = allEpisodes.firstWhere(
          (e) => e.url == item.episodeId || e.number == item.episodeNumber.toString(),
          orElse: () => initialEpisode,
        );
      } catch (_) {}

      if (!mounted) return;

      // Navigate to video player with full list
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AnimeVideoPlayer(
            episodeToLoad: episodeToLoad,
            animeId: item.animeId,
            animeTitle: item.animeTitle,
            allEpisodes: allEpisodes,
            animePoster: item.animePoster,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Fallback: Navigate with single episode if detail fetch fails
      final fallbackEpisode = Episode(
        url: item.episodeId,
        title: item.episodeTitle,
        number: item.episodeNumber.toString(),
        date: DateTime.now().toIso8601String(),
        episodeNumber: item.episodeNumber,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AnimeVideoPlayer(
            episodeToLoad: fallbackEpisode,
            animeId: item.animeId,
            animeTitle: item.animeTitle,
            allEpisodes: [fallbackEpisode],
            animePoster: item.animePoster,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_continueWatching.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if empty
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFF818CF8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue Watching',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WatchHistoryScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF818CF8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _continueWatching.length,
              itemBuilder: (context, index) {
                final item = _continueWatching[index];
                return _buildContinueWatchingCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFF818CF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue Watching',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                      strokeWidth: 2,
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

  Widget _buildContinueWatchingCard(WatchHistoryItem item) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _resumeWatching(item);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with progress overlay
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: SizedBox(
                        width: double.infinity,
                        child: item.animePoster != null
                            ? CachedNetworkImage(
                                imageUrl: item.animePoster!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.white.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.white24,
                                    size: 32,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white24,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white.withOpacity(0.1),
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    // Progress overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                        child: LinearProgressIndicator(
                          value: item.progressPercentage,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    // Play button overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.animeTitle,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${item.episodeNumber}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF818CF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(item.progressPercentage * 100).toInt()}% watched',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 10,
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
}