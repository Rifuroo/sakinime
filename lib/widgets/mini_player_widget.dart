import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart'; 
import '../providers/global_player_provider.dart';
import '../utils/platform_utils.dart';
import '../utils/navigator_key.dart';
import 'anime_video_player.dart';
import 'video_player_subtitle_overlay.dart';

class MiniPlayerWidget extends StatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  // Position state (null means use default bottom-right)
  double? _left;
  double? _top;
  double? _right;
  double? _bottom;

  @override
  void initState() {
    super.initState();
    // Set default initial position
    _resetPosition();
  }

  void _resetPosition() {
    _right = PlatformUtils.isDesktop ? 20.0 : 12.0;
    _bottom = PlatformUtils.isDesktop ? 20.0 : 90.0;
    _left = null;
    _top = null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalPlayerProvider>(
      builder: (context, player, child) {
        if (!player.isInitialized || player.currentEpisode == null || player.isFullPlayerActive) {
          return const SizedBox.shrink();
        }

        final width = PlatformUtils.isDesktop ? 320.0 : null; // Fixed width
        final height = PlatformUtils.isDesktop ? 180.0 : 70.0;

        return Positioned(
          left: _left,
          top: _top,
          right: _right,
          bottom: _bottom,
          width: width,
          height: height,
          child: GestureDetector(
            onPanStart: (details) {
               // Lock position to absolute coordinates on start drag
               if (_left == null && context.mounted) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  // Use localToGlobal to find where we are relative to the Screen/Stack
                  // Assuming Stack is full screen in main.dart
                  final pos = box.localToGlobal(Offset.zero);
                  setState(() {
                    _left = pos.dx;
                    _top = pos.dy;
                    _right = null;
                    _bottom = null;
                  });
               }
            },
            onPanUpdate: (details) {
              final screenSize = MediaQuery.of(context).size;
              // MiniPlayer dimensions
              final w = width ?? 300.0; // Fallback for mobile if width is null
              final h = height;

              setState(() {
                _left = ((_left ?? 0) + details.delta.dx).clamp(0.0, screenSize.width - w);
                _top = ((_top ?? 0) + details.delta.dy).clamp(0.0, screenSize.height - h);
                _right = null;
                _bottom = null;
              });
            },
            onTap: () {
               if (player.currentEpisode != null && player.currentAnimeId != null) {
                 navigatorKey.currentState?.push(
                   MaterialPageRoute(
                     builder: (context) => AnimeVideoPlayer(
                       episodeToLoad: player.currentEpisode!,
                       animeId: player.currentAnimeId!,
                       animeTitle: player.currentAnimeTitle ?? 'Anime',
                       animePoster: player.currentAnimePoster,
                     ),
                   ),
                 );
               }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1f3a),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    // Thumbnail / Video
                    Expanded(
                      flex: PlatformUtils.isDesktop ? 1 : 0,
                      child: SizedBox(
                        width: PlatformUtils.isDesktop ? null : 120,
                        height: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                              if (player.currentAnimePoster != null)
                              CachedNetworkImage(
                                imageUrl: player.currentAnimePoster!,
                                fit: BoxFit.cover,
                              ),
                            // Overlay Video if playing
                            if (player.isInitialized)
                              FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                  width: (player.controller.player.state.width ?? 0) > 0 ? (player.controller.player.state.width ?? 1280).toDouble() : 1280,
                                  height: (player.controller.player.state.height ?? 0) > 0 ? (player.controller.player.state.height ?? 720).toDouble() : 720,
                                  child: Video(
                                      controller: player.controller,
                                      controls: (state) => const SizedBox(),
                                  ),
                                  ),
                              ),

                            // SUBTITLES
                            if (player.currentSubtitle.isNotEmpty)
                              VideoPlayerSubtitleOverlay(
                                subtitleText: player.currentSubtitle,
                                isPip: true, // Use PiP mode for scaling
                                fontSize: 16,
                                bottomOffset: 10,
                              ),
                            
                            // Desktop Controls Overlays (Pause/Close)
                            if (PlatformUtils.isDesktop)
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Row(
                                  children: [
                                    _buildCircleButton(
                                      icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      onTap: player.togglePlay,
                                    ),
                                    const SizedBox(width: 5),
                                    _buildCircleButton(
                                      icon: Icons.close_rounded,
                                      onTap: () => player.clearCurrentEpisode(),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Title for Mobile (Hidden on Desktop Draggable 16:9 view usually, but we can show overlay)
                    if (!PlatformUtils.isDesktop)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              player.currentAnimeTitle ?? 'Anime',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Episode ${player.currentEpisode?.number ?? '?'}',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (!PlatformUtils.isDesktop)
                    // Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: player.togglePlay,
                          icon: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            player.pause();
                            // Optional: clearCurrentEpisode()
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
