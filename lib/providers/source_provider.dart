import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnimeSource {
  hianime,
  otakudesu,
  kuramanime,
}

class SourceProvider with ChangeNotifier {
  AnimeSource _currentSource = AnimeSource.hianime;
  static const String _storageKey = 'selected_anime_source';

  SourceProvider() {
    _loadSource();
  }

  AnimeSource get currentSource => _currentSource;

  String get baseUrl {
    switch (_currentSource) {
      case AnimeSource.hianime:
        return 'https://hianime-api-seven-steel.vercel.app/api/v1';
      case AnimeSource.otakudesu:
        return 'https://api-otakudesu-worker.joas77055.workers.dev/otakudesu/';
      case AnimeSource.kuramanime:
        return 'https://api-otakudesu-worker.joas77055.workers.dev/kuramanime/';
    }
  }

  bool get isIndoSource =>
      _currentSource == AnimeSource.otakudesu ||
      _currentSource == AnimeSource.kuramanime;

  Future<void> _loadSource() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_storageKey);
    if (index != null && index < AnimeSource.values.length) {
      _currentSource = AnimeSource.values[index];
      notifyListeners();
    }
  }

  Future<void> setSource(AnimeSource source) async {
    if (_currentSource == source) return;
    _currentSource = source;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, source.index);
  }
}
