import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/zoro_service.dart';
import '../models/anime_model.dart';
import '../constants/app_colors.dart';
import '../screens/detail_anime_screen.dart';

class AnimePreviewDialog extends StatefulWidget {
  final Anime anime;

  const AnimePreviewDialog({super.key, required this.anime});

  @override
  State<AnimePreviewDialog> createState() => _AnimePreviewDialogState();
}

class _AnimePreviewDialogState extends State<AnimePreviewDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  Anime? _fullAnime;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200), // FASTER
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    // Check if we need more data
    final hasCompleteData = widget.anime.synopsis != null && 
                           widget.anime.synopsis!.isNotEmpty &&
                           widget.anime.genres != null && 
                           widget.anime.genres!.isNotEmpty;
                           
    if (!hasCompleteData) {
      _fetchFullDetails();
    }
  }

  Future<void> _fetchFullDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final zoro = ZoroService();
      final data = await zoro.getInfo(widget.anime.id);
      
      if (data != null && mounted) {
        final detail = AnimeDetail.fromJson(data);
        setState(() {
          _fullAnime = Anime(
            id: detail.id,
            title: detail.title,
            poster: detail.poster,
            synopsis: detail.synopsis,
            genres: detail.genres,
            rating: detail.rating,
            type: detail.type,
            status: detail.status,
            totalEpisodes: detail.episodes.length,
            bannerImage: detail.bannerImage,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToDetail() {
    Navigator.of(context).pop(); // Close dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailAnimeScreen(animeId: widget.anime.id),
      ),
    );
  }

  Map<String, String> _getImageHeaders() {
    return {
      'Referer': 'https://hianime.to/',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayAnime = _fullAnime ?? widget.anime;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Reduced for performance
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E293B).withValues(alpha: 0.95),
                    const Color(0xFF0F172A).withValues(alpha: 0.98),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Background poster with blur
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: displayAnime.poster,
                        fit: BoxFit.cover,
                        httpHeaders: _getImageHeaders(),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Reduced for performance
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with close button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Preview',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Poster and basic info
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Poster
                                    Container(
                                      width: 120,
                                      height: 170,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: displayAnime.poster,
                                          fit: BoxFit.cover,
                                          httpHeaders: _getImageHeaders(),
                                          placeholder: (context, url) => Shimmer.fromColors(
                                            baseColor: const Color(0xFF1E1E2C),
                                            highlightColor: const Color(0xFF2A2A35),
                                            child: Container(color: Colors.white10),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: const Color(0xFF1A1A1A),
                                            child: Icon(
                                              Icons.image_not_supported_rounded,
                                              color: Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Title and quick info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayAnime.title,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1.2,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Status and Latest Episode
                                          if (displayAnime.status != null || displayAnime.latestEpisode != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: displayAnime.status?.toLowerCase() == 'ongoing'
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                    : AppColors.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: displayAnime.status?.toLowerCase() == 'ongoing'
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                                      : AppColors.primary.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                displayAnime.latestEpisode ?? displayAnime.status ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: displayAnime.status?.toLowerCase() == 'ongoing'
                                                      ? const Color(0xFF6EE7B7)
                                                      : const Color(0xFFBFDBFE),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),

                                          // Quick stats
                                          if (displayAnime.totalEpisodes != null)
                                            _buildStatChip(
                                              Icons.movie_rounded,
                                              '${displayAnime.totalEpisodes} Episodes',
                                            ),
                                          const SizedBox(height: 6),
                                          if (displayAnime.rating != null)
                                            _buildStatChip(
                                              Icons.star_rounded,
                                              displayAnime.rating!,
                                            ),
                                          const SizedBox(height: 6),
                                          if (displayAnime.type != null)
                                            _buildStatChip(
                                              Icons.tv_rounded,
                                              displayAnime.type!,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Genres
                                if (_isLoading) ...[
                                  _buildSectionTitle('Genres'),
                                  const SizedBox(height: 8),
                                  _buildShimmerBlock(height: 30, width: 200),
                                  const SizedBox(height: 16),
                                ] else if (displayAnime.genres != null && displayAnime.genres!.isNotEmpty) ...[
                                  _buildSectionTitle('Genres'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: displayAnime.genres!.take(5).map((genre) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          genre,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Synopsis
                                if (_isLoading) ...[
                                  _buildSectionTitle('Synopsis'),
                                  const SizedBox(height: 8),
                                  _buildShimmerBlock(height: 80, width: double.infinity),
                                ] else if (displayAnime.synopsis != null && displayAnime.synopsis!.isNotEmpty) ...[
                                  _buildSectionTitle('Synopsis'),
                                  const SizedBox(height: 8),
                                  Text(
                                    displayAnime.synopsis!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToDetail,
                                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                                  label: Text(
                                    'View Details',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildShimmerBlock({required double height, required double width}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E2C),
      highlightColor: const Color(0xFF2A2A35),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

