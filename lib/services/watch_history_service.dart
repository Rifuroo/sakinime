// services/watch_history_service.dart - Watch History & Progress Tracking
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


class WatchHistoryItem {
  final String animeId;
  final String animeTitle;
  final String? animePoster;
  final String episodeId;
  final String episodeTitle;
  final int episodeNumber;
  final Duration watchedDuration; // Progress dalam episode
  final Duration totalDuration;   // Total durasi episode
  final DateTime lastWatched;
  final bool isCompleted;         // Apakah episode selesai ditonton

  WatchHistoryItem({
    required this.animeId,
    required this.animeTitle,
    this.animePoster,
    required this.episodeId,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.watchedDuration,
    required this.totalDuration,
    required this.lastWatched,
    this.isCompleted = false,
  });

  // Progress percentage (0.0 - 1.0)
  double get progressPercentage {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (watchedDuration.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  // Formatted progress text
  String get progressText {
    final watched = _formatDuration(watchedDuration);
    final total = _formatDuration(totalDuration);
    return '$watched / $total';
  }

  // Check if episode is almost finished (>90%)
  bool get isAlmostFinished => progressPercentage > 0.9;

  Map<String, dynamic> toJson() {
    return {
      'animeId': animeId,
      'animeTitle': animeTitle,
      'animePoster': animePoster,
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
      'episodeNumber': episodeNumber,
      'watchedDuration': watchedDuration.inMilliseconds,
      'totalDuration': totalDuration.inMilliseconds,
      'lastWatched': lastWatched.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      animeId: json['animeId'] ?? '',
      animeTitle: json['animeTitle'] ?? '',
      animePoster: json['animePoster'],
      episodeId: json['episodeId'] ?? '',
      episodeTitle: json['episodeTitle'] ?? '',
      episodeNumber: json['episodeNumber'] ?? 0,
      watchedDuration: Duration(milliseconds: json['watchedDuration'] ?? 0),
      totalDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
      lastWatched: DateTime.tryParse(json['lastWatched'] ?? '') ?? DateTime.now(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  static String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class WatchHistoryService {
  static const String _historyKey = 'watch_history';
  static const int _maxHistoryItems = 100; // Limit history items

  /// Save watch progress for an episode
  static Future<void> saveWatchProgress({
    required String animeId,
    required String animeTitle,
    String? animePoster,
    required String episodeId,
    required String episodeTitle,
    required int episodeNumber,
    required Duration watchedDuration,
    required Duration totalDuration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = await getWatchHistory();
      
      // Remove existing entry for this episode
      historyList.removeWhere((item) => 
        item.animeId == animeId && item.episodeId == episodeId);
      
      // Create new history item
      final historyItem = WatchHistoryItem(
        animeId: animeId,
        animeTitle: animeTitle,
        animePoster: animePoster,
        episodeId: episodeId,
        episodeTitle: episodeTitle,
        episodeNumber: episodeNumber,
        watchedDuration: watchedDuration,
        totalDuration: totalDuration,
        lastWatched: DateTime.now(),
        isCompleted: watchedDuration.inMilliseconds >= totalDuration.inMilliseconds * 0.9,
      );
      
      // Add to beginning of list (most recent first)
      historyList.insert(0, historyItem);
      
      // Limit history size
      if (historyList.length > _maxHistoryItems) {
        historyList.removeRange(_maxHistoryItems, historyList.length);
      }
      
      // Save to SharedPreferences
      final jsonList = historyList.map((item) => item.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
      
      if (kDebugMode) {
        print('💾 Watch progress saved: $animeTitle Ep$episodeNumber - ${historyItem.progressText}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save watch progress: $e');
      }
    }
  }

  /// Get complete watch history
  static Future<List<WatchHistoryItem>> getWatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(historyJson);
      return jsonList.map((json) => WatchHistoryItem.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load watch history: $e');
      }
      return [];
    }
  }

  /// Get watch progress for specific episode
  static Future<WatchHistoryItem?> getEpisodeProgress(String animeId, String episodeId) async {
    try {
      final history = await getWatchHistory();
      return history.firstWhere(
        (item) => item.animeId == animeId && item.episodeId == episodeId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get continue watching list (recent episodes with progress)
  static Future<List<WatchHistoryItem>> getContinueWatching({int limit = 10}) async {
    final history = await getWatchHistory();
    
    // Filter: only episodes with progress but not completed
    final continueList = history.where((item) => 
      item.progressPercentage > 0.05 && // At least 5% watched
      !item.isCompleted && // Not completed
      item.progressPercentage < 0.95 // Less than 95% watched
    ).take(limit).toList();
    
    return continueList;
  }

  /// Get recently watched anime (grouped by anime)
  static Future<List<WatchHistoryItem>> getRecentAnime({int limit = 20}) async {
    final history = await getWatchHistory();
    final Map<String, WatchHistoryItem> animeMap = {};
    
    // Group by anime ID, keep most recent episode per anime
    for (final item in history) {
      if (!animeMap.containsKey(item.animeId) || 
          item.lastWatched.isAfter(animeMap[item.animeId]!.lastWatched)) {
        animeMap[item.animeId] = item;
      }
    }
    
    final recentList = animeMap.values.toList();
    recentList.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    
    return recentList.take(limit).toList();
  }

  /// Clear all watch history
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      
      if (kDebugMode) {
        print('🗑️ Watch history cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear watch history: $e');
      }
    }
  }

  /// Remove specific anime from history
  static Future<void> removeAnimeFromHistory(String animeId) async {
    try {
      final history = await getWatchHistory();
      final filteredHistory = history.where((item) => item.animeId != animeId).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = filteredHistory.map((item) => item.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
      
      if (kDebugMode) {
        print('🗑️ Removed anime from history: $animeId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to remove anime from history: $e');
      }
    }
  }

  /// Migrate old title-based animeId to correct slug/ID
  static Future<void> migrateAnimeId(String oldId, String newId) async {
    if (oldId == newId) return;
    try {
      final history = await getWatchHistory();
      bool changed = false;
      
      final updatedHistory = history.map((item) {
        if (item.animeId == oldId) {
          changed = true;
          return WatchHistoryItem(
            animeId: newId,
            animeTitle: item.animeTitle,
            animePoster: item.animePoster,
            episodeId: item.episodeId,
            episodeTitle: item.episodeTitle,
            episodeNumber: item.episodeNumber,
            watchedDuration: item.watchedDuration,
            totalDuration: item.totalDuration,
            lastWatched: item.lastWatched,
            isCompleted: item.isCompleted,
          );
        }
        return item;
      }).toList();
      
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = updatedHistory.map((item) => item.toJson()).toList();
        await prefs.setString(_historyKey, jsonEncode(jsonList));
        if (kDebugMode) print('🔄 Migrated history: $oldId -> $newId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to migrate history: $e');
    }
  }

  /// Get watch statistics
  static Future<Map<String, dynamic>> getWatchStats() async {
    final history = await getWatchHistory();
    
    final totalEpisodes = history.length;
    final completedEpisodes = history.where((item) => item.isCompleted).length;
    final totalWatchTime = history.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + item.watchedDuration,
    );
    final uniqueAnime = history.map((item) => item.animeId).toSet().length;
    
    return {
      'totalEpisodes': totalEpisodes,
      'completedEpisodes': completedEpisodes,
      'totalWatchTime': totalWatchTime,
      'uniqueAnime': uniqueAnime,
      'averageProgress': totalEpisodes > 0 
          ? history.fold<double>(0, (sum, item) => sum + item.progressPercentage) / totalEpisodes
          : 0.0,
    };
  }

  /// Auto-save progress every 30 seconds during playback
  static Future<void> autoSaveProgress({
    required String animeId,
    required String animeTitle,
    String? animePoster,
    required String episodeId,
    required String episodeTitle,
    required int episodeNumber,
    required Duration currentPosition,
    required Duration totalDuration,
  }) async {
    // Only save if watched for at least 30 seconds and not at the very end
    if (currentPosition.inSeconds < 30 || 
        currentPosition.inMilliseconds >= totalDuration.inMilliseconds * 0.98) {
      return;
    }
    
    await saveWatchProgress(
      animeId: animeId,
      animeTitle: animeTitle,
      animePoster: animePoster,
      episodeId: episodeId,
      episodeTitle: episodeTitle,
      episodeNumber: episodeNumber,
      watchedDuration: currentPosition,
      totalDuration: totalDuration,
    );
  }
}