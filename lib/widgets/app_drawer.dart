import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/anime_provider.dart';
import '../constants/app_colors.dart';
import '../screens/browse_screen.dart';
import '../screens/schedule_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeProvider>(context, listen: false);
    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      backgroundColor: AppColors.background,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          // Drawer Header matching Expo LinearGradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: topPadding + 20, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.black),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sukinime',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Anime Universe',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 25),
              children: [
                Text(
                  'CATEGORIES',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                _buildDrawerItem(
                  context,
                  icon: Icons.whatshot_outlined,
                  label: 'Most Popular',
                  onTap: () => _navigateToBrowse(context, 'most-popular'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.favorite_outline,
                  label: 'Most Favorite',
                  onTap: () => _navigateToBrowse(context, 'most-favorite'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.movie_outlined,
                  label: 'Movies',
                  onTap: () => _navigateToBrowse(context, 'movie'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.tv_rounded,
                  label: 'TV Series',
                  onTap: () => _navigateToBrowse(context, 'tv'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.album_outlined,
                  label: 'OVAs',
                  onTap: () => _navigateToBrowse(context, 'ova'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.public_outlined,
                  label: 'ONAs',
                  onTap: () => _navigateToBrowse(context, 'ona'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.star_outline_rounded,
                  label: 'Specials',
                  onTap: () => _navigateToBrowse(context, 'special'),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  child: Divider(color: Colors.white10),
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.calendar_month_outlined,
                  label: 'Schedule',
                  iconColor: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen()));
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.only(left: 25, right: 25, bottom: MediaQuery.of(context).padding.bottom + 20, top: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v1.1.0 Alpha',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Made with ❤️ for Anime fans',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToBrowse(BuildContext context, String category) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseScreen(initialCategory: category),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: iconColor ?? const Color(0xFFA1A1AA)),
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
