// services/bookmark_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_model.dart';

class BookmarkService {
  static const String _bookmarksKey = 'bookmarks';

  static Future<void> addBookmark(Anime anime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await getBookmarks();
      
      // Check if already exist
      if (bookmarks.any((item) => item.id == anime.id)) return;
      
      bookmarks.insert(0, anime);
      
      final jsonList = bookmarks.map((item) => item.toJson()).toList();
      await prefs.setString(_bookmarksKey, jsonEncode(jsonList));
      
      if (kDebugMode) print('⭐ Added to bookmarks: ${anime.title}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to add bookmark: $e');
    }
  }

  static Future<void> removeBookmark(String animeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await getBookmarks();
      
      bookmarks.removeWhere((item) => item.id == animeId);
      
      final jsonList = bookmarks.map((item) => item.toJson()).toList();
      await prefs.setString(_bookmarksKey, jsonEncode(jsonList));
      
      if (kDebugMode) print('🗑️ Removed from bookmarks: $animeId');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to remove bookmark: $e');
    }
  }

  static Future<List<Anime>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString(_bookmarksKey);
      
      if (bookmarksJson == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(bookmarksJson);
      return jsonList.map((json) => Anime.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load bookmarks: $e');
      return [];
    }
  }

  static Future<bool> isBookmarked(String animeId) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((item) => item.id == animeId);
  }
}
