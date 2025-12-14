// services/blogger_resolver.dart - WITH OTAKUFILES RESOLVER
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class BloggerResolver {
  static final Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    maxRedirects: 8,
    validateStatus: (status) => status! < 500,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static final Map<String, String?> _resolveCache = {};

  static Future<String?> resolveToDirectVideo(String url) async {
    if (_resolveCache.containsKey(url)) {
      if (kDebugMode) print('💾 CACHE HIT: ${_extractProvider(url)}');
      return _resolveCache[url];
    }

    try {
      if (kDebugMode) print('\n🔗 RESOLVING: ${_extractProvider(url)}');

      // Skip Blogger links (always 404)
      if (url.contains('blogger.com/blog/')) {
        if (kDebugMode) print('⚠️ SKIP: Blogger link always fails');
        _resolveCache[url] = null;
        return null;
      }

      // 🔥 OTAKUFILES RESOLVER
      if (url.contains('otakufiles.net')) {
        final result = await _resolveOtakuFiles(url);
        _resolveCache[url] = result;
        return result;
      }

      // DESUSTREAM SAFELINK
      if (url.contains('desustream.com/safelink')) {
        final result = await _resolveDesustreamSafelink(url);
        _resolveCache[url] = result;
        return result;
      }

      // DIRECT FILE CHECK
      if (_isDirectFile(url)) {
        if (kDebugMode) print('✅ DIRECT: Already a video file');
        _resolveCache[url] = url;
        return url;
      }

      // GENERIC RESOLVER
      final response = await _dio.get(
        url,
        options: Options(
          followRedirects: true,
          maxRedirects: 8,
          validateStatus: (status) => status! < 500,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://otakudesu.cloud/',
          },
        ),
      );

      if (kDebugMode) print('   Status: ${response.statusCode}');

      final finalUrl = response.realUri.toString();
      
      if (finalUrl.contains('googlevideo.com') || _isDirectFile(finalUrl)) {
        if (kDebugMode) print('✅ RESOLVED: Direct redirect');
        _resolveCache[url] = finalUrl;
        return finalUrl;
      }

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        final extractedUrl = await _aggressiveExtract(html, url);
        
        if (extractedUrl != null) {
          _resolveCache[url] = extractedUrl;
          return extractedUrl;
        }
      }

      if (kDebugMode) print('⚠️ FAILED: No video URL found');
      _resolveCache[url] = null;
      return null;

    } on DioException catch (e) {
      if (kDebugMode) print('⚠️ ERROR: ${e.type}');
      _resolveCache[url] = null;
      return null;
    } catch (e) {
      if (kDebugMode) print('⚠️ ERROR: $e');
      _resolveCache[url] = null;
      return null;
    }
  }

  /// 🔥 OTAKUFILES RESOLVER
  static Future<String?> _resolveOtakuFiles(String otakuUrl) async {
    try {
      if (kDebugMode) print('   Type: OtakuFiles URL');
      
      // Pattern URL OtakuFiles: https://otakufiles.net/{hash}/{filename}
      // Kita perlu fetch HTML untuk dapat direct download link
      
      final response = await _dio.get(
        otakuUrl,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://otakudesu.cloud/',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        
        // Pattern 1: Direct download button
        final downloadPattern = RegExp(
          r'href=["\x27](https?://[^"\x27]+otakufiles\.net/[^"\x27]+/download[^"\x27]*)["\x27]',
          caseSensitive: false,
        );
        var match = downloadPattern.firstMatch(html);
        if (match != null) {
          final downloadUrl = _cleanUrl(match.group(1)!);
          if (kDebugMode) print('✅ OTAKUFILES: Found download URL');
          return downloadUrl;
        }

        // Pattern 2: Video source tag
        final videoPattern = RegExp(
          r'<video[^>]*>.*?<source[^>]*src=["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false,
          dotAll: true,
        );
        match = videoPattern.firstMatch(html);
        if (match != null) {
          String videoUrl = _cleanUrl(match.group(1)!);
          if (!videoUrl.startsWith('http')) {
            videoUrl = 'https://otakufiles.net$videoUrl';
          }
          if (kDebugMode) print('✅ OTAKUFILES: Found video source');
          return videoUrl;
        }

        // Pattern 3: JavaScript file variable
        final jsFilePattern = RegExp(
          r'(?:file|videoUrl|src)\s*[:=]\s*["\x27](https?://[^"\x27]+)["\x27]',
          caseSensitive: false,
        );
        match = jsFilePattern.firstMatch(html);
        if (match != null) {
          final videoUrl = _cleanUrl(match.group(1)!);
          if (kDebugMode) print('✅ OTAKUFILES: Found JS video URL');
          return videoUrl;
        }

        // Pattern 4: Direct file link dengan hash
        final directFilePattern = RegExp(
          r'(https?://otakufiles\.net/files/[^"\x27\s<>]+)',
          caseSensitive: false,
        );
        match = directFilePattern.firstMatch(html);
        if (match != null) {
          final videoUrl = _cleanUrl(match.group(1)!);
          if (kDebugMode) print('✅ OTAKUFILES: Found direct file URL');
          return videoUrl;
        }

        // Pattern 5: Construct download URL from hash
        // URL format: https://otakufiles.net/{hash}/{filename}
        final uriParts = Uri.parse(otakuUrl);
        final pathSegments = uriParts.pathSegments;
        
        if (pathSegments.length >= 2) {
          final hash = pathSegments[0];
          final filename = pathSegments[1];
          
          // Try direct download URL
          final downloadUrl = 'https://otakufiles.net/$hash/download';
          if (kDebugMode) print('🔄 OTAKUFILES: Trying constructed download URL');
          
          try {
            final downloadResponse = await _dio.head(
              downloadUrl,
              options: Options(
                followRedirects: false,
                validateStatus: (status) => status! < 400,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Referer': otakuUrl,
                },
              ),
            );
            
            if (downloadResponse.statusCode == 200 || 
                downloadResponse.statusCode == 302 ||
                downloadResponse.statusCode == 301) {
              if (kDebugMode) print('✅ OTAKUFILES: Download URL works');
              return downloadUrl;
            }
          } catch (e) {
            // Download URL doesn't work, continue
          }
          
          // Try file URL
          final fileUrl = 'https://otakufiles.net/files/$hash/$filename';
          if (kDebugMode) print('🔄 OTAKUFILES: Trying file URL');
          return fileUrl;
        }
      }

      if (kDebugMode) print('⚠️ FAILED: Cannot resolve OtakuFiles URL');
      return null;

    } catch (e) {
      if (kDebugMode) print('⚠️ ERROR: $e');
      return null;
    }
  }

  /// DESUSTREAM SAFELINK RESOLVER
  static Future<String?> _resolveDesustreamSafelink(String safelinkUrl) async {
    try {
      if (kDebugMode) print('   Type: Desustream safelink');
      
      final response = await _dio.get(
        safelinkUrl,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://desustream.com/',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        
        // Direct video file
        final directPattern = RegExp(
          r'https?://[^\s"\x27<>]+\.(mp4|mkv|m3u8)',
          caseSensitive: false,
        );
        var match = directPattern.firstMatch(html);
        if (match != null) {
          final url = _cleanUrl(match.group(0)!);
          if (kDebugMode) print('✅ DIRECT: Video file in safelink');
          return url;
        }

        // OtakuFiles pattern
        final otakuPattern = RegExp(
          r'https?://otakufiles\.net/[a-zA-Z0-9]+/[^"\x27\s<>]+',
          caseSensitive: false,
        );
        match = otakuPattern.firstMatch(html);
        if (match != null) {
          final url = _cleanUrl(match.group(0)!);
          if (kDebugMode) print('🔄 OTAKUFILES: Found in safelink, resolving...');
          // Recursively resolve OtakuFiles
          return await resolveToDirectVideo(url);
        }

        // Meta refresh redirect
        final metaPattern = RegExp(
          r'<meta[^>]*http-equiv=["\x27]refresh["\x27][^>]*content=["\x27][0-9]+;\s*url=([^"\x27]+)["\x27]',
          caseSensitive: false,
        );
        match = metaPattern.firstMatch(html);
        if (match != null) {
          String redirectUrl = match.group(1)!;
          if (redirectUrl.startsWith('//')) {
            redirectUrl = 'https:$redirectUrl';
          }
          
          if (!_isBadHost(redirectUrl)) {
            if (kDebugMode) print('🔄 META REFRESH: Recursive');
            return await resolveToDirectVideo(redirectUrl);
          }
        }

        // JavaScript window.location redirect
        final jsRedirectPattern = RegExp(
          r'window\.location(?:\.href)?\s*=\s*["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false,
        );
        match = jsRedirectPattern.firstMatch(html);
        if (match != null) {
          String redirectUrl = match.group(1)!;
          if (redirectUrl.startsWith('//')) {
            redirectUrl = 'https:$redirectUrl';
          }
          
          if (!_isBadHost(redirectUrl)) {
            if (kDebugMode) print('🔄 JS REDIRECT: Recursive');
            return await resolveToDirectVideo(redirectUrl);
          }
        }

        // Generic redirect pattern
        final redirectPattern = RegExp(
          r'(?:href|content|url)=["\x27](https?://[^"\x27]+)["\x27]',
          caseSensitive: false,
        );
        
        for (final match in redirectPattern.allMatches(html)) {
          final url = match.group(1);
          if (url != null && 
              !url.contains('desustream.com') &&
              !_isBadHost(url) &&
              url.startsWith('http')) {
            
            if (kDebugMode) print('🔄 REDIRECT: Found link');
            return await resolveToDirectVideo(url);
          }
        }
      }

      if (kDebugMode) print('⚠️ FAILED: No video in safelink');
      return null;

    } catch (e) {
      if (kDebugMode) print('⚠️ ERROR: $e');
      return null;
    }
  }

  /// AGGRESSIVE HTML EXTRACTION
  static Future<String?> _aggressiveExtract(String html, String sourceUrl) async {
    // Pattern 1: Google Video
    final googleVideoPattern = RegExp(
      r'https://[^"\x27\s<>]*googlevideo\.com[^"\x27\s<>]*',
      caseSensitive: false,
    );
    var match = googleVideoPattern.firstMatch(html);
    if (match != null) {
      String videoUrl = _cleanUrl(match.group(0)!);
      if (kDebugMode) print('✅ EXTRACTED: Google Video');
      return videoUrl;
    }

    // Pattern 2: Direct video files
    final directVideoPattern = RegExp(
      r'https?://[^"\x27\s<>]+\.(mp4|mkv|m3u8|webm|avi)[^"\x27\s<>]*',
      caseSensitive: false,
    );
    match = directVideoPattern.firstMatch(html);
    if (match != null) {
      String videoUrl = _cleanUrl(match.group(0)!);
      if (kDebugMode) print('✅ EXTRACTED: Direct video file');
      return videoUrl;
    }

    // Pattern 3: OtakuFiles
    final otakuFilesPattern = RegExp(
      r'https?://[^"\x27\s<>]*otakufiles\.net/[a-zA-Z0-9]+/[^"\x27\s<>]+',
      caseSensitive: false,
    );
    match = otakuFilesPattern.firstMatch(html);
    if (match != null) {
      String url = _cleanUrl(match.group(0)!);
      if (kDebugMode) print('🔄 OTAKUFILES: Found, resolving...');
      return await resolveToDirectVideo(url);
    }

    // Pattern 4: Video tag source
    final videoTagPattern = RegExp(
      r'<video[^>]*>.*?<source[^>]*src=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
      dotAll: true,
    );
    match = videoTagPattern.firstMatch(html);
    if (match != null) {
      String videoUrl = _cleanUrl(match.group(1)!);
      if (kDebugMode) print('✅ EXTRACTED: <video> tag');
      return videoUrl;
    }

    return null;
  }

  // HELPER FUNCTIONS
  static bool _isDirectFile(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Check if it's truly a direct file
    if (lowerUrl.contains('otakufiles.net')) {
      // OtakuFiles URLs need special handling
      return lowerUrl.contains('/files/') || 
             lowerUrl.contains('/download') ||
             lowerUrl.endsWith('.mp4') ||
             lowerUrl.endsWith('.mkv') ||
             lowerUrl.endsWith('.m3u8');
    }
    
    return lowerUrl.endsWith('.mp4') ||
           lowerUrl.endsWith('.mkv') ||
           lowerUrl.endsWith('.m3u8') ||
           lowerUrl.endsWith('.webm') ||
           lowerUrl.endsWith('.avi') ||
           lowerUrl.contains('.mp4?') ||
           lowerUrl.contains('.mkv?') ||
           lowerUrl.contains('.m3u8?') ||
           lowerUrl.contains('videoplayback') ||
           lowerUrl.contains('googlevideo.com');
  }

  static bool _isValidVideoUrl(String url) {
    if (url.length < 10) return false;
    if (_isBadHost(url)) return false;
    
    return url.startsWith('http://') ||
           url.startsWith('https://') ||
           _isDirectFile(url);
  }

  static bool _isBadHost(String url) {
    final lowerUrl = url.toLowerCase();
    final badHosts = [
      'acefile.co/assets',
      'gofile.io/',
      'mega.nz/file',
      'krakenfiles.com/view',
      'pixeldrain.com/u',
      'favicon',
      '.css',
      '.js',
      '.ico',
      'jquery',
      'bootstrap',
    ];
    
    return badHosts.any((host) => lowerUrl.contains(host));
  }

  static String _cleanUrl(String url) {
    return url
        .replaceAll('&amp;', '&')
        .replaceAll('&#61;', '=')
        .replaceAll('&#38;', '&')
        .replaceAll('\\"', '')
        .replaceAll("\\'", '')
        .trim();
  }

  static String _extractProvider(String url) {
    if (url.contains('blogger.com')) return 'Blogger';
    if (url.contains('desustream')) return 'Desustream';
    if (url.contains('otakufiles')) return 'OtakuFiles';
    if (url.contains('pixeldrain')) return 'Pdrain';
    if (url.contains('acefile')) return 'Acefile';
    if (url.contains('gofile')) return 'GoFile';
    if (url.contains('mega.nz')) return 'Mega';
    if (url.contains('krakenfiles')) return 'KFiles';
    if (url.contains('googlevideo')) return 'GoogleVideo';
    return 'Unknown';
  }

  static bool isDirectVideoUrl(String url) {
    return url.contains('googlevideo.com') ||
           url.contains('googleusercontent.com') ||
           (url.contains('otakufiles.net') && 
            (url.contains('/files/') || url.contains('/download'))) ||
           url.endsWith('.mp4') ||
           url.endsWith('.mkv') ||
           url.endsWith('.m3u8') ||
           url.contains('videoplayback');
  }

  static void clearCache() {
    _resolveCache.clear();
    if (kDebugMode) print('🗑️ Resolver cache cleared');
  }

  static int get cacheSize => _resolveCache.length;
}