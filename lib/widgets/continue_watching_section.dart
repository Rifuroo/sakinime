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

  void _resumeWatching(WatchHistoryItem item) {
    // Create initial episode object from history
    final initialEpisode = Episode(
      url: item.episodeId,
      title: item.episodeTitle,
      number: item.episodeNumber.toString(),
      date: DateTime.now().toIso8601String(),
      episodeNumber: item.episodeNumber,
    );

    // ✅ INSTANT RESUME: Push player immediately with what we have
    // The player will fetch the full list in background if needed
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AnimeVideoPlayer(
          episodeToLoad: initialEpisode,
          animeId: item.animeId,
          animeTitle: item.animeTitle,
          allEpisodes: [initialEpisode], // Player will background-load the rest
          animePoster: item.animePoster,
        ),
      ),
    );
    
    // Optional: Pre-fetch details in background to warm up cache / history migration
    _preFetchDetail(item);
  }

  Future<void> _preFetchDetail(WatchHistoryItem item) async {
    try {
      final animeService = AnimeService();
      await animeService.getAnimeDetail(item.animeId);
      // No need to do anything with result here, it helps migrate ID if needed
    } catch (_) {}
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFFF59E0B),
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
                      color: const Color(0xFFF59E0B),
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
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFFF59E0B),
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
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF59E0B),
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
        color: const Color(0xFF18181B), // Matches React Native #18181B (Zinc 900)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                                  color: Colors.white.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.white24,
                                    size: 32,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white24,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white.withValues(alpha: 0.1),
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
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                        child: LinearProgressIndicator(
                          value: item.progressPercentage,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    // Play button overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
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
                        color: const Color(0xFFF59E0B),
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
