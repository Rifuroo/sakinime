import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class M3U8Parser {
  /// Parse M3U8 master playlist and extract quality variants
  static Future<List<Map<String, dynamic>>> parseQualities(
    String masterUrl, {
    String referer = 'https://megacloud.tv',
  }) async {
    try {
      if (kDebugMode) print('🎬 Parsing M3U8 master playlist: $masterUrl');
      
      final response = await http.get(
        Uri.parse(masterUrl),
        headers: {
          'Referer': referer,
          'User-Agent': 'Sukinime/2.0',
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) print('   ❌ Failed to fetch M3U8: ${response.statusCode}');
        return [];
      }

      final content = response.body;
      final lines = content.split('\n');
      final qualities = <Map<String, dynamic>>[];
      
      String? currentResolution;
      int? currentBandwidth;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Parse #EXT-X-STREAM-INF line
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          // Extract RESOLUTION
          final resolutionMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          if (resolutionMatch != null) {
            final width = int.parse(resolutionMatch.group(1)!);
            final height = int.parse(resolutionMatch.group(2)!);
            currentResolution = '${width}x$height';
          }
          
          // Extract BANDWIDTH
          final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
          if (bandwidthMatch != null) {
            currentBandwidth = int.parse(bandwidthMatch.group(1)!);
          }
          
          // Next line should be the variant URL
          if (i + 1 < lines.length) {
            final variantUrl = lines[i + 1].trim();
            if (variantUrl.isNotEmpty && !variantUrl.startsWith('#')) {
              // Build full URL if relative
              String fullUrl = variantUrl;
              if (!variantUrl.startsWith('http')) {
                final baseUrl = masterUrl.substring(0, masterUrl.lastIndexOf('/') + 1);
                fullUrl = baseUrl + variantUrl;
              }
              
              // Determine quality label from resolution
              String qualityLabel = 'auto';
              if (currentResolution != null) {
                final height = int.parse(currentResolution.split('x')[1]);
                qualityLabel = '${height}p';
              }
              
              // Calculate estimated size (MB) from bandwidth
              String? size;
              if (currentBandwidth != null) {
                // Assume 24 minutes average (1440 seconds)
                final sizeInMb = (currentBandwidth / 8 / 1048576) * 1440;
                size = '${sizeInMb.round()} MB';
              }
              
              qualities.add({
                'quality': qualityLabel,
                'resolution': currentResolution ?? 'Unknown',
                'bandwidth': currentBandwidth,
                'size': size,
                'url': fullUrl,
                'file': fullUrl,
                'type': 'hls',
              });
              
              // Reset for next variant
              currentResolution = null;
              currentBandwidth = null;
            }
          }
        }
      }
      
      // Sort by quality (highest first)
      qualities.sort((a, b) {
        final aHeight = int.tryParse(a['quality'].toString().replaceAll('p', '')) ?? 0;
        final bHeight = int.tryParse(b['quality'].toString().replaceAll('p', '')) ?? 0;
        return bHeight.compareTo(aHeight);
      });
      
      if (kDebugMode) {
        print('   ✅ Found ${qualities.length} quality variants:');
        for (var q in qualities) {
          print('      - ${q['quality']}: ${q['resolution']} (${q['size'] ?? 'Unknown size'})');
        }
      }
      
      return qualities;
    } catch (e) {
      if (kDebugMode) print('   ❌ M3U8 parsing error: $e');
      return [];
    }
  }
}
