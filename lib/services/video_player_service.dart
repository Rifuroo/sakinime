// services/video_player_service.dart - Enhanced video player with fallbacks
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/anime_model.dart';

class VideoPlayerService {
  static const Duration _initTimeout = Duration(seconds: 30);
  static const Duration _fallbackTimeout = Duration(seconds: 15);

  /// Create video controller with enhanced error handling and fallbacks
  static Future<VideoPlayerController?> createController(
    StreamLink streamLink, {
    Map<String, String>? customHeaders,
  }) async {
    if (kDebugMode) {
      print('🎬 VideoPlayerService: Creating controller for ${streamLink.provider}');
      print('   URL: ${streamLink.url}');
      print('   Quality: ${streamLink.quality}');
    }

    VideoPlayerController? controller;

    // Check if this is an HLS stream for Android ExoPlayer format hint
    final isHls = streamLink.type.toLowerCase() == 'hls' ||
                  streamLink.url.toLowerCase().contains('.m3u8');

    try {
      // ✅ Primary attempt with full headers
      controller = await _createWithHeaders(
        streamLink.url,
        customHeaders ?? _getDefaultHeaders(streamLink.url),
        _initTimeout,
        isHls: isHls,
      );

      if (controller != null) {
        if (kDebugMode) print('✅ Primary initialization successful');
        return controller;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Primary initialization failed: $e');
    }

    try {
      // ✅ Fallback 1: Simplified headers
      if (kDebugMode) print('🔄 Trying fallback with simplified headers...');
      
      controller = await _createWithHeaders(
        streamLink.url,
        _getSimplifiedHeaders(),
        _fallbackTimeout,
        isHls: isHls,
      );

      if (controller != null) {
        if (kDebugMode) print('✅ Fallback initialization successful');
        return controller;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Fallback initialization failed: $e');
    }

    try {
      // ✅ Fallback 2: No headers
      if (kDebugMode) print('🔄 Trying without headers...');
      
      controller = VideoPlayerController.networkUrl(
        Uri.parse(streamLink.url),
        formatHint: isHls ? VideoFormat.hls : null,
      );
      
      await controller.initialize().timeout(_fallbackTimeout);
      
      if (kDebugMode) print('✅ No-headers initialization successful');
      return controller;
    } catch (e) {
      if (kDebugMode) print('❌ All initialization attempts failed: $e');
      controller?.dispose();
      return null;
    }
  }

  /// Create controller with specific headers and timeout
  static Future<VideoPlayerController?> _createWithHeaders(
    String url,
    Map<String, String> headers,
    Duration timeout, {
    bool isHls = false,
  }) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      formatHint: isHls ? VideoFormat.hls : null,
    );

    try {
      await controller.initialize().timeout(timeout);
      return controller;
    } catch (e) {
      controller.dispose();
      rethrow;
    }
  }

  /// Get default headers based on URL
  static Map<String, String> _getDefaultHeaders(String url) {
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'video',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site',
    };

    // ✅ Add referer based on domain
    if (uri.host.contains('hianime') || uri.host.contains('zoro')) {
      headers['Referer'] = 'https://hianime.to/';
    } else if (uri.host.contains('gogoanime')) {
      headers['Referer'] = 'https://gogoanime.lu/';
    } else if (uri.host.contains('animixplay')) {
      headers['Referer'] = 'https://animixplay.to/';
    }

    return headers;
  }

  /// Get simplified headers for fallback
  static Map<String, String> _getSimplifiedHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
      'Accept': '*/*',
    };
  }

  /// Validate stream URL before creating controller
  static bool isValidStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get quality priority for sorting
  static int getQualityPriority(String quality) {
    switch (quality.toLowerCase()) {
      case 'auto':
        return 0;
      case '1080p':
      case '1080':
        return 1;
      case '720p':
      case '720':
        return 2;
      case '480p':
      case '480':
        return 3;
      case '360p':
      case '360':
        return 4;
      case '240p':
      case '240':
        return 5;
      default:
        return 99;
    }
  }

  /// Sort stream links by quality and priority
  static List<StreamLink> sortStreamLinks(List<StreamLink> links) {
    final sortedLinks = List<StreamLink>.from(links);
    
    sortedLinks.sort((a, b) {
      // ✅ First sort by source priority (stream > download)
      final sourceA = (a.toJson()['source'] ?? 'unknown') as String;
      final sourceB = (b.toJson()['source'] ?? 'unknown') as String;
      
      if (sourceA == 'stream' && sourceB != 'stream') return -1;
      if (sourceB == 'stream' && sourceA != 'stream') return 1;
      
      // ✅ Then sort by quality
      final qualityA = getQualityPriority(a.quality ?? 'auto');
      final qualityB = getQualityPriority(b.quality ?? 'auto');
      
      return qualityA.compareTo(qualityB);
    });
    
    return sortedLinks;
  }

  /// Dispose controller safely
  static Future<void> disposeController(VideoPlayerController? controller) async {
    if (controller != null) {
      try {
        await controller.pause();
        controller.dispose();
        if (kDebugMode) print('✅ Video controller disposed safely');
      } catch (e) {
        if (kDebugMode) print('⚠️ Error disposing controller: $e');
      }
    }
  }

  /// Test video player initialization with a simple URL
  static Future<bool> testVideoPlayerInitialization() async {
    if (kDebugMode) {
      print('🧪 Testing video player initialization...');
    }

    try {
      // Test with a simple MP4 URL
      final testController = VideoPlayerController.networkUrl(
        Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
      );

      await testController.initialize().timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('✅ Video player test successful');
        print('   Duration: ${testController.value.duration}');
        print('   Size: ${testController.value.size}');
      }

      await testController.dispose();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Video player test failed: $e');
      }
      return false;
    }
  }
}