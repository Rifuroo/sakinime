// services/watch_history_service.dart - Watch history and progress tracking
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchHistoryService {
  static const String _historyKey = 'watch_history';
  static const String _progressKey = 'watch_progress';
  
  /// Save video progress
  Future<void> saveProgress({
    required String videoId,
    required int lastPosition,
    required int duration,
    required String title,
    String? thumbnail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = prefs.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> allProgress = json.decode(progressData);
      
      allProgress[videoId] = {
        'lastPosition': lastPosition,
        'duration': duration,
        'title': title,
        'thumbnail': thumbnail,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_progressKey, json.encode(allProgress));
      
      if (kDebugMode) {
        print('💾 Saved progress: $videoId at ${lastPosition}s/${duration}s');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save progress: $e');
      }
    }
  }
  
  /// Get video progress
  Future<Map<String, dynamic>?> getVideoProgress(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = prefs.getString(_progressKey) ?? '{}';
      final Map<String, dynamic> allProgress = json.decode(progressData);
      
      return allProgress[videoId];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get progress: $e');
      }
      return null;
    }
  }
  
  /// Add to watch history
  Future<void> addToHistory({
    required String videoId,
    required String title,
    String? thumbnail,
    String? animeTitle,
    int? episodeNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> history = json.decode(historyData);
      
      // Remove existing entry if present
      history.removeWhere((item) => item['videoId'] == videoId);
      
      // Add new entry at the beginning
      history.insert(0, {
        'videoId': videoId,
        'title': title,
        'thumbnail': thumbnail,
        'animeTitle': animeTitle,
        'episodeNumber': episodeNumber,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Keep only last 100 entries
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }
      
      await prefs.setString(_historyKey, json.encode(history));
      
      if (kDebugMode) {
        print('📚 Added to history: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to add to history: $e');
      }
    }
  }
  
  /// Get watch history
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> history = json.decode(historyData);
      
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get history: $e');
      }
      return [];
    }
  }
  
  /// Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      
      if (kDebugMode) {
        print('🗑️ Cleared watch history');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear history: $e');
      }
    }
  }
  
  /// Clear all progress
  Future<void> clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey);
      
      if (kDebugMode) {
        print('🗑️ Cleared watch progress');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear progress: $e');
      }
    }
  }
  
  /// Get progress percentage for a video
  Future<double> getProgressPercentage(String videoId) async {
    final progress = await getVideoProgress(videoId);
    if (progress == null) return 0.0;
    
    final lastPosition = progress['lastPosition'] as int? ?? 0;
    final duration = progress['duration'] as int? ?? 0;
    
    if (duration <= 0) return 0.0;
    
    return (lastPosition / duration).clamp(0.0, 1.0);
  }
  
  /// Check if video is completed (>90% watched)
  Future<bool> isVideoCompleted(String videoId) async {
    final percentage = await getProgressPercentage(videoId);
    return percentage >= 0.9;
  }
}

// Global instance
final watchHistoryService = WatchHistoryService();