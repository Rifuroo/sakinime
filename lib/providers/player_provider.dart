import 'package:flutter/foundation.dart';
import '../services/zoro_service.dart';

class PlayerProvider extends ChangeNotifier {
  final ZoroService _service = ZoroService();

  bool isLoading = false;
  String? errorMessage;

  Map<String, String> headers = {};
  List<Map<String, dynamic>> subtitles = [];
  List<Map<String, dynamic>> qualities = [];

  String? currentQuality;
  String? currentUrl; // active playback url
  String? episodeId;
  String? server;
  bool dub = false;

  Future<void> loadEpisode(
    String episodeId, {
    String? server,
    bool dub = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    this.episodeId = episodeId;
    this.server = server;
    this.dub = dub;
    notifyListeners();

    try {
      final data = await _service.getQualities(episodeId, server: server, dub: dub);
      if (data == null) {
        throw Exception('No data');
      }

      headers = Map<String, String>.from(data['headers'] ?? {});
      subtitles = List<Map<String, dynamic>>.from(data['subtitles'] ?? []);

      // ✅ Parse qualities from sources
      final sources = List<Map<String, dynamic>>.from(data['sources'] ?? []);
      
      if (sources.isEmpty) {
        throw Exception('No sources available');
      }

      // Check if sources have multiple qualities or just master.m3u8
      final hasMultipleQualities = sources.length > 1 || 
          (sources.isNotEmpty && sources.first['quality'] != null);

      if (hasMultipleQualities) {
        // Multiple qualities available
        qualities = sources;
        qualities.sort((a, b) {
          final aq = _q(a['quality']);
          final bq = _q(b['quality']);
          return bq.compareTo(aq);
        });
        currentQuality = qualities.first['quality']?.toString() ?? 'auto';
        currentUrl = qualities.first['url']?.toString();
      } else {
        // Single source (usually master.m3u8 with adaptive streaming)
        qualities = [];
        currentQuality = 'auto';
        currentUrl = sources.first['url']?.toString();
      }

      if (kDebugMode) {
        print('✅ Player loaded:');
        print('   URL: $currentUrl');
        print('   Quality: $currentQuality');
        print('   Qualities available: ${qualities.length}');
        print('   Headers: ${headers.keys.join(", ")}');
        print('   Subtitles: ${subtitles.length}');
      }
    } catch (e) {
      errorMessage = 'Gagal memuat: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  void selectQuality(String q) {
    if (qualities.isEmpty) return;
    final match = qualities.firstWhere(
      (e) => (e['quality']?.toString() ?? '') == q,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      currentQuality = q;
      currentUrl = match['url']?.toString();
      notifyListeners();
    }
  }

  int _q(dynamic q) {
    try {
      final s = q?.toString() ?? '0';
      if (s.endsWith('p')) return int.tryParse(s.replaceAll('p', '')) ?? 0;
      if (s.endsWith('kbps')) return int.tryParse(s.replaceAll('kbps', '')) ?? 0;
      return int.tryParse(s) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
