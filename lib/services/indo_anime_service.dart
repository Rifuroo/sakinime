import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/anime_model.dart';
import '../models/indo_anime_models.dart';
import '../providers/source_provider.dart';

class IndoAnimeService {
  final Dio _dio;
  final AnimeSource source;

  IndoAnimeService({required String baseUrl, required this.source})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    if (kDebugMode) {
      print('🚀 IndoAnimeService initialized for $source at $baseUrl');
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ));
    }
  }

  Future<IndoHomeResponse?> getHome() async {
    try {
      if (source == AnimeSource.otakudesu) {
        // OtakuDesu worker is missing /home, fetch ongoing and completed in parallel
        if (kDebugMode)
          print('📡 fetching OtakuDesu ongoing and completed separately...');
        final futures = await Future.wait([
          _dio.get('ongoing'),
          _dio.get('completed'),
        ]);

        final ongoingData = futures[0].data['data'];
        final completedData = futures[1].data['data'];

        // Build the structure IndoHomeResponse expects
        final combinedData = {
          'ongoing': {'animeList': ongoingData},
          'completed': {'animeList': completedData},
        };

        return IndoHomeResponse.fromOtakuDesu(combinedData);
      } else {
        // Kuramanime has /home
        const path = 'home';
        final response = await _dio.get(path);
        final isSuccess = response.data['success'] == true ||
            response.data['statusCode'] == 200;

        if (response.statusCode == 200 && isSuccess) {
          final data = response.data['data'];
          if (kDebugMode) print('📦 Raw Indo Data: ${data.keys.toList()}');
          return IndoHomeResponse.fromKuramanime(data);
        } else {
          if (kDebugMode)
            print(
                '⚠️ Indo API Success false or Status Code ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ IndoAnimeService.getHome Error: $e');
    }
    return null;
  }

  Future<List<Anime>> search(String query) async {
    try {
      final path = source == AnimeSource.otakudesu ? 'search' : 'anime';
      final params =
          source == AnimeSource.otakudesu ? {'q': query} : {'search': query};

      final response = await _dio.get(path, queryParameters: params);
      final isSuccess = response.data['success'] == true ||
          response.data['statusCode'] == 200;

      if (response.statusCode == 200 && isSuccess) {
        final data = response.data['data'];
        final List? rawList = data['animeList'] ?? data['animes'];
        if (rawList != null) {
          return rawList
              .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ IndoAnimeService.search Error: $e');
    }
    return [];
  }

  Future<AnimeDetail?> getDetail(String id) async {
    try {
      // id for Kuramanime is expected as "animeId/animeSlug"
      final path = 'anime/$id';
      final response = await _dio.get(path);
      final isSuccess = response.data['success'] == true ||
          response.data['statusCode'] == 200;

      if (response.statusCode == 200 && isSuccess) {
        final data = response.data['data'];
        if (data is Map && data['details'] != null) {
          // Kuramanime format
          return AnimeDetail.fromJson(
              Map<String, dynamic>.from(data['details']));
        } else if (data is Map) {
          // OtakuDesu format (direct data or nested in data)
          return AnimeDetail.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ IndoAnimeService.getDetail Error: $e');
    }
    return null;
  }

  Future<List<StreamLink>> getStreamLinks(String episodeId) async {
    try {
      // OtakuDesu: /otakudesu/episode/{id}
      // Kuramanime: /kuramanime/episode/{animeId}/{animeSlug}/{id}
      final path = 'episode/$episodeId';
      final response = await _dio.get(path);
      final isSuccess = response.data['success'] == true ||
          response.data['statusCode'] == 200;

      if (response.statusCode == 200 && isSuccess) {
        final rawData = response.data['data'];
        final data = (rawData is Map && rawData['details'] != null)
            ? Map<String, dynamic>.from(rawData['details'])
            : Map<String, dynamic>.from(rawData);

        final List<StreamLink> links = [];

        // 1. Priority: Default Streaming URL (Ready to use)
        if (data['defaultStreamingUrl'] != null &&
            data['defaultStreamingUrl'].toString().isNotEmpty) {
          final streamUrl = data['defaultStreamingUrl'].toString();
          final resolved = await _resolveIframeLink(streamUrl);

          links.add(StreamLink(
            provider: 'Player 1 (Main)',
            url: resolved ?? streamUrl,
            type: resolved != null ? 'hls' : 'iframe',
            quality: 'Default',
            headers: getHeadersForUrl(resolved ?? streamUrl),
          ));
        }

        // 2. Secondary: Detailed Server/Quality List
        final server = data['server'];
        if (server is Map) {
          final List? qualities = server['qualityList'];
          if (qualities != null) {
            for (var q in qualities) {
              // Quality title often comes as "Mirror 360pvidhidefiledonmega" from API
              final qualityTitle =
                  _cleanQualityLabel(q['title']?.toString() ?? 'Default');

              // Handle serverList (OtakuDesu format)
              final List? serverList = q['serverList'];
              if (serverList != null) {
                for (var s in serverList) {
                  final id = s['serverId']?.toString() ?? '';
                  if (id.isNotEmpty) {
                    final resolved = await _resolveIframeLink(id);
                    links.add(StreamLink(
                      provider: s['title'] ?? 'Mirror',
                      url: resolved ?? id,
                      type: resolved != null ? 'hls' : 'iframe',
                      quality: qualityTitle,
                      headers: getHeadersForUrl(resolved ?? id),
                    ));
                  }
                }
              }

              // Handle urlList (Kuramanime format)
              final List? urlList = q['urlList'];
              if (urlList != null) {
                for (var u in urlList) {
                  final streamUrl = u['url'] ?? '';
                  final resolved = await _resolveIframeLink(streamUrl);
                  links.add(StreamLink(
                    provider: u['title'] ?? 'KuramaDrive',
                    url: resolved ?? streamUrl,
                    type: resolved != null ? 'hls' : 'iframe',
                    quality: qualityTitle,
                    headers: getHeadersForUrl(resolved ?? streamUrl),
                  ));
                }
              }
            }
          }
        }

        // If we found links, return them
        if (links.isNotEmpty) return links;

        // Fallback: Check if there's any other structure
        if (kDebugMode) print('⚠️ No structured streaming links found in data');
      }
    } catch (e) {
      if (kDebugMode) print('❌ IndoAnimeService.getStreamLinks Error: $e');
    }
    return [];
  }

  Future<String?> getServerUrl(String serverId) async {
    try {
      final path = 'server/$serverId';
      final response = await _dio.get(path);
      final isSuccess = response.data['success'] == true ||
          response.data['statusCode'] == 200;

      if (response.statusCode == 200 && isSuccess) {
        final data = response.data['data'];
        final url = (data is Map && data['details'] != null)
            ? data['details']['url']
            : data['url'];

        if (url != null) {
          final resolved = await _resolveIframeLink(url.toString());
          // If we couldn't resolve it to a direct link, returning null is safer
          // than passing the iframe URL to a native media player.
          return resolved;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ IndoAnimeService.getServerUrl Error: $e');
    }
    return null;
  }

  /// Resolves "iframe" links (like desustream) to direct media URLs if possible.
  Future<String?> _resolveIframeLink(String url) async {
    try {
      if (url.contains('desustream.info')) {
        // desustream has a ?mode=json endpoint that returns direct Blogger token
        final separator = url.contains('?') ? '&' : '?';
        final jsonUrl = '$url${separator}mode=json';

        if (kDebugMode) print('📡 Resolving desustream: $jsonUrl');

        final response = await _dio.get(
          jsonUrl,
          options: Options(headers: {
            'Referer': 'https://otakudesu.best/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
          }),
        );

        if (response.data != null && response.data['video'] != null) {
          final videoUrl = response.data['video'].toString();
          if (kDebugMode) print('✅ Resolved to Blogger: $videoUrl');

          // Deep resolve Blogger to get direct googlevideo link if possible
          final directUrl = await _deepResolveBlogger(videoUrl);
          return directUrl; // If null, we let caller handle failure
        }
      }

      if (url.contains('filedon.co')) {
        if (kDebugMode) print('📡 Deep resolving FileDon: $url');
        final directUrl = await _deepResolveFileDon(url);
        if (directUrl != null) {
          if (kDebugMode) print('✅ Resolved FileDon to direct R2: $directUrl');
          return directUrl;
        }
      }

      if (url.contains('vidhide') || url.contains('odvidhide')) {
        if (kDebugMode) print('📡 Deep resolving Vidhide: $url');
        final directUrl = await _deepResolveVidhide(url);
        if (directUrl != null) {
          if (kDebugMode)
            print('✅ Resolved Vidhide to direct M3U8: $directUrl');
          return directUrl;
        }
      }

      // If it's already a direct video link or we don't know how to resolve it
      if (url.endsWith('.mp4') || url.contains('.m3u8')) {
        return url;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to resolve iframe link $url: $e');
    }
    return null;
  }

  /// Deeply resolves Blogger URLs to extract direct googlevideo links.
  Future<String?> _deepResolveBlogger(String url) async {
    try {
      if (kDebugMode) print('🔍 Deep resolving Blogger: $url');

      final uri = Uri.parse(url);
      final token = uri.queryParameters['token'];
      if (token == null) {
        if (kDebugMode) print('⚠️ No token found in Blogger URL');
        return null;
      }

      // 1. First GET to get session/NID cookies
      final originalResponse = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer': 'https://desustream.info/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
          },
        ),
      );

      final cookies = originalResponse.headers['set-cookie']?.join('; ') ?? '';
      if (kDebugMode && cookies.isNotEmpty) {
        print('🍪 Captured Blogger cookies: ${cookies.length} chars');
      }

      // Strategy 1: The "video-play.mp4" redirect trick
      // This is often more reliable than HTML parsing because it's the actual stream endpoint
      try {
        final redirectUrl =
            'https://www.blogger.com/video-play.mp4?token=$token';
        if (kDebugMode)
          print('📡 Trying fallback redirect trick: $redirectUrl');

        final checkResponse = await _dio.get(
          redirectUrl,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Referer': url,
              'Cookie': cookies,
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
            },
          ),
        );

        if (checkResponse.statusCode == 302 ||
            checkResponse.statusCode == 301) {
          final location = checkResponse.headers.value('location');
          if (location != null &&
              (location.contains('googlevideo.com') ||
                  location.contains('videoplayback'))) {
            if (kDebugMode)
              print('✅ Success! Caught Blogger redirect to: $location');
            return location;
          }
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Redirect trick failed: $e');
      }

      // Strategy 2: HTML Parsing (Advanced)
      final html = originalResponse.data.toString();

      // Advanced regex to look for googlevideo links even if heavily escaped
      // We look for anything that contains googlevideo.com and ends before a quote or space
      final googleRegex = RegExp(
          r'https?[:\\/]+[^\s"<>|\\]+googlevideo\.com[^\s"<>|\\]+',
          caseSensitive: false);

      if (kDebugMode && !html.contains('googlevideo.com')) {
        print(
            '⚠️ Blogger HTML does not contain googlevideo.com. First 300 chars: ${html.substring(0, html.length > 300 ? 300 : html.length)}');
      }

      final matches = googleRegex.allMatches(html);
      for (final match in matches) {
        var directUrl = match.group(0)!;

        // Unescape manually
        directUrl = directUrl
            .replaceAll(r'\u0026', '&')
            .replaceAll(r'\u003d', '=')
            .replaceAll(r'\/', '/')
            .replaceAll(r'\\/', '/')
            .replaceAll(r'\\', '')
            .replaceAll('"', '')
            .replaceAll("'", "");

        if (directUrl.contains('videoplayback')) {
          if (kDebugMode)
            print('✅ Resolved Blogger via Advanced HTML Regex: $directUrl');
          return directUrl;
        }
      }

      // Strategy 3: Look for any "videoplayback" fallback
      if (html.contains('videoplayback')) {
        final vpRegex = RegExp(
            r'https?[:\\/]+[^\s"<>|\\]+videoplayback[^\s"<>|\\]+',
            caseSensitive: false);
        final vpMatch = vpRegex.firstMatch(html);
        if (vpMatch != null) {
          var directUrl = vpMatch
              .group(0)!
              .replaceAll(r'\/', '/')
              .replaceAll(r'\\/', '/')
              .replaceAll(r'\\', '');
          if (kDebugMode) print('✅ Found videoplayback fallback URL!');
          return directUrl;
        }
      }

      if (kDebugMode)
        print('❌ Blogger deep resolution failed to find playable URL');
    } catch (e) {
      if (kDebugMode) print('❌ Error in deep resolution: $e');
    }
    return null;
  }

  /// Deeply resolves FileDon URLs to extract direct media links from data-page.
  Future<String?> _deepResolveFileDon(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'Referer': 'https://otakudesu.best/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
        }),
      );

      final htmlContent = response.data.toString();

      // FileDon stores the direct R2 URL in a data-page JSON attribute
      // <div id="app" data-page="{...&quot;url&quot;:&quot;https:\/\/...&quot;...}">
      final dataPageRegex = RegExp(r'data-page="({.*?})"');
      final match = dataPageRegex.firstMatch(htmlContent);

      if (match != null) {
        final encodedJson = match.group(1)!;
        // Unescape HTML entities (simple version for &quot;)
        final jsonStr = encodedJson.replaceAll('&quot;', '"');
        final Map<String, dynamic> data = json.decode(jsonStr);

        // The URL is usually in props -> url
        final directUrl = data['props']?['url']?.toString();
        if (directUrl != null) {
          // Unescape &amp; and other common entities
          return directUrl.replaceAll('&amp;', '&').replaceAll(r'\/', '/');
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to deep resolve FileDon: $e');
    }
    return null;
  }

  /// Deeply resolves Vidhide URLs by unpacking obfuscated JS.
  Future<String?> _deepResolveVidhide(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'Referer': 'https://otakudesu.best/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
        }),
      );

      final html = response.data.toString();

      // Look for packed script: eval(function(p,a,c,k,e,d){...}('...',62,62,'...'.split('|')))
      final packedRegex = RegExp(
        r"eval\(function\(p,a,c,k,e,d\)\{.*?\}\('(.*?)',(\d+),(\d+),'(.*?)'\.split\('\|'\)\)\)",
        dotAll: true,
      );
      final match = packedRegex.firstMatch(html);

      if (match != null) {
        final p = match.group(1)!;
        final a = int.parse(match.group(2)!);
        final c = int.parse(match.group(3)!);
        final k = match.group(4)!.split('|');

        final unpacked = _unpackJS(p, a, c, k);
        if (unpacked != null) {
          final m3u8Regex =
              RegExp(r"https?://[^\s\x22\x27<>]+?\.(?:m3u8|mp4|mpd|webm)");
          final m3u8Match = m3u8Regex.firstMatch(unpacked);
          if (m3u8Match != null) {
            return m3u8Match.group(0);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to deep resolve Vidhide: $e');
    }
    return null;
  }

  /// Basic Dean Edwards P.A.C.K.E.R. unpacker.
  String? _unpackJS(String p, int a, int c, List<String> k) {
    String baseN(int n, int b) {
      const charset =
          '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      if (n == 0) return charset[0];
      var res = '';
      while (n > 0) {
        res = charset[n % b] + res;
        n = n ~/ b;
      }
      return res;
    }

    var result = p;
    for (var i = c - 1; i >= 0; i--) {
      if (k[i].isNotEmpty) {
        final pattern = RegExp('\\b${baseN(i, a)}\\b');
        result = result.replaceAll(pattern, k[i]);
      }
    }
    return result;
  }

  String _cleanQualityLabel(String raw) {
    if (raw.isEmpty) return 'Default';

    // Extract resolution patterns like 360p, 480p, 720p, 1080p
    final resMatch = RegExp(r'(\d{3,4}p)').firstMatch(raw);
    if (resMatch != null) {
      return resMatch.group(1)!;
    }

    // If no resolution found, just tidy up the string
    return raw.split(' ').lastWhere((e) => e.isNotEmpty, orElse: () => raw);
  }

  /// Returns appropriate headers (Referer, etc.) for a given stream URL.
  Map<String, String>? getHeadersForUrl(String url) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
    };

    if (url.contains('blogger.com')) {
      headers['Referer'] = 'https://desustream.info/';
    } else if (url.contains('otakudesu')) {
      headers['Referer'] = 'https://otakudesu.best/';
    } else if (url.contains('kuramanime')) {
      headers['Referer'] = 'https://v8.kuramanime.tel/';
    } else if (url.contains('desustream')) {
      headers['Referer'] = 'https://otakudesu.best/';
    }

    return headers;
  }
}
