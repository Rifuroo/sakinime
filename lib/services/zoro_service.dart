// services/zoro_service.dart - HiAnime API v2.0.0
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../utils/m3u8_parser.dart';

class ZoroService {
  static final ZoroService _instance = ZoroService._internal();
  factory ZoroService() => _instance;

  // ✅ NEW API BASE URL
  final String baseUrl = 'https://api.animo.qzz.io/api/v1';
  late final Dio _dio;

  ZoroService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'Sukinime/2.0',
      },
      validateStatus: (code) => code != null && code < 500,
    ));
  }

  /// ✅ GET STREAM - /stream?id={episodeId}&type={sub/dub}&server={hd-1/hd-2}
  Future<Map<String, dynamic>?> getQualities(
    String episodeId, {
    String? server,
    bool dub = false,
  }) async {
    if (kDebugMode) {
      print('🎬 ZoroService.getQualities:');
      print('   Episode ID: $episodeId');
      print('   Server: $server');
      print('   Dub: $dub');
    }

    try {
      // Clean episode ID
      String cleanId = episodeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      if (cleanId.endsWith('/')) cleanId = cleanId.substring(0, cleanId.length - 1);
      
      final type = dub ? 'dub' : 'sub';
      final serverName = server ?? 'hd-2';
      
      final params = {'id': cleanId, 'type': type, 'server': serverName};
      
      if (kDebugMode) print('   📡 Params: $params');
      
      final response = await _dio.get('/stream', queryParameters: params);
      
      if (kDebugMode) print('   ✅ Status: ${response.statusCode}');


      if (response.statusCode == 200) {
        final responseData = response.data;
        
        if (responseData is Map) {
          Map<dynamic, dynamic>? data;
          
          // Handle wrapped format: { success: true, data: {...} }
          if (responseData['success'] == true && responseData['data'] is Map) {
            data = responseData['data'] as Map;
          } else if (responseData['link'] != null || responseData['tracks'] != null) {
            data = responseData;
          }
          
          if (data != null) {
            if (kDebugMode) print('   📦 Data keys: ${data.keys.toList()}');
            
            // NEW: Parse sources following Expo parity logic (Qualities + Sources fallback)
            final sources = <Map<String, dynamic>>[];
            final List qualitiesList = (data['qualities'] is List) ? data['qualities'] : [];
            final List sourcesList = (data['sources'] is List) ? data['sources'] : [];
            final allFound = [...qualitiesList, ...sourcesList];
            
            if (allFound.isNotEmpty) {
              for (var s in allFound) {
                if (s is Map) {
                  final qLabel = s['quality']?.toString() ?? s['label']?.toString() ?? 'auto';
                  final videoUrl = s['url']?.toString() ?? s['file']?.toString() ?? '';
                  
                  if (videoUrl.isNotEmpty && !sources.any((e) => e['quality'] == qLabel)) {
                    sources.add({
                      'url': videoUrl,
                      'quality': qLabel,
                      'type': s['type']?.toString() ?? (videoUrl.contains('.m3u8') ? 'hls' : 'mp4'),
                      'size': s['size']?.toString(),
                    });
                  }
                }
              }
            } 
            
            if (sources.isEmpty && data['link'] is Map && data['link']['file'] != null) {
              final link = data['link'];
              sources.add({
                'url': link['file'].toString(),
                'quality': 'auto',
                'type': 'hls',
              });
            }

            if (kDebugMode) {
               print('   📊 Sources Found: ${sources.length}');
               for (var s in sources) print('      - ${s['quality']}: ${s['url'].toString().substring(0, min(30, s['url'].toString().length))}...');
               print('   🔍 RAW API DATA KEYS: ${data.keys.toList()}');
               print('   🔍 RAW qualities field: ${data['qualities']}');
               print('   🔍 RAW sources field: ${data['sources']}');
               print('   🔍 RAW link field: ${data['link']}');
            }
            
            // If only 'auto' quality found, try to parse M3U8 master playlist
            if (sources.length == 1 && sources[0]['quality'] == 'auto') {
              final masterUrl = sources[0]['url'].toString();
              if (masterUrl.contains('master.m3u8')) {
                if (kDebugMode) print('   🔍 Detected master.m3u8, parsing quality variants...');
                
                try {
                  // Extract directUrl if available (non-proxied)
                  String urlToParse = masterUrl;
                  if (data['link'] is Map && data['link']['directUrl'] != null) {
                    urlToParse = data['link']['directUrl'].toString();
                  }
                  
                  final qualities = await M3U8Parser.parseQualities(urlToParse);
                  
                  if (qualities.isNotEmpty) {
                    // Use Direct URLs with Headers instead of Proxy
                    // Proxying M3U8 breaks relative paths in sub-manifests
                    sources.clear();
                    for (var q in qualities) {
                      sources.add({
                        'url': q['url'],
                        'quality': q['quality'],
                        'type': 'hls',
                        'size': q['size'],
                        'resolution': q['resolution'],
                        'headers': {
                          'Referer': 'https://megacloud.tv',
                          'User-Agent': 'Sukinime/2.0',
                          'Origin': 'https://megacloud.tv',
                        }
                      });
                    }
                    
                    if (kDebugMode) print('   ✅ Replaced with ${sources.length} parsed qualities (Direct URL)');
                  }
                } catch (e) {
                  if (kDebugMode) print('   ⚠️ M3U8 parsing failed: $e');
                }
              }
            }
            
            // Parse subtitles from 'tracks'
            final subtitles = <Map<String, dynamic>>[];
            
            if (data['tracks'] is List) {
              for (var track in data['tracks']) {
                if (track is Map) {
                  final kind = track['kind']?.toString() ?? '';
                  if (kind != 'thumbnails') {
                    final subUrl = track['file']?.toString() ?? '';
                    if (subUrl.isNotEmpty) {
                      subtitles.add({
                        'url': subUrl,
                        'lang': track['label']?.toString() ?? 'Unknown',
                        'label': track['label']?.toString() ?? 'Unknown',
                        'default': track['default'] == true,
                      });
                    }
                  }
                }
              }
            } else if (data['subtitles'] is List) {
              for (var sub in data['subtitles']) {
                if (sub is Map) {
                  subtitles.add({
                    'url': sub['url']?.toString() ?? sub['file']?.toString() ?? '',
                    'lang': sub['lang']?.toString() ?? sub['label']?.toString() ?? 'Unknown',
                    'label': sub['lang']?.toString() ?? sub['label']?.toString() ?? 'Unknown',
                    'default': sub['default'] == true,
                  });
                }
              }
            }
            
            final result = <String, dynamic>{
              'sources': sources,
              'subtitles': subtitles,
              'headers': data['headers'] ?? {},
              'intro': data['intro'],
              'outro': data['outro'],
              'server': data['server'],
            };
            
            if (kDebugMode) print('   ✅ Parsed: ${sources.length} sources, ${subtitles.length} subtitles');
            return result;
          }
          
          if (kDebugMode) print('   ⚠️ Using raw response data');
          return Map<String, dynamic>.from(responseData);
        }
      }
      
      // Try alternate server if first fails
      if (server == null || server == 'hd-2') {
        if (kDebugMode) print('   ⚠️ Trying alternate server hd-1...');
        return await getQualities(episodeId, server: 'hd-1', dub: dub);
      }
      
    } catch (e) {
      if (kDebugMode) print('   ❌ Error: $e');
      
      if (server == null || server == 'hd-2') {
        try {
          return await getQualities(episodeId, server: 'hd-1', dub: dub);
        } catch (_) {}
      }
    }
    
    return null;
  }


  /// ✅ GET SERVERS - /servers?id={episodeId}
  Future<Map<String, dynamic>?> getServers(String episodeId) async {
    if (kDebugMode) print('🎬 ZoroService.getServers: $episodeId');

    try {
      String cleanId = episodeId.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      if (cleanId.endsWith('/')) cleanId = cleanId.substring(0, cleanId.length - 1);
      
      final response = await _dio.get('/servers', queryParameters: {'id': cleanId});
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          if (kDebugMode) print('   ✅ Servers loaded');
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('   ❌ Error: $e');
    }
    
    return null;
  }

  /// ✅ GET ANIME INFO - /anime/{id}
  Future<Map<String, dynamic>?> getInfo(String id) async {
    if (kDebugMode) print('🎬 ZoroService.getInfo: $id');
    
    try {
      String cleanId = id.trim();
      if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
      if (cleanId.endsWith('/')) cleanId = cleanId.substring(0, cleanId.length - 1);
      
      final response = await _dio.get('/anime/$cleanId');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('   ❌ Error: $e');
    }
    
    return null;
  }

  /// ✅ SEARCH - /search?keyword={query}&page={page}
  Future<Map<String, dynamic>?> search(String query, {int page = 1}) async {
    if (kDebugMode) print('🔍 ZoroService.search: $query (page: $page)');
    
    try {
      final response = await _dio.get('/search', queryParameters: {
        'keyword': query,
        'page': page,
      });
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      if (kDebugMode) print('   ❌ Error: $e');
    }
    
    return null;
  }

  /// ✅ GET QUALITIES WITH SUBTITLES - wrapper method
  Future<Map<String, dynamic>?> getQualitiesWithSubtitles(String episodeId) async {
    var result = await getQualities(episodeId, dub: false);
    
    if (result != null) {
      final subtitles = result['subtitles'];
      if (subtitles == null || (subtitles is List && subtitles.isEmpty)) {
        if (kDebugMode) print('   ⚠️ No subtitles in sub, trying dub...');
        final dubResult = await getQualities(episodeId, dub: true);
        if (dubResult != null) {
          final dubSubs = dubResult['subtitles'];
          if (dubSubs is List && dubSubs.isNotEmpty) {
            result['subtitles'] = dubSubs;
          }
        }
      }
    }
    
    return result;
  }

  /// ✅ CHECK HLS FOR SUBTITLES
  Future<bool> checkHLSForSubtitles(String hlsUrl) async {
    try {
      if (kDebugMode) print('🔍 Checking HLS manifest: $hlsUrl');
      
      final response = await http.get(Uri.parse(hlsUrl));
      if (response.statusCode == 200) {
        final manifest = response.body;
        final hasSubtitles = manifest.contains('#EXT-X-MEDIA:TYPE=SUBTITLES') ||
                           manifest.contains('SUBTITLES=') ||
                           manifest.contains('.vtt') ||
                           manifest.contains('captions');
        
        if (kDebugMode) print(hasSubtitles ? '✅ HLS has subtitles' : '❌ No subtitles in HLS');
        return hasSubtitles;
      }
    } catch (e) {
      if (kDebugMode) print('❌ HLS check error: $e');
    }
    
    return false;
  }

  /// ✅ GET AVAILABLE SERVERS
  Future<List<Map<String, dynamic>>> getAvailableServers(String episodeId) async {
    final servers = await getServers(episodeId);
    if (servers == null) return [];
    
    final result = <Map<String, dynamic>>[];
    
    if (servers['sub'] is List) {
      for (var server in servers['sub']) {
        if (server is Map) {
          result.add({
            'name': server['name'] ?? server['serverName'] ?? 'Unknown',
            'type': 'sub',
            'serverId': server['serverId'] ?? server['id'],
          });
        }
      }
    }
    
    if (servers['dub'] is List) {
      for (var server in servers['dub']) {
        if (server is Map) {
          result.add({
            'name': server['name'] ?? server['serverName'] ?? 'Unknown',
            'type': 'dub',
            'serverId': server['serverId'] ?? server['id'],
          });
        }
      }
    }
    
    return result;
  }

  /// ✅ GET PROXY URL
  String getProxyUrl(String url, {String referer = 'https://megacloud.tv'}) {
    final encodedUrl = Uri.encodeComponent(url);
    final encodedReferer = Uri.encodeComponent(referer);
    return '$baseUrl/proxy?url=$encodedUrl&referer=$encodedReferer';
  }

  /// ✅ GET EMBED URL
  String getEmbedUrl(String episodeId, {String server = 'hd-2', String type = 'sub'}) {
    return '$baseUrl/embed?id=$episodeId&server=$server&type=$type';
  }
}
