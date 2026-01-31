import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/download_service.dart';
import '../constants/app_colors.dart';
import 'player_screen.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Offline Downloads',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<DownloadService>(
        builder: (context, service, child) {
          final tasks = service.tasks;

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_download_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildDownloadCard(context, task, service);
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadCard(BuildContext context, DownloadTask task, DownloadService service) {
    bool isCompleted = task.status == 'completed';
    bool isFailed = task.status == 'failed';
    bool isDownloading = task.status == 'downloading';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          task.animeTitle,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.episodeTitle,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.white10,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${(task.progress * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ] else if (isFailed) ...[
              const SizedBox(height: 4),
              Text(
                'Download failed',
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Downloaded (${(task.totalSize != null ? (task.totalSize! / (1024 * 1024)).toStringAsFixed(1) : "0")} MB)',
                style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 32),
                onPressed: () {
                  // Play offline!
                  // We'll pass the local filePath to PlayerScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlayerScreen(),
                      settings: RouteSettings(
                        arguments: {
                          'episodeId': task.url, // MediaKit can play local files
                          'animeId': task.animeId,
                          'animeTitle': task.animeTitle,
                          'offline': true,
                        },
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: () => service.removeDownload(task.id),
            ),
          ],
        ),
      ),
    );
  }
}

