import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/anime_provider.dart';
import '../models/anime_model.dart';
import 'detail_anime_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [];
  final List<DateTime> _dates = [];

  @override
  void initState() {
    super.initState();
    _generateDates();
    _tabController = TabController(length: 7, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnimeProvider>(context, listen: false).fetchSchedule();
    });
  }

  void _generateDates() {
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      _dates.add(date);
      if (i == 0) {
        _days.add('Today');
      } else {
        _days.add(DateFormat('EEE').format(date));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Release Schedule',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: _days.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: Consumer<AnimeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.schedules.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          if (provider.errorMessage != null && provider.schedules.isEmpty) {
            return Center(
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: _dates.map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final daySchedule = provider.schedules[dateStr] ?? [];

              if (daySchedule.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy_rounded, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        'No schedule for this day',
                        style: GoogleFonts.poppins(color: Colors.white38),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: daySchedule.length,
                itemBuilder: (context, index) {
                  final item = daySchedule[index];
                  return _buildScheduleCard(item);
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.time,
            style: GoogleFonts.poppins(
              color: const Color(0xFF818CF8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          item.name,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.episode,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: item.id != null ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailAnimeScreen(animeId: item.id!),
            ),
          );
        } : null,
      ),
    );
  }
}