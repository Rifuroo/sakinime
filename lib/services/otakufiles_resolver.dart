// services/otakufiles_resolver.dart - ANTI-BOT BYPASS COMPLETE
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

class OtakuFilesResolver {
  static final Dio _dio = Dio(BaseOptions(
    followRedirects: false,
    validateStatus: (status) => status! < 500,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static final Map<String, String?> _cache = {};

  /// 🔥 RESOLVE OTAKUFILES TO DIRECT STREAMING URL - ANTI-BOT BYPASS
  static Future<String?> resolveToDirectDownload(String otakuUrl) async {
    if (_cache.containsKey(otakuUrl)) {
      if (kDebugMode) print('💾 OTAKU CACHE HIT');
      return _cache[otakuUrl];
    }

    try {
      if (kDebugMode) print('🔥 OTAKUFILES: Resolving $otakuUrl');

      final uri = Uri.parse(otakuUrl);
      final segments = uri.pathSegments;
      
      if (segments.isEmpty) {
        if (kDebugMode) print('❌ Invalid URL format');
        return null;
      }

      final hash = segments[0];
      final filename = segments.length > 1 ? segments[1] : null;

      if (kDebugMode) {
        print('   Hash: $hash');
        if (filename != null) print('   File: $filename');
      }

      // 🔥 METHOD 0: Test if download endpoint returns actual video (check Content-Type)
      final downloadUrl = 'https://otakufiles.net/$hash/download';
      if (kDebugMode) print('🔄 Testing download endpoint...');
      
      try {
        final testResponse = await _dio.head(
          downloadUrl,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status! < 500,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': otakuUrl,
            },
          ),
        );

        final contentType = testResponse.headers.value('content-type')?.toLowerCase();
        if (kDebugMode) print('   Content-Type: $contentType');

        // If it's NOT HTML/text, it's likely a video
        if (contentType != null && 
            !contentType.contains('text/html') && 
            !contentType.contains('text/plain') &&
            (contentType.contains('video') || 
             contentType.contains('application/octet-stream') ||
             contentType.contains('binary'))) {
          if (kDebugMode) print('✅ VERIFIED: Download endpoint serves video');
          _cache[otakuUrl] = downloadUrl;
          return downloadUrl;
        }

        if (kDebugMode) print('⚠️ Download endpoint returns HTML (anti-bot)');
      } catch (e) {
        if (kDebugMode) print('⚠️ Download test failed: $e');
      }

      // 🔥 METHOD 1: Fetch HTML and extract REAL video URL with anti-bot bypass headers
      if (kDebugMode) print('🔄 Fetching HTML with anti-bot headers...');
      
      final pageResponse = await _dio.get(
        otakuUrl,
        options: Options(
          followRedirects: true,
          headers: {
            // Enhanced anti-bot bypass headers
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://otakudesu.cloud/',
            'Origin': 'https://otakudesu.cloud',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'cross-site',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"Windows"',
          },
        ),
      );

      if (pageResponse.statusCode == 200 && pageResponse.data != null) {
        final html = pageResponse.data.toString();
        final document = html_parser.parse(html);
        
        if (kDebugMode) print('📄 HTML fetched: ${html.length} bytes');

        // 🔥 PRIORITY 1: Look for actual video URL in JavaScript variables
        final jsVideoPatterns = [
          RegExp(r'''(?:videoUrl|fileUrl|downloadUrl|streamUrl)\s*=\s*["'](https?://[^"']+)["']''', caseSensitive: false),
          RegExp(r'''(?:file|src|url)\s*:\s*["'](https?://[^"']+\.(?:mp4|mkv|avi|webm)[^"']*)["']''', caseSensitive: false),
          RegExp(r'''data-(?:video|file|src|url)=["'](https?://[^"']+)["']''', caseSensitive: false),
        ];

        for (final pattern in jsVideoPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null) {
            final videoUrl = match.group(1)!;
            if (_isRealVideoUrl(videoUrl)) {
              if (kDebugMode) print('✅ JS VAR: Real video URL found');
              if (kDebugMode) print('   URL: ${videoUrl.substring(0, videoUrl.length > 80 ? 80 : videoUrl.length)}...');
              _cache[otakuUrl] = videoUrl;
              return videoUrl;
            }
          }
        }

        // 🔥 PRIORITY 2: Look for video in <video> tag
        final videoElements = document.querySelectorAll('video source[src], video[src]');
        for (final el in videoElements) {
          final src = el.attributes['src'];
          if (src != null && _isRealVideoUrl(src)) {
            String url = src;
            if (!url.startsWith('http')) {
              url = 'https://otakufiles.net$url';
            }
            if (kDebugMode) print('✅ VIDEO TAG: Real source found');
            if (kDebugMode) print('   URL: ${url.substring(0, url.length > 80 ? 80 : url.length)}...');
            _cache[otakuUrl] = url;
            return url;
          }
        }

        // 🔥 PRIORITY 3: Look for download button with data attributes
        final downloadButtons = document.querySelectorAll('[data-url], [data-file], [data-src], [data-download]');
        for (final btn in downloadButtons) {
          final dataUrl = btn.attributes['data-url'] ?? 
                          btn.attributes['data-file'] ?? 
                          btn.attributes['data-src'] ??
                          btn.attributes['data-download'];
          if (dataUrl != null && _isRealVideoUrl(dataUrl)) {
            String url = dataUrl;
            if (!url.startsWith('http')) {
              url = 'https://otakufiles.net$url';
            }
            if (kDebugMode) print('✅ DATA ATTR: Real URL found');
            if (kDebugMode) print('   URL: ${url.substring(0, url.length > 80 ? 80 : url.length)}...');
            _cache[otakuUrl] = url;
            return url;
          }
        }

        // 🔥 PRIORITY 4: Extract all URLs and find the real video file
        final allUrlPattern = RegExp(
          r'''(https?://(?:www\.)?otakufiles\.net/(?:files|stream|d|v)/[a-zA-Z0-9_\-]+/[^\s"'<>]+\.(?:mp4|mkv|avi|webm))''',
          caseSensitive: false,
        );
        
        final urlMatches = allUrlPattern.allMatches(html);
        for (final match in urlMatches) {
          final videoUrl = match.group(1)!;
          if (_isRealVideoUrl(videoUrl)) {
            if (kDebugMode) print('✅ REGEX: Real video URL extracted');
            if (kDebugMode) print('   URL: ${videoUrl.substring(0, videoUrl.length > 80 ? 80 : videoUrl.length)}...');
            _cache[otakuUrl] = videoUrl;
            return videoUrl;
          }
        }

        // 🔥 PRIORITY 5: Try to find any /files/ or /stream/ URL (even without extension)
        final streamPattern = RegExp(
          r'''(https?://(?:www\.)?otakufiles\.net/(?:files|stream|d|v)/[a-zA-Z0-9_\-]+/[^\s"'<>]+)''',
          caseSensitive: false,
        );
        
        final streamMatches = streamPattern.allMatches(html);
        for (final match in streamMatches) {
          final streamUrl = match.group(1)!;
          // Test if this URL serves video
          try {
            final testResponse = await _dio.head(
              streamUrl,
              options: Options(
                followRedirects: false,
                validateStatus: (status) => status! < 500,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Referer': otakuUrl,
                },
              ),
            );

            final contentType = testResponse.headers.value('content-type')?.toLowerCase();
            
            if (contentType != null && 
                !contentType.contains('text/html') &&
                (contentType.contains('video') || 
                 contentType.contains('octet-stream'))) {
              if (kDebugMode) print('✅ STREAM URL VERIFIED: $streamUrl');
              _cache[otakuUrl] = streamUrl;
              return streamUrl;
            }
          } catch (e) {
            continue;
          }
        }
      }

