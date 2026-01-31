import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/anime_provider.dart';
import '../models/anime_model.dart';
import '../constants/app_colors.dart';
import 'detail_anime_screen.dart';

class Watch2GetherScreen extends StatefulWidget {
  const Watch2GetherScreen({super.key});

  @override
  State<Watch2GetherScreen> createState() => _Watch2GetherScreenState();
}

class _Watch2GetherScreenState extends State<Watch2GetherScreen> {
  String _currentFilter = 'all';
  final List<Map<String, String>> _filters = [
    {'id': 'all', 'label': 'All'},
    {'id': 'on_air', 'label': 'On-Air'},
    {'id': 'scheduled', 'label': 'Scheduled'},
    {'id': 'waiting', 'label': 'Waiting'},
    {'id': 'ended', 'label': 'Ended'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRooms();
    });
  }

  void _loadRooms() {
    Provider.of<AnimeProvider>(context, listen: false).fetchWatch2GetherRooms(room: _currentFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Watch2Gether',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadRooms,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<AnimeProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.watch2GetherRooms.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (provider.watch2GetherRooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.group_off_rounded, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage ?? 'No active rooms found',
                          style: GoogleFonts.poppins(color: Colors.white38),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: provider.watch2GetherRooms.length,
                  itemBuilder: (context, index) {
                    final room = provider.watch2GetherRooms[index];
                    return _buildRoomCard(room);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _currentFilter == filter['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentFilter = filter['id']!;
              });
              _loadRooms();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.white24 : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  filter['label']!,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(Watch2GetherRoom room) {
    return GestureDetector(
      onTap: room.animeId != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailAnimeScreen(animeId: room.animeId!),
          ),
        );
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: room.poster ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.status,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomTitle ?? room.animeTitle ?? 'Unnamed Room',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${room.createdBy ?? "System"}',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.video_library_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.episode ?? 'N/A',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

