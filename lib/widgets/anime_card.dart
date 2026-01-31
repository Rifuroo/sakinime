import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/anime_model.dart';
import '../screens/detail_anime_screen.dart';
import '../constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';
import 'anime_preview_dialog.dart';

class AnimeCard extends StatefulWidget {
  final Anime anime;
  final double? width;
  final VoidCallback? onTap;

  const AnimeCard({
    super.key,
    required this.anime,
    this.width,
    this.onTap,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fast press feel
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressIn(TapDownDetails _) {
    _controller.forward();
  }

  void _handlePressOut(TapUpDetails _) {
    _controller.reverse();
  }

  void _handleCancel() {
    _controller.reverse();
  }

  void _showPreview() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AnimePreviewDialog(anime: widget.anime),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using centralized AppColors
    
    // Width logic: default 140 if not provided
    final cardWidth = widget.width ?? 140.0;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handlePressIn,
        onTapUp: _handlePressOut,
        onTapCancel: _handleCancel,
        onLongPress: _showPreview,
        onTap: () {
            if (widget.onTap != null) {
                widget.onTap!();
            } else {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailAnimeScreen(animeId: widget.anime.id),
                  ),
                );
            }
        },
        child: Container(
          width: cardWidth,
          margin: const EdgeInsets.only(bottom: 8),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster Image
                  CachedNetworkImage(
                    imageUrl: widget.anime.poster,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 500),
                    httpHeaders: const {
                      'Referer': 'https://hianime.to/',
                      'User-Agent': 'Mozilla/5.0',
                    },
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: const Color(0xFF1E1E2C),
                      highlightColor: const Color(0xFF2A2A35),
                      child: Container(color: Colors.white10),
                    ),
                    errorWidget: (context, url, error) => Container(
                        color: AppColors.cardBg,
                        child: const Icon(Icons.broken_image, color: Colors.white24,),
                    ),
                  ),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.cardGradient,
                        stops: const [0.4, 0.7, 1.0], // Matching locations [0.4, 0.7, 1.0]
                      ),
                    ),
                  ),

                  // Rating Badge (Top Left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 10, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            widget.anime.rating ?? 'N/A',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Anime Info (Bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.anime.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.28, // 18px line height / 14px font size ~= 1.28
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.anime.type ?? 'TV'} ${widget.anime.totalEpisodes != null ? '• ${widget.anime.totalEpisodes} Ep' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.textSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
