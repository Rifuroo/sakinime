import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/anime_service.dart';
import '../constants/app_colors.dart';
import 'detail_anime_screen.dart';

class CharacterDetailScreen extends StatefulWidget {
  final String characterId;
  final String characterName;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  Map<String, dynamic>? _characterData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCharacterDetail();
  }

  Future<void> _loadCharacterDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = AnimeService();
      final data = await service.getCharacterDetail(widget.characterId);
      
      if (mounted) {
        setState(() {
          _characterData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load character details: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFCA5A5),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadCharacterDetail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // App Bar with Character Image
                    SliverAppBar(
                      expandedHeight: 300,
                      pinned: true,
                      backgroundColor: const Color(0xFF0A0A0A),
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          widget.characterName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if ((_characterData?['imageUrl'] ??
                                    _characterData?['image'] ??
                                    _characterData?['poster'] ??
                                    _characterData?['img'] ??
                                    _characterData?['thumbnail']) !=
                                null)
                              CachedNetworkImage(
                                imageUrl: (_characterData?['imageUrl'] ??
                                    _characterData?['image'] ??
                                    _characterData?['poster'] ??
                                    _characterData?['img'] ??
                                    _characterData?['thumbnail'])!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF1E293B),
                                  child: const Icon(
                                    Icons.person,
                                    size: 80,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF0A0A0A).withValues(alpha: 0.7),
                                    const Color(0xFF0A0A0A),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Character Info
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_characterData?['description'] != null) ...[
                              Text(
                                'About',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _characterData!['description'],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Voice Actors
                            if (_characterData?['voiceActors'] != null &&
                                (_characterData!['voiceActors'] as List).isNotEmpty) ...[
                              Text(
                                'Voice Actors',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(_characterData!['voiceActors'] as List).map((va) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      if (va['image'] != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: va['image'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              va['name'] ?? 'Unknown',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (va['language'] != null)
                                              Text(
                                                va['language'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 24),
                            ],

                            // Related Anime
                            if (_characterData?['animeography'] != null &&
                                (_characterData!['animeography'] as List).isNotEmpty) ...[
                              Text(
                                'Appears In',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(_characterData!['animeography'] as List).map((anime) {
                                return GestureDetector(
                                  onTap: () {
                                    if (anime['id'] != null) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => DetailAnimeScreen(
                                            animeId: anime['id'],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        if (anime['poster'] != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: anime['poster'],
                                              width: 60,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                anime['title'] ?? 'Unknown',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (anime['role'] != null)
                                                Text(
                                                  anime['role'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

