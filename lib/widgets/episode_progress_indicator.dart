// widgets/episode_progress_indicator.dart - Episode Progress Indicator
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/watch_history_service.dart';

class EpisodeProgressIndicator extends StatefulWidget {
  final String animeTitle;
  final String episodeId;
  final int episodeNumber;
  final Widget child;

  const EpisodeProgressIndicator({
    super.key,
    required this.animeTitle,
    required this.episodeId,
    required this.episodeNumber,
    required this.child,
  });

  @override
  State<EpisodeProgressIndicator> createState() => _EpisodeProgressIndicatorState();
}

class _EpisodeProgressIndicatorState extends State<EpisodeProgressIndicator> {
  WatchHistoryItem? _progress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(EpisodeProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    
    try {
      final progress = await WatchHistoryService.getEpisodeProgress(
        widget.animeTitle,
        widget.episodeId,
      );
      
      if (mounted) {
        setState(() {
          _progress = progress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isLoading && _progress != null) ...[
          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
              ),
              child: LinearProgressIndicator(
                value: _progress!.progressPercentage,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progress!.isCompleted ? Colors.green : const Color(0xFF6366F1),
                ),
                minHeight: 3,
              ),
            ),
          ),
          // Completion badge
          if (_progress!.isCompleted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'WATCHED',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Continue watching badge
          if (!_progress!.isCompleted && _progress!.progressPercentage > 0.05)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(_progress!.progressPercentage * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// Simplified version for list items
class EpisodeProgressBadge extends StatefulWidget {
  final String animeTitle;
  final String episodeId;

  const EpisodeProgressBadge({
    super.key,
    required this.animeTitle,
    required this.episodeId,
  });

  @override
  State<EpisodeProgressBadge> createState() => _EpisodeProgressBadgeState();
}

class _EpisodeProgressBadgeState extends State<EpisodeProgressBadge> {
  WatchHistoryItem? _progress;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await WatchHistoryService.getEpisodeProgress(
        widget.animeTitle,
        widget.episodeId,
      );
      
      if (mounted) {
        setState(() => _progress = progress);
      }
    } catch (e) {
      // Ignore errors for badge
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_progress == null) return const SizedBox.shrink();

    if (_progress!.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'WATCHED',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_progress!.progressPercentage > 0.05) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '${(_progress!.progressPercentage * 100).toInt()}%',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}