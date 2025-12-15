// Test watch history functionality
import 'package:flutter/foundation.dart';
import 'lib/services/watch_history_service.dart';

void main() async {
  print('🧪 Testing Watch History Service...');
  
  // Test saving progress
  await WatchHistoryService.saveWatchProgress(
    animeId: 'chainsaw-man',
    animeTitle: 'Chainsaw Man',
    animePoster: 'https://example.com/poster.jpg',
    episodeId: 'chainsaw-man-ep1',
    episodeTitle: 'Episode 1: Dog & Chainsaw',
    episodeNumber: 1,
    watchedDuration: const Duration(minutes: 5, seconds: 30),
    totalDuration: const Duration(minutes: 24),
  );
  print('✅ Progress saved successfully');
  
  // Test getting history
  final history = await WatchHistoryService.getWatchHistory();
  print('📺 Watch history: ${history.length} items');
  
  if (history.isNotEmpty) {
    final item = history.first;
    print('   Latest: ${item.animeTitle} - ${item.episodeTitle}');
    print('   Progress: ${item.progressText} (${(item.progressPercentage * 100).toStringAsFixed(1)}%)');
  }
  
  // Test continue watching
  final continueWatching = await WatchHistoryService.getContinueWatching();
  print('▶️ Continue watching: ${continueWatching.length} items');
  
  // Test recent anime
  final recentAnime = await WatchHistoryService.getRecentAnime();
  print('🕒 Recent anime: ${recentAnime.length} items');
  
  // Test stats
  final stats = await WatchHistoryService.getWatchStats();
  print('📊 Watch stats:');
  print('   Total episodes: ${stats['totalEpisodes']}');
  print('   Completed episodes: ${stats['completedEpisodes']}');
  print('   Unique anime: ${stats['uniqueAnime']}');
  print('   Total watch time: ${stats['totalWatchTime']}');
  
  print('🎉 All tests completed!');
}