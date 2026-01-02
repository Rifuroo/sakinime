// screens/character_browser_screen.dart - Character Browser Screen
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/anime_provider.dart';
import 'character_detail_screen.dart';

class CharacterBrowserScreen extends StatefulWidget {
  final String? animeId;
  final String? animeTitle;

  const CharacterBrowserScreen({super.key, this.animeId, this.animeTitle});

  @override
  State<CharacterBrowserScreen> createState() => _CharacterBrowserScreenState();
}

class _CharacterBrowserScreenState extends State<CharacterBrowserScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    if (widget.animeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AnimeProvider>(context, listen: false).fetchCharacters(widget.animeId!);
      });
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 400) {
        _loadMore();
      }
    }
  }

  void _loadMore() {
    if (widget.animeId == null) return;
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    if (!provider.isLoadingCharacters && !provider.isLoadingMore && provider.hasMoreCharacters) {
      _currentPage++;
      provider.fetchCharacters(widget.animeId!, page: _currentPage);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Text(
          widget.animeTitle ?? 'Characters',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<AnimeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCharacters && provider.characters.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.characters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.people_outline, size: 64, color: Colors.white24),
                   const SizedBox(height: 16),
                   Text(
                     widget.animeId == null 
                        ? 'Select an anime to browse characters'
                        : 'No characters found for this anime',
                     style: GoogleFonts.inter(color: Colors.white54),
                   ),
                ],
              ),
            );
          }

          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: provider.characters.length + (provider.isLoadingMore ? 3 : 0),
            itemBuilder: (context, index) {
              if (index >= provider.characters.length) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final character = provider.characters[index];
              return _buildCharacterCard(character);
            },
          );
        },
      ),
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> character) {
    final String name = character['name'] ?? 'Unknown';
    final String? image = character['imageUrl'] ?? character['image'] ?? character['poster'] ?? character['img'] ?? character['thumbnail'];
    final String? id = character['id'];
    final String? role = character['role'];

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
      child: Column(
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
            textAlign: TextAlign.center,
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
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
