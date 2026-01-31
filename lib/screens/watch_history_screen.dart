// screens/watch_history_screen.dart - Watch History Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../services/watch_history_service.dart';
import '../services/anime_service.dart';
import '../widgets/anime_video_player.dart';
import '../models/anime_model.dart';
import '../constants/app_colors.dart';


class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WatchHistoryItem> _allHistory = [];
  List<WatchHistoryItem> _continueWatching = [];
  List<WatchHistoryItem> _recentAnime = [];
  Map<String, dynamic> _watchStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWatchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // Progressive loading - load from top to bottom
      
      // 1. Watch Stats (shows first - small data)
      try {
        _watchStats = await WatchHistoryService.getWatchStats();
        if (mounted) setState(() {}); // Update UI immediately
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to load watch stats: $e');
      }
      
      // 2. Continue Watching (priority - user wants to resume)
      try {
        _continueWatching = await WatchHistoryService.getContinueWatching(limit: 20);
        if (mounted) setState(() {}); // Update UI immediately
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to load continue watching: $e');
      }
      
      // 3. Recent Anime (second tab)
      try {
        _recentAnime = await WatchHistoryService.getRecentAnime(limit: 15);
        if (mounted) setState(() {}); // Update UI immediately
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to load recent anime: $e');
      }
      
      // 4. All History (last - largest dataset)
      try {
        _allHistory = await WatchHistoryService.getWatchHistory();
        if (mounted) setState(() {}); // Update UI immediately
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to load all history: $e');
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load watch history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Watch History',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to clear all watch history? This action cannot be undone.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await WatchHistoryService.clearHistory();
      _loadWatchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch history cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _resumeWatching(WatchHistoryItem item) async {
    // Show a small loading indicator if needed or just handle it silently
    // since we already have basic item data. 
    // But for next/prev episodes, we need the full list.
    
    try {
      // Create a temporary episode object from history if fetch fails
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
      if (kDebugMode) print('Error resuming from history: $e');
      
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          'Watch History',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        actions: [
          if (!_isLoading && _allHistory.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: 'Clear History',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Continue'),
            Tab(text: 'Recent'),
            Tab(text: 'All History'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContinueWatchingTab(),
                      _buildRecentAnimeTab(),
                      _buildAllHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading watch history...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_watchStats.isEmpty) return const SizedBox.shrink();

    final totalEpisodes = _watchStats['totalEpisodes'] ?? 0;
    final completedEpisodes = _watchStats['completedEpisodes'] ?? 0;
    final uniqueAnime = _watchStats['uniqueAnime'] ?? 0;
    final totalWatchTime = _watchStats['totalWatchTime'] as Duration? ?? Duration.zero;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Watch Statistics',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Episodes',
                  '$totalEpisodes',
                  Icons.play_circle_outline,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  '$completedEpisodes',
                  Icons.check_circle_outline,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Anime',
                  '$uniqueAnime',
                  Icons.movie_outlined,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Watch Time',
                  _formatWatchTime(totalWatchTime),
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatWatchTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildContinueWatchingTab() {
    if (_continueWatching.isEmpty) {
      return _buildEmptyState(
        'No episodes to continue',
        'Episodes you\'ve partially watched will appear here',
        Icons.play_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _continueWatching.length,
      itemBuilder: (context, index) {
        final item = _continueWatching[index];
        return _buildHistoryCard(item, showProgress: true);
      },
    );
  }

  Widget _buildRecentAnimeTab() {
    if (_recentAnime.isEmpty) {
      return _buildEmptyState(
        'No recent anime',
        'Anime you\'ve recently watched will appear here',
        Icons.history,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentAnime.length,
      itemBuilder: (context, index) {
        final item = _recentAnime[index];
        return _buildAnimeCard(item);
      },
    );
  }

  Widget _buildAllHistoryTab() {
    if (_allHistory.isEmpty) {
      return _buildEmptyState(
        'No watch history',
        'Your watch history will appear here as you watch episodes',
        Icons.history,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allHistory.length,
      itemBuilder: (context, index) {
        final item = _allHistory[index];
        return _buildHistoryCard(item, showProgress: true);
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(WatchHistoryItem item, {bool showProgress = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 80,
                    child: item.animePoster != null
                        ? CachedNetworkImage(
                            imageUrl: item.animePoster!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white24,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.animeTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.episodeTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Episode ${item.episodeNumber}',
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Completed',
                                style: GoogleFonts.inter(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (showProgress) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: item.progressPercentage,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.isCompleted ? Colors.green : AppColors.primary,
                                ),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.progressText,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatLastWatched(item.lastWatched),
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action button
                IconButton(
                  onPressed: () {
                    // TODO: Show options (remove from history, etc.)
                  },
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeCard(WatchHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 80,
                    child: item.animePoster != null
                        ? CachedNetworkImage(
                            imageUrl: item.animePoster!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white24,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.animeTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last watched: ${item.episodeTitle}',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatLastWatched(item.lastWatched),
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastWatched(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

