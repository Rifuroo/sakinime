// services/aggressive_blogger_resolver.dart - WITH OTAKUFILES FIX
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';
import 'otakufiles_resolver.dart'; // Import the dedicated resolver

class AggressiveBloggerResolver {
  static final Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (status) => status! < 500,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static final Map<String, String?> _resolveCache = {};
  static int _requestCount = 0;

  /// Main resolver
  static Future<String?> resolveToDirectVideo(String url, {int depth = 0}) async {
    if (depth > 2) {
      if (kDebugMode) print('${"  " * depth}⚠️ Max depth reached');
      return null;
    }

    // Check cache
    if (_resolveCache.containsKey(url)) {
      if (kDebugMode) print('💾 CACHE HIT: ${_extractProvider(url)}');
      return _resolveCache[url];
    }

    try {
      if (kDebugMode) {
        print('\n${"  " * depth}🔗 RESOLVING: ${_extractProvider(url)}');
        print('${"  " * depth}   URL: ${url.substring(0, url.length > 80 ? 80 : url.length)}...');
      }

      // Rate limiting
      _requestCount++;
      if (_requestCount % 3 == 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Skip known bad URLs
      if (_isBadHost(url)) {
        if (kDebugMode) print('${"  " * depth}⚠️ SKIP: Bad host');
        _resolveCache[url] = null;
        return null;
      }

      // 🔥 PRIORITY 0: OtakuFiles - Use dedicated resolver
      if (url.contains('otakufiles.net')) {
        if (kDebugMode) print('${"  " * depth}🎯 OTAKUFILES: Using dedicated resolver');
        final result = await OtakuFilesResolver.resolveToDirectDownload(url);
        _resolveCache[url] = result;
        return result;
      }

      // Direct file check
      if (_isDirectFile(url)) {
        if (kDebugMode) print('${"  " * depth}✅ DIRECT: Already video file');
        _resolveCache[url] = url;
        return url;
      }

      // FETCH HTML
      final response = await _dio.get(
        url,
        options: Options(
          followRedirects: true,
          maxRedirects: 10,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
            'Referer': 'https://otakudesu.cloud/',
            'Origin': 'https://otakudesu.cloud',
            'Cache-Control': 'no-cache',
            'Sec-Fetch-Dest': 'iframe',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'cross-site',
          },
        ),
      );

      if (kDebugMode) print('${"  " * depth}   Status: ${response.statusCode}');

      final htmlContent = response.data.toString();
      
      if (kDebugMode) print('${"  " * depth}   HTML: ${htmlContent.length} bytes');

      // Check if redirect happened
      final finalUrl = response.realUri.toString();
      if (finalUrl != url && _isDirectFile(finalUrl)) {
        if (kDebugMode) print('${"  " * depth}✅ REDIRECT: Direct video');
        _resolveCache[url] = finalUrl;
        return finalUrl;
      }

      // Check if redirected to OtakuFiles
      if (finalUrl.contains('otakufiles.net') && finalUrl != url) {
        if (kDebugMode) print('${"  " * depth}🔄 REDIRECT to OtakuFiles, resolving...');
        final result = await OtakuFilesResolver.resolveToDirectDownload(finalUrl);
        _resolveCache[url] = result;
        return result;
      }

      // PRIORITY 1: Blogger extraction
      final bloggerResults = _extractBloggerFromHtml(htmlContent, depth);
      if (bloggerResults != null && bloggerResults.isNotEmpty) {
        final bestUrl = bloggerResults.first;
        if (kDebugMode) print('${"  " * depth}✅ BLOGGER: ${bloggerResults.length} links');
        _resolveCache[url] = bestUrl;
        return bestUrl;
      }

      // PRIORITY 2: Parse HTML for iframes & video tags
      final document = html_parser.parse(htmlContent);
      
      // Find Blogger iframes
      final bloggerIframes = _findBloggerIframes(document, htmlContent);
      for (final iframeUrl in bloggerIframes) {
        if (kDebugMode) print('${"  " * depth}🔍 Blogger iframe...');
        
        try {
          final iframeResponse = await _dio.get(
            iframeUrl,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': url,
                'Accept': '*/*',
              },
              validateStatus: (status) => status! < 500,
            ),
          );
          
          final iframeResults = _extractBloggerFromHtml(iframeResponse.data.toString(), depth);
          if (iframeResults != null && iframeResults.isNotEmpty) {
            final bestUrl = iframeResults.first;
            if (kDebugMode) print('${"  " * depth}✅ Blogger iframe success');
            _resolveCache[url] = bestUrl;
            return bestUrl;
          }
        } catch (e) {
          if (kDebugMode) print('${"  " * depth}⚠️ Blogger iframe failed');
        }
        
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // PRIORITY 3: Check for OtakuFiles in HTML
      final otakuMatches = RegExp(r'https?://otakufiles\.net/[a-zA-Z0-9]+/[^\s"' + "'" + r'<>]+')
          .allMatches(htmlContent);
      
      for (final match in otakuMatches.take(1)) {
        final otakuUrl = match.group(0)!;
        if (kDebugMode) print('${"  " * depth}🔍 Found OtakuFiles in HTML');
        final result = await OtakuFilesResolver.resolveToDirectDownload(otakuUrl);
        if (result != null) {
          _resolveCache[url] = result;
          return result;
        }
      }

      // PRIORITY 4: JavaScript variables
      final jsVarResult = _extractFromJsVariables(htmlContent, depth);
      if (jsVarResult != null) {
        _resolveCache[url] = jsVarResult;
        return jsVarResult;
      }

      // PRIORITY 5: Aggressive regex patterns
      final regexResult = _extractWithAggressiveRegex(htmlContent, depth);
      if (regexResult != null) {
        _resolveCache[url] = regexResult;
        return regexResult;
      }

      // PRIORITY 6: Base64 decoding
      final base64Result = _extractFromBase64(htmlContent, depth);
      if (base64Result != null) {
        _resolveCache[url] = base64Result;
        return base64Result;
      }

      // PRIORITY 7: Nested iframes (video embeds)
      final nestedIframes = _findNestedIframes(document);
      if (kDebugMode) print('${"  " * depth}🔍 Nested: ${nestedIframes.length}');
      
      for (final nestedUrl in nestedIframes.take(3)) {
        if (_isVideoEmbedUrl(nestedUrl) && nestedUrl != url) {
          if (kDebugMode) print('${"  " * depth}🔄 Following iframe...');
          
          final result = await resolveToDirectVideo(nestedUrl, depth: depth + 1);
          if (result != null) {
            _resolveCache[url] = result;
            return result;
          }
        }
      }

      if (kDebugMode) print('${"  " * depth}❌ No video found');
      _resolveCache[url] = null;
      return null;

    } on DioException catch (e) {
      if (kDebugMode) print('${"  " * depth}⚠️ ERROR: ${e.type} - ${e.message}');
      _resolveCache[url] = null;
      return null;
    } catch (e) {
      if (kDebugMode) print('${"  " * depth}⚠️ ERROR: $e');
      _resolveCache[url] = null;
      return null;
    }
  }

  /// Extract Blogger video URLs from HTML
  static List<String>? _extractBloggerFromHtml(String html, int depth) {
    final qualities = <String>[];

    // Method 1: streams array with format_note
    final streamsPattern = RegExp(r'"streams":\s*\[([^\]]+)\]');
    final streamsMatch = streamsPattern.firstMatch(html);
    
    if (streamsMatch != null) {
      try {
        final streamsContent = streamsMatch.group(1)!;
        final playUrlPattern = RegExp(r'"play_url":"([^"]+)"[^}]*"format_note":"([^"]+)"');
        final playUrlMatches = playUrlPattern.allMatches(streamsContent);
        
        for (final match in playUrlMatches) {
          String videoUrl = match.group(1)!
              .replaceAll(r'\u0026', '&')
              .replaceAll('\\', '');
          
          if (videoUrl.contains('videoplayback')) {
            qualities.add(videoUrl);
          }
        }
      } catch (e) {
        // Continue to next method
      }
    }

    // Method 2: progressive_url
    if (qualities.isEmpty) {
      final progressivePattern = RegExp(r'"progressive_url":"([^"]+)"');
      final progressiveMatch = progressivePattern.firstMatch(html);
      
      if (progressiveMatch != null) {
        String videoUrl = progressiveMatch.group(1)!
            .replaceAll(r'\u0026', '&')
            .replaceAll('\\', '');
        qualities.add(videoUrl);
      }
    }

    // Method 3: play_url
    if (qualities.isEmpty) {
      final playUrlPattern = RegExp(r'"play_url":"([^"]+)"');
      final playUrlMatch = playUrlPattern.firstMatch(html);
      
      if (playUrlMatch != null) {
        String videoUrl = playUrlMatch.group(1)!
            .replaceAll(r'\u0026', '&')
            .replaceAll('\\', '');
        qualities.add(videoUrl);
      }
    }

    // Remove duplicates and validate
    final unique = qualities.toSet().where(_isValidVideoUrl).toList();
    
    if (unique.isNotEmpty && kDebugMode) {
      print('${"  " * depth}📺 Blogger: ${unique.length} qualities');
    }
    
    return unique.isNotEmpty ? unique : null;
  }

  /// Find Blogger iframes in HTML
  static List<String> _findBloggerIframes(dom.Document document, String html) {
    final bloggerUrls = <String>{};
    
    // Parse with DOM
    final iframes = document.querySelectorAll('iframe[src]');
    for (final iframe in iframes) {
      final src = iframe.attributes['src'];
      if (src != null && 
          (src.contains('blogger.com/video') || src.contains('blogspot.com'))) {
        bloggerUrls.add(src.replaceAll('&amp;', '&'));
      }
    }

    // Regex fallback
    final iframePatterns = [
      RegExp(r'''<iframe[^>]+src=["']([^"']*blogger\.com/video[^"']*)''', caseSensitive: false),
      RegExp(r'''<iframe[^>]+src=["']([^"']*blogspot\.com[^"']*)''', caseSensitive: false),
      RegExp(r'''src=["']([^"']*blogger\.com/video[^"']*)''', caseSensitive: false),
      RegExp(r'''href=["']([^"']*blogger\.com/video[^"']*)''', caseSensitive: false),
    ];

    for (final pattern in iframePatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        final bloggerUrl = match.group(1)!
            .replaceAll('&amp;', '&')
            .replaceAll('\\', '');
        
        if (bloggerUrl.startsWith('http')) {
          bloggerUrls.add(bloggerUrl);
        }
      }
    }

    return bloggerUrls.toList();
  }

  /// Extract from JavaScript variables
  static String? _extractFromJsVariables(String html, int depth) {
    final jsPatterns = [
      RegExp(r'''(?:var|let|const)\s+(?:video|stream|source|file|url)\s*=\s*["']([^"']+\.(?:mp4|m3u8)[^"']*)["']''', caseSensitive: false),
      RegExp(r'''["'](?:video|stream|source|file|url)["']\s*:\s*["']([^"']+\.(?:mp4|m3u8)[^"']*)["']''', caseSensitive: false),
      RegExp(r'''videoUrl\s*=\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''streamUrl\s*=\s*["']([^"']+)["']''', caseSensitive: false),
    ];

    for (final pattern in jsPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final videoUrl = match.group(1)!.replaceAll('\\', '');
        
        if (_isValidVideoUrl(videoUrl)) {
          if (kDebugMode) print('${"  " * depth}✅ JS VAR: ${videoUrl.substring(0, 60)}...');
          return videoUrl;
        }
      }
    }

    return null;
  }

  /// Extract with aggressive regex patterns
  static String? _extractWithAggressiveRegex(String html, int depth) {
    final patterns = [
      RegExp(r'''https?://[^"'\s<>]*googlevideo\.com[^"'\s<>]*videoplayback[^"'\s<>]*''', caseSensitive: false),
      RegExp(r'''https?://[^"'\s<>]+\.mp4(?:[?#][^"'\s<>]*)?''', caseSensitive: false),
      RegExp(r'''https?://[^"'\s<>]+\.m3u8(?:[?#][^"'\s<>]*)?''', caseSensitive: false),
      RegExp(r'"(?:file|url|src|source)":\s*"([^"]+\.(?:mp4|m3u8)[^"]*)"', caseSensitive: false),
      RegExp(r'"(?:progressive_url|play_url)":\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'''source:\s*["']([^"']+\.(?:mp4|m3u8))["']''', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        String videoUrl = (match.groupCount > 0 ? match.group(1) : match.group(0)) ?? '';
        videoUrl = videoUrl
            .replaceAll(r'\u0026', '&')
            .replaceAll('\\', '');
        
        if (_isValidVideoUrl(videoUrl) && videoUrl.startsWith('http')) {
          if (kDebugMode) print('${"  " * depth}✅ REGEX: ${videoUrl.substring(0, 60)}...');
          return videoUrl;
        }
      }
    }

    return null;
  }

  /// Extract from Base64 encoded data
  static String? _extractFromBase64(String html, int depth) {
    final base64Patterns = [
      RegExp(r'''atob\(["']([A-Za-z0-9+/=]{30,})["']''', caseSensitive: false),
      RegExp(r'''Base64\.decode\(["']([A-Za-z0-9+/=]{30,})["']''', caseSensitive: false),
      RegExp(r'''data-video=["']([A-Za-z0-9+/=]{30,})["']''', caseSensitive: false),
    ];

    for (final pattern in base64Patterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        try {
          final base64Str = match.group(1)!;
          final decoded = utf8.decode(base64.decode(base64Str));
          
          final urlMatch = RegExp(r'''https?://[^\s"']+\.(?:mp4|m3u8)''').firstMatch(decoded);
          if (urlMatch != null) {
            final videoUrl = urlMatch.group(0)!;
            if (kDebugMode) print('${"  " * depth}✅ BASE64: ${videoUrl.substring(0, 60)}...');
            return videoUrl;
          }
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  /// Find nested iframes
  static List<String> _findNestedIframes(dom.Document document) {
    final iframes = <String>[];
    
    final iframeElements = document.querySelectorAll('iframe[src], [data-src]');
    for (final el in iframeElements) {
      final src = el.attributes['src'] ?? el.attributes['data-src'];
      if (src != null && src.startsWith('http')) {
        iframes.add(src);
      }
    }

    return iframes;
  }

  /// Check if URL is a video embed
  static bool _isVideoEmbedUrl(String url) {
    final videoProviders = [
      'blogger.com/video',
      'blogspot.com',
      'googlevideo.com',
      'desustream.info',
      'desustream.com',
      'streamtape.com',
      'mp4upload.com',
      'acefile.co',
      'filelions.com',
      'vidguard.to',
      'streamwish.to',
      'wishfast.top',
      'otakufiles.net',
    ];

    final skipPatterns = [
      'safelink',
      'racaty',
      'gdrive',
      'drive.google',
      'zippyshare',
      'mega.nz',
      'mediafire',
    ];

    final urlLower = url.toLowerCase();
    
    if (skipPatterns.any((pattern) => urlLower.contains(pattern))) {
      return false;
    }

    return videoProviders.any((provider) => urlLower.contains(provider));
  }

  /// Check if URL is direct video file
  static bool _isDirectFile(String url) {
    final lowerUrl = url.toLowerCase();
    
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

  /// Check if URL is valid video URL
  static bool _isValidVideoUrl(String url) {
    if (url.length < 10) return false;
    if (_isBadHost(url)) return false;
    
    final invalid = ['logo', 'icon', 'thumb', 'preview', 'banner', 'ad', 'analytics', '.js', '.css', '.png', '.jpg'];
    if (invalid.any((pattern) => url.toLowerCase().contains(pattern))) {
      return false;
    }
    
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Check if host is bad
  static bool _isBadHost(String url) {
    final lowerUrl = url.toLowerCase();
    final badHosts = [
      'favicon',
      '.css',
      '.js',
      '.ico',
      'jquery',
      'bootstrap',
      'logo',
      'icon',
      'thumb',
      'banner',
    ];
    
    return badHosts.any((host) => lowerUrl.contains(host));
  }

  /// Extract provider name from URL
  static String _extractProvider(String url) {
    if (url.contains('blogger.com')) return 'Blogger';
    if (url.contains('desustream')) return 'Desustream';
    if (url.contains('otakufiles')) return 'OtakuFiles';
    if (url.contains('pixeldrain')) return 'Pdrain';
    if (url.contains('acefile')) return 'Acefile';
    if (url.contains('streamtape')) return 'Streamtape';
    if (url.contains('mp4upload')) return 'MP4Upload';
    if (url.contains('googlevideo')) return 'GoogleVideo';
    return 'Unknown';
  }

  /// Check if URL is direct video URL
  static bool isDirectVideoUrl(String url) {
    return url.contains('googlevideo.com') ||
           url.contains('googleusercontent.com') ||
           url.contains('videoplayback') ||
           _isDirectFile(url);
  }

  /// Clear cache
  static void clearCache() {
    _resolveCache.clear();
    OtakuFilesResolver.clearCache();
    if (kDebugMode) print('🗑️ Resolver cache cleared');
  }

  /// Get cache size
  static int get cacheSize => _resolveCache.length;
}