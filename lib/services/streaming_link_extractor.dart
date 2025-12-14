// services/streaming_link_extractor.dart - FIXED ANTI-BOT BYPASS
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

class StreamingLinkExtractor {
  static final Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    maxRedirects: 5,
    validateStatus: (status) => status! < 500,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static final Map<String, List<Map<String, String>>> _cache = {};

  /// 🔥 MAIN EXTRACTOR - SMART FILTERING
  static Future<List<Map<String, String>>> extractStreamingLinks(String url, {int depth = 0}) async {
    if (depth > 2) return [];

    // ❌ SKIP ANTI-BOT URLS IMMEDIATELY
    if (_isAntiBotUrl(url)) {
      if (kDebugMode) print('${"  " * depth}⚠️ SKIP: Anti-bot URL detected');
      return [];
    }

    if (_cache.containsKey(url)) {
      if (kDebugMode) print('💾 CACHE: ${_getProvider(url)}');
      return _cache[url]!;
    }

    try {
      final provider = _getProvider(url);
      if (kDebugMode) {
        print('\n${"  " * depth}🔥 EXTRACTING: $provider');
        print('${"  " * depth}   ${url.substring(0, 80)}...');
      }

      // Direct video
      if (_isDirectVideo(url)) {
        if (kDebugMode) print('${"  " * depth}✅ DIRECT VIDEO');
        final result = [{
          'url': url,
          'type': url.contains('.m3u8') ? 'hls' : 'mp4',
          'quality': _extractQuality(url),
          'source': 'direct'
        }];
        _cache[url] = result;
        return result;
      }

      List<Map<String, String>> results = [];

      // Route ke handler
      if (url.contains('blogger.com/video') || url.contains('blogspot.com')) {
        results = await _extractBlogger(url, depth);
      } else if (url.contains('blogger.com/blog/')) {
        results = await _extractBloggerBlog(url, depth);
      } else if (url.contains('otakufiles.net')) {
        results = await _extractOtakuFiles(url, depth);
      } else {
        results = await _extractGeneric(url, depth);
      }

      _cache[url] = results;
      return results;

    } catch (e) {
      if (kDebugMode) print('${"  " * depth}❌ ERROR: $e');
      _cache[url] = [];
      return [];
    }
  }