      // 🔥 METHOD 2: Try alternative URL patterns with verification
      if (filename != null) {
        final patterns = [
          'https://otakufiles.net/files/$hash/$filename',
          'https://otakufiles.net/stream/$hash/$filename',
          'https://otakufiles.net/d/$hash/$filename',
          'https://otakufiles.net/v/$hash/$filename',
        ];

        for (final testUrl in patterns) {
          if (kDebugMode) print('🔄 Testing pattern: ${testUrl.substring(0, testUrl.length > 60 ? 60 : testUrl.length)}...');
          
          try {
            final testResponse = await _dio.head(
              testUrl,
              options: Options(
                followRedirects: false,
                validateStatus: (status) => status! < 500,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Referer': otakuUrl,
                },
              ),
            );

            final contentType = testResponse.headers.value('content-type')?.toLowerCase();
            
            if (kDebugMode) print('   Status: ${testResponse.statusCode}, Content-Type: $contentType');
            
            // Check if it's NOT HTML and status is OK or Partial Content
            if ((testResponse.statusCode == 200 || 
                 testResponse.statusCode == 206 ||
                 testResponse.statusCode == 302)) {
              
              if (contentType == null || 
                  (!contentType.contains('text/html') && 
                   !contentType.contains('text/plain'))) {
                if (kDebugMode) print('✅ ALTERNATIVE PATTERN WORKS: $testUrl');
                _cache[otakuUrl] = testUrl;
                return testUrl;
              }
            }
          } catch (e) {
            if (kDebugMode) print('   Failed: $e');
            continue;
          }
        }
      }

      if (kDebugMode) print('❌ FAILED: Cannot bypass OtakuFiles anti-bot protection');
      if (kDebugMode) print('   Suggestion: Try other servers (Desustream, etc)');
      
      _cache[otakuUrl] = null;
      return null;

    } catch (e) {
      if (kDebugMode) print('❌ ERROR: $e');
      _cache[otakuUrl] = null;
      return null;
    }
  }

  /// Helper: Check if URL is a real video URL (not anti-bot page)
  static bool _isRealVideoUrl(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Must NOT be /download endpoint alone (it's anti-bot)
    if (lowerUrl.endsWith('/download') && !lowerUrl.contains('/files/')) {
      return false;
    }
    
    // Must be video file or stream endpoint
    return lowerUrl.contains('/files/') ||
           lowerUrl.contains('/stream/') ||
           lowerUrl.contains('/d/') ||
           lowerUrl.contains('/v/') ||
           lowerUrl.endsWith('.mp4') ||
           lowerUrl.endsWith('.mkv') ||
           lowerUrl.endsWith('.avi') ||
           lowerUrl.endsWith('.webm') ||
           lowerUrl.contains('.mp4?') ||
           lowerUrl.contains('.mkv?');
  }

  static void clearCache() {
    _cache.clear();
    if (kDebugMode) print('🗑️ OtakuFiles cache cleared');
  }
}