  /// 🔥 BLOGGER /video EXTRACTOR (MOST RELIABLE)
  static Future<List<Map<String, String>>> _extractBlogger(String url, int depth) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.blogger.com/',
            'Accept': '*/*',
          },
          followRedirects: true,
        ),
      );

      final html = response.data.toString();
      final results = <Map<String, String>>[];

      // Pattern 1: streams array (BEST)
      final streamsMatch = RegExp(r'"streams":\s*\[([^\]]+)\]').firstMatch(html);
      if (streamsMatch != null) {
        final streamsJson = streamsMatch.group(1)!;
        final playPattern = RegExp(r'"play_url":"([^"]+)"[^}]*"format_note":"([^"]+)"');
        
        for (final match in playPattern.allMatches(streamsJson)) {
          String videoUrl = match.group(1)!
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\/', '/')
              .replaceAll('\\', '');
          
          if (videoUrl.contains('googlevideo.com')) {
            results.add({
              'url': videoUrl,
              'type': 'mp4',
              'quality': match.group(2)!,
              'source': 'blogger'
            });
          }
        }
      }

      // Pattern 2: progressive_url
      if (results.isEmpty) {
        final match = RegExp(r'"progressive_url":"([^"]+)"').firstMatch(html);
        if (match != null) {
          String videoUrl = match.group(1)!.replaceAll(r'\u0026', '&').replaceAll('\\', '');
          results.add({
            'url': videoUrl,
            'type': 'mp4',
            'quality': _extractQuality(videoUrl),
            'source': 'blogger'
          });
        }
      }

      if (results.isNotEmpty) {
        if (kDebugMode) print('${"  " * depth}✅ BLOGGER: ${results.length} links');
      }

      return results;
    } catch (e) {
      if (kDebugMode) print('${"  " * depth}❌ Blogger: $e');
      return [];
    }
  }

  /// 🔥 BLOGGER /blog CONVERTER
  static Future<List<Map<String, String>>> _extractBloggerBlog(String url, int depth) async {
    try {
      if (kDebugMode) print('${"  " * depth}🔄 Converting /blog to /video...');
      
      // Extract video ID from /blog/ URL
      final blogPattern = RegExp(r'/blog/([A-Za-z0-9_\-]+)');
      final match = blogPattern.firstMatch(url);
      
      if (match != null) {
        final videoId = match.group(1)!;
        final videoUrl = 'https://www.blogger.com/video.g?token=$videoId';
        
        if (kDebugMode) print('${"  " * depth}   Trying: $videoUrl');
        
        return await _extractBlogger(videoUrl, depth);
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('${"  " * depth}❌ Blog convert: $e');
      return [];
    }
  }

  /// 🔥 OTAKUFILES SMART TESTER
  static Future<List<Map<String, String>>> _extractOtakuFiles(String url, int depth) async {
    try {
      if (kDebugMode) print('${"  " * depth}🔍 OtakuFiles: Smart test...');
      
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      if (segments.isEmpty) return [];

      final hash = segments[0];
      
      // Test endpoints dengan HEAD request (cepat, no download)
      final testEndpoints = [
        'https://otakufiles.net/$hash/download',
        'https://otakufiles.net/files/$hash',
        'https://otakufiles.net/stream/$hash',
      ];

      for (final testUrl in testEndpoints) {
        try {
          final response = await _dio.head(
            testUrl,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://otakudesu.cloud/',
              },
              followRedirects: false,
              validateStatus: (status) => status! < 500,
            ),
          );

          final contentType = response.headers.value('content-type')?.toLowerCase();
          final contentLength = response.headers.value('content-length');
          
          // Check if it's a video file (not HTML anti-bot page)
          if (contentType != null && 
              !contentType.contains('text/html') &&
              contentLength != null &&
              int.parse(contentLength) > 1000000) { // > 1MB = likely video
            
            if (kDebugMode) {
              print('${"  " * depth}✅ OTAKUFILES: Working endpoint');
              print('${"  " * depth}   Content-Type: $contentType');
              print('${"  " * depth}   Size: ${(int.parse(contentLength) / 1024 / 1024).toStringAsFixed(1)} MB');
            }
            
            return [{
              'url': testUrl,
              'type': 'mp4',
              'quality': 'auto',
              'source': 'otakufiles'
            }];
          }
        } catch (e) {
          continue;
        }
      }

      if (kDebugMode) print('${"  " * depth}⚠️ OtakuFiles: All endpoints failed (anti-bot)');
      return [];

    } catch (e) {
      if (kDebugMode) print('${"  " * depth}❌ OtakuFiles: $e');
      return [];
    }
  }

  /// 🔥 GENERIC EXTRACTOR
  static Future<List<Map<String, String>>> _extractGeneric(String url, int depth) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://otakudesu.cloud/',
          },
          followRedirects: true,
        ),
      );

      final html = response.data.toString();

      // Try to find Blogger iframe
      final bloggerPattern = RegExp(
        r'<iframe[^>]*src=["\x27](https?://[^"\x27]*blogger\.com/video[^"\x27]*)["\x27]',
        caseSensitive: false
      );
      final match = bloggerPattern.firstMatch(html);
      
      if (match != null) {
        final bloggerUrl = match.group(1)!.replaceAll('&amp;', '&');
        if (kDebugMode) print('${"  " * depth}🔍 Found Blogger iframe');
        return await _extractBlogger(bloggerUrl, depth + 1);
      }

      // Direct video file
      final videoPattern = RegExp(
        r'(https?://[^"\s<>]+googlevideo\.com[^"\s<>]+videoplayback[^"\s<>]+)',
        caseSensitive: false
      );
      final videoMatch = videoPattern.firstMatch(html);
      
      if (videoMatch != null) {
        final videoUrl = videoMatch.group(1)!;
        if (kDebugMode) print('${"  " * depth}✅ GENERIC: Direct GoogleVideo');
        return [{
          'url': videoUrl,
          'type': 'mp4',
          'quality': _extractQuality(videoUrl),
          'source': 'generic'
        }];
      }

      return [];
    } catch (e) {
      if (kDebugMode) print('${"  " * depth}❌ Generic: $e');
      return [];
    }
  }

  /// CHECK IF URL HAS ANTI-BOT
  static bool _isAntiBotUrl(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Known anti-bot patterns
    final antiBotPatterns = [
      'desustream.com/safelink', // Always anti-bot
      'acefile.co/player',       // Requires verification
      'gofile.io/',              // Download only
      'mega.nz/file',            // Download only
      'pixeldrain.com/u',        // Sometimes anti-bot
      'krakenfiles.com/view',    // Download only
    ];
    
    return antiBotPatterns.any((pattern) => lowerUrl.contains(pattern));
  }

  static bool _isDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('googlevideo.com') ||
           lower.contains('videoplayback') ||
           lower.endsWith('.mp4') ||
           lower.endsWith('.m3u8') ||
           lower.contains('.mp4?') ||
           lower.contains('.m3u8?');
  }

  static String _extractQuality(String url) {
    final patterns = [
      RegExp(r'/(\d{3,4})p[/.]'),
      RegExp(r'quality[=_](\d{3,4})p?', caseSensitive: false),
      RegExp(r'itag=(\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        if (pattern.pattern.contains('itag')) {
          const itagMap = {'18': '360p', '22': '720p', '37': '1080p', '59': '480p'};
          return itagMap[match.group(1)!] ?? 'auto';
        }
        return '${match.group(1)}p';
      }
    }
    return 'auto';
  }

  static String _getProvider(String url) {
    if (url.contains('blogger.com')) return 'Blogger';
    if (url.contains('desustream')) return 'Desustream';
    if (url.contains('otakufiles')) return 'OtakuFiles';
    if (url.contains('googlevideo')) return 'GoogleVideo';
    return 'Unknown';
  }

  static void clearCache() {
    _cache.clear();
    if (kDebugMode) print('🗑️ Cache cleared');
  }
}