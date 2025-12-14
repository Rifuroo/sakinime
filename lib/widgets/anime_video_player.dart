// widgets/anime_video_player.dart - PROFESSIONAL STREAMING UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/anime_model.dart';
import '../services/zoro_service.dart';
import 'anime_webview_player.dart';
import 'dart:async';

class AnimeVideoPlayer extends StatefulWidget {
  final Episode episodeToLoad;
  final String animeTitle;
  final List<Episode> allEpisodes;
  final String? animePoster;

  const AnimeVideoPlayer({
    super.key,
    required this.episodeToLoad,
    required this.animeTitle,
    required this.allEpisodes,
    this.animePoster,
  });

  @override
  State<AnimeVideoPlayer> createState() => _AnimeVideoPlayerState();
}

class _AnimeVideoPlayerState extends State<AnimeVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  StreamLink? _currentStreamLink;
  List<StreamLink> _allAvailableQualities = [];
  Episode? _currentEpisode;
  List<Subtitle> _subtitles = []; // ✅ Parsed subtitles
  String _currentSubtitle = ''; // ✅ Current subtitle text to display
  List<Map<String, String>> _availableSubtitles = []; // ✅ Available subtitle languages
  String _selectedSubtitleLang = 'English'; // ✅ Selected subtitle language
  
  bool _isLoadingEpisode = true;
  bool _isLoadingPlayer = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _subtitleTimer; // ✅ Timer to update subtitles
  
  // Performance optimization: track previous states to avoid unnecessary rebuilds
  bool _previousIsPlaying = false;
  Duration _previousPosition = Duration.zero;
  String _previousSubtitle = '';
  
  int _currentPage = 0;
  static const int _episodesPerPage = 12;
  
  static const platform = MethodChannel('com.sukinime/pip');
  bool _isPiPSupported = false;
  bool _isInPiP = false;
  
  // Cache for extracted URLs
  static final Map<String, List<StreamLink>> _episodeCache = {};
  static final Map<String, List<Map<String, String>>> _subtitleCache = {}; // ✅ Cache subtitle data
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentEpisode = widget.episodeToLoad;
    _enableWakelock();
    _checkPiPSupport();
    _setupPiPListener();
    _hideSystemUI();
    _loadEpisodeAndPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isInPiP && state == AppLifecycleState.paused) return;
    if (state == AppLifecycleState.paused) {
      _disableWakelock();
    } else if (state == AppLifecycleState.resumed && _videoController?.value.isPlaying == true) {
      _enableWakelock();
      _hideSystemUI();
    }
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {}
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {}
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    if (_videoController?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && _videoController?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  Future<void> _checkPiPSupport() async {
    try {
      final bool result = await platform.invokeMethod('isPiPSupported');
      if (mounted) setState(() => _isPiPSupported = result);
    } catch (e) {}
  }

  void _setupPiPListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isInPiP = call.arguments['isInPiP'] ?? false;
        if (mounted) {
          setState(() => _isInPiP = isInPiP);
          if (isInPiP && _videoController != null && !_videoController!.value.isPlaying) {
            _videoController!.play();
            _enableWakelock();
          }
        }
      }
    });
  }

  Future<void> _enterPiP() async {
    if (!_isPiPSupported || _isInPiP) return;
    try {
      if (_videoController != null && !_videoController!.value.isPlaying) {
        await _videoController!.play();
        await _enableWakelock();
      }
      await platform.invokeMethod('enterPiP');
    } catch (e) {}
  }

  // LOAD EPISODE
  Future<void> _loadEpisodeAndPlay() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingEpisode = true;
      _hasError = false;
      _errorMessage = null;
    });

    // Check cache
    if (_episodeCache.containsKey(_currentEpisode!.url)) {
      if (kDebugMode) print('🚀 Using cached URLs for: ${_currentEpisode!.url}');
      
      final cachedLinks = _episodeCache[_currentEpisode!.url]!;
      final cachedSubs = _subtitleCache[_currentEpisode!.url] ?? []; // ✅ Get cached subtitles
      final cleanedLinks = _filterUniqueQualities(cachedLinks);
      // Fallback: if filtering yields empty (e.g., only 'auto'), use all fetched links
      final playableLinks = cleanedLinks.isNotEmpty ? cleanedLinks : cachedLinks;
      final defaultLink = _selectBestQuality(playableLinks);
      
      if (mounted) {
        setState(() {
          _allAvailableQualities = playableLinks;
          _currentStreamLink = defaultLink;
          _availableSubtitles = cachedSubs; // ✅ Restore cached subtitles
          _isLoadingEpisode = false;
        });
        
        await _initializePlayer();
        
        // ✅ Auto-load first subtitle if available
        if (cachedSubs.isNotEmpty) {
          await _loadSubtitle(cachedSubs.first['lang']!);
        }
      }
      return;
    }

    try {
      if (kDebugMode) print('🔄 Fetching: ${_currentEpisode!.url}');
      
      // ✅ Use ZoroService instead of old backend
      final zoroService = ZoroService();
      final data = await zoroService.getQualities(_currentEpisode!.url);

      if (!mounted) return;

      if (data != null && data['sources'] is List) {
        final sources = data['sources'] as List;
        final List<StreamLink> fetchedLinks = [];

        for (var source in sources) {
          final url = source['url'] ?? '';
          final quality = source['quality'] ?? 'auto';
          final type = source['isM3U8'] == true ? 'hls' : 'mp4';
          
          fetchedLinks.add(StreamLink(
            provider: 'Zoro',
            url: url,
            type: type,
            quality: quality,
            source: 'zoro',
          ));
        }

        // ✅ Store available subtitles (don't fetch yet)
        final List<Map<String, String>> availableSubs = [];
        if (data['subtitles'] is List) {
          for (var sub in data['subtitles'] as List) {
            final lang = sub['lang'] ?? '';
            final url = sub['url'] ?? '';
            
            if (lang.toLowerCase() != 'thumbnails' && url.isNotEmpty) {
              availableSubs.add({'lang': lang, 'url': url});
            }
          }
          
          if (availableSubs.isNotEmpty && kDebugMode) {
            print('   📝 Available subtitles: ${availableSubs.map((s) => s['lang']).join(', ')}');
          }
        }

        if (fetchedLinks.isEmpty) {
          if (mounted) {
            setState(() {
              _isLoadingEpisode = false;
              _hasError = true;
              _errorMessage = 'No playable links available';
            });
          }
          return;
        }

        // Cache and filter
        _episodeCache[_currentEpisode!.url] = fetchedLinks;
        _subtitleCache[_currentEpisode!.url] = availableSubs; // ✅ Cache subtitle data
        final cleanedLinks = _filterUniqueQualities(fetchedLinks);
        // Fallback: if filtering yields empty (e.g., only 'auto'), use all fetched links
        final playableLinks = cleanedLinks.isNotEmpty ? cleanedLinks : fetchedLinks;
        final defaultLink = _selectBestQuality(playableLinks);

        if (mounted) {
          setState(() {
            _allAvailableQualities = playableLinks;
            _currentStreamLink = defaultLink;
            _availableSubtitles = availableSubs; // ✅ Store subtitle options
            _isLoadingEpisode = false;
          });
          
          await _initializePlayer();
          
          // ✅ Auto-load first subtitle (usually English)
          if (availableSubs.isNotEmpty) {
            await _loadSubtitle(availableSubs.first['lang']!);
          }
        }
      } else {
        throw Exception('Invalid response data');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoadingEpisode = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // LOAD SUBTITLE BY LANGUAGE
  Future<void> _loadSubtitle(String lang) async {
    try {
      if (kDebugMode) print('📝 Loading subtitle: $lang');
      
      // Find subtitle URL for selected language
      final subData = _availableSubtitles.firstWhere(
        (s) => s['lang'] == lang,
        orElse: () => {},
      );
      
      if (subData.isEmpty || subData['url'] == null) {
        if (kDebugMode) print('⚠️  Subtitle not found for: $lang');
        return;
      }
      
      final parsed = await _fetchAndParseVTT(subData['url']!);
      
      if (mounted) {
        setState(() {
          _subtitles = parsed;
          _selectedSubtitleLang = lang;
          _currentSubtitle = ''; // Reset current subtitle
        });
        
        // Restart subtitle timer
        if (parsed.isNotEmpty) {
          _startSubtitleTimer();
        }
        
        if (kDebugMode) print('✅ Loaded $lang: ${parsed.length} entries');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Subtitle load error: $e');
    }
  }

  // FETCH AND PARSE VTT SUBTITLE FILE
  Future<List<Subtitle>> _fetchAndParseVTT(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        return [];
      }
      
      final content = response.body;
      final lines = content.split('\n');
      final List<Subtitle> subtitles = [];
      
      int i = 0;
      while (i < lines.length) {
        final line = lines[i].trim();
        
        // Skip WEBVTT header and empty lines
        if (line.isEmpty || line.startsWith('WEBVTT') || line.startsWith('NOTE')) {
          i++;
          continue;
        }
        
        // Check if this is a timestamp line (e.g., "00:00:01.000 --> 00:00:03.000")
        if (line.contains('-->')) {
          final parts = line.split('-->');
          if (parts.length == 2) {
            final start = _parseVTTTimestamp(parts[0].trim());
            final end = _parseVTTTimestamp(parts[1].trim());
            
            // Get subtitle text (next lines until empty line)
            i++;
            final textLines = <String>[];
            while (i < lines.length && lines[i].trim().isNotEmpty) {
              textLines.add(lines[i].trim());
              i++;
            }
            
            if (textLines.isNotEmpty && start != null && end != null) {
              final rawText = textLines.join('\n');
              final cleanText = _stripHtmlTags(rawText); // ✅ Remove HTML tags
              
              subtitles.add(Subtitle(
                index: subtitles.length,
                start: start,
                end: end,
                text: cleanText,
              ));
            }
          }
        }
        i++;
      }
      
      return subtitles;
    } catch (e) {
      if (kDebugMode) print('VTT parse error: $e');
      return [];
    }
  }

  // STRIP HTML TAGS FROM SUBTITLE TEXT
  String _stripHtmlTags(String text) {
    // Remove common VTT HTML tags: <i>, <b>, <u>, <font>, etc.
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove all HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  // PARSE VTT TIMESTAMP (e.g., "00:00:01.000")
  Duration? _parseVTTTimestamp(String timestamp) {
    try {
      final parts = timestamp.split(':');
      if (parts.length < 2) return null;
      
      int hours = 0;
      int minutes = 0;
      double seconds = 0;
      
      if (parts.length == 3) {
        // HH:MM:SS.mmm
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
        seconds = double.parse(parts[2]);
      } else {
        // MM:SS.mmm
        minutes = int.parse(parts[0]);
        seconds = double.parse(parts[1]);
      }
      
      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds.floor(),
        milliseconds: ((seconds - seconds.floor()) * 1000).round(),
      );
    } catch (e) {
      return null;
    }
  }

  // FILTER UNIQUE QUALITIES (360p, 480p, 720p, 1080p only)
  List<StreamLink> _filterUniqueQualities(List<StreamLink> links) {
    final uniqueQualities = <String, StreamLink>{};
    
    for (var link in links) {
      final quality = link.quality?.toLowerCase() ?? '';
      
      if (quality.contains('360') || 
          quality.contains('480') || 
          quality.contains('720') || 
          quality.contains('1080')) {
        
        final normalizedQuality = quality.replaceAll(RegExp(r'[^0-9]'), '') + 'p';
        
        if (!uniqueQualities.containsKey(normalizedQuality)) {
          uniqueQualities[normalizedQuality] = link;
        }
      }
    }
    
    // Sort by quality (highest first)
    final sorted = uniqueQualities.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key.replaceAll('p', '')) ?? 0;
        final bNum = int.tryParse(b.key.replaceAll('p', '')) ?? 0;
        return bNum.compareTo(aNum);
      });
    
    return sorted.map((e) => e.value).toList();
  }

  // SELECT BEST QUALITY (720p default)
  StreamLink _selectBestQuality(List<StreamLink> links) {
    if (links.isEmpty) {
      throw StateError('No playable links');
    }
    // Try to find 720p
    for (var link in links) {
      if (link.quality?.contains('720') == true) {
        if (kDebugMode) print('✅ Selected: 720p');
        return link;
      }
    }
    
    // Fallback to 480p
    for (var link in links) {
      if (link.quality?.contains('480') == true) {
        if (kDebugMode) print('✅ Selected: 480p');
        return link;
      }
    }
    
    // Return first available
    if (kDebugMode) print('✅ Selected: ${links.first.quality}');
    return links.first;
  }

  // INITIALIZE PLAYER
  Future<void> _initializePlayer() async {
    if (!mounted || _currentStreamLink == null) return;
    
    // Fallback to WebView for HLS/Desustream "auto" streams to avoid 403 on segment requests
    if (_shouldUseWebView(_currentStreamLink!)) {
      final episodeTitle = '${widget.animeTitle} - ${_currentEpisode?.number ?? ''}';
      // Delay navigation slightly to ensure current frame is stable
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnimeWebViewPlayer(
              initialStreamLink: _currentStreamLink!,
              episodeTitle: episodeTitle,
              allStreamLinks: _allAvailableQualities,
            ),
          ),
        );
      });
      // Keep UI in loading state briefly, then stop to show error/controls-free screen
      setState(() {
        _isLoadingPlayer = false;
        _isPlayerInitialized = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingPlayer = true;
      _hasError = false;
      _isPlayerInitialized = false;
    });

    try {
      if (kDebugMode) {
        print('🎬 Initializing player:');
        print('   Quality: ${_currentStreamLink!.quality}');
      }
      
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_currentStreamLink!.url),
        httpHeaders: _getHttpHeaders(_currentStreamLink!.url),
      );
      
      await _videoController!.initialize();
      
      // ✅ Optimized listener: only update on important state changes
      _videoController!.addListener(_onVideoStateChanged);

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        showControls: false,
        // ✅ Performance optimizations - disable unused features
        allowPlaybackSpeedChanging: false,
        // ✅ Reduce UI rebuilds
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6366F1),
          handleColor: const Color(0xFF6366F1),
          backgroundColor: Colors.white24,
          bufferedColor: const Color(0xFF6366F1).withOpacity(0.3),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          ),
        ),
        errorBuilder: (context, errorMessage) => _buildErrorWidget(),
      );
      
      // ✅ Start subtitle timer if subtitles are available
      if (_subtitles.isNotEmpty) {
        _startSubtitleTimer();
      }

      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _isPlayerInitialized = true;
        });
        _startHideTimer();
      }
      
      if (kDebugMode) print('✅ Player initialized successfully');
      
    } catch (e) {
      if (kDebugMode) print('❌ Player error: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _disableWakelock();
      }
    }
  }

  bool _shouldUseWebView(StreamLink link) {
    final url = link.url.toLowerCase();
    final isDesu = url.contains('desustream') || (link.source?.toLowerCase() == 'desustream');
    // Only use WebView for Desustream (not Zoro HLS)
    return isDesu;
  }

  // ✅ Optimized video state change handler
  void _onVideoStateChanged() {
    if (!mounted || _videoController == null) return;
    
    try {
      final isPlaying = _videoController!.value.isPlaying;
      
      // Only update wakelock state when playing state changes
      if (isPlaying != _previousIsPlaying) {
        _previousIsPlaying = isPlaying;
        if (isPlaying) {
          _enableWakelock();
        } else {
          _disableWakelock();
        }
      }
      
      // Only call setState for UI updates when necessary (not every frame)
      // Chewie will handle its own updates, we only need to update our custom controls
      // Use a throttled approach: only update every ~500ms for position changes
      final currentPosition = _videoController!.value.position;
      final positionDiff = (currentPosition - _previousPosition).abs();
      
      // Update UI only if position changed significantly (>500ms) or playing state changed
      if (positionDiff.inMilliseconds > 500 || isPlaying != _previousIsPlaying) {
        _previousPosition = currentPosition;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // ✅ Prevent crashes from video controller errors
      if (kDebugMode) print('⚠️ Video state change error: $e');
    }
  }

  // START SUBTITLE TIMER
  void _startSubtitleTimer() {
    _subtitleTimer?.cancel();
    // ✅ Optimized: 500ms interval (reduced from 250ms to save CPU)
    _subtitleTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateSubtitle();
    });
    if (kDebugMode) print('📝 Subtitle timer started (${_subtitles.length} subs)');
  }

  // UPDATE CURRENT SUBTITLE BASED ON VIDEO POSITION
  void _updateSubtitle() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    try {
      // ✅ Skip update if video is paused (performance optimization)
      if (!_videoController!.value.isPlaying) {
        // Clear subtitle when paused
        if (_currentSubtitle.isNotEmpty && mounted) {
          setState(() {
            _currentSubtitle = '';
            _previousSubtitle = '';
          });
        }
        return;
      }

      final position = _videoController!.value.position;
      String newSubtitle = '';

      // Find subtitle that matches current position
      for (final sub in _subtitles) {
        if (position >= sub.start && position <= sub.end) {
          newSubtitle = sub.text;
          break;
        }
      }

      // Only update if subtitle changed (prevent unnecessary rebuilds)
      if (newSubtitle != _previousSubtitle && mounted) {
        _previousSubtitle = newSubtitle;
        setState(() {
          _currentSubtitle = newSubtitle;
        });
      }
    } catch (e) {
      // ✅ Prevent crashes from subtitle update errors
      if (kDebugMode) print('⚠️ Subtitle update error: $e');
    }
  }

  Map<String, String> _getHttpHeaders(String url) {
    final urlLower = url.toLowerCase();
    
    // ✅ Zoro CDN headers
    if (urlLower.contains('netmagcdn.com') || urlLower.contains('megacloud')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://megacloud.blog/',
        'Origin': 'https://megacloud.blog',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      };
    }
    
    if (urlLower.contains('desustream.info')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://desustream.info/',
        'Origin': 'https://desustream.info',
        'Accept': 'video/*,application/vnd.apple.mpegurl,application/x-mpegURL,application/octet-stream',
        'Accept-Encoding': 'identity',
      };
    }
    
    if (urlLower.contains('pixeldrain.com')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept': 'video/mp4,video/*',
        'Accept-Encoding': 'identity',
      };
    }
    
    if (urlLower.contains('googlevideo.com') || urlLower.contains('blogger.com')) {
      return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://www.blogger.com/',
        'Origin': 'https://www.blogger.com',
        'Accept': 'video/*',
      };
    }
    
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'video/*',
    };
  }

  // CHANGE QUALITY
  Future<void> _changeQuality(StreamLink newLink) async {
    if (_currentStreamLink?.url == newLink.url) return;
    
    final currentPosition = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;
    
    // ✅ Proper cleanup before switching quality
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoStateChanged);
    }
    _chewieController?.pause();
    _chewieController?.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    
    if (mounted) {
      setState(() {
        _currentStreamLink = newLink;
      });
    }
    
    await _initializePlayer();
    
    if (currentPosition.inSeconds > 0 && _isPlayerInitialized && _videoController != null) {
      await _videoController!.seekTo(currentPosition);
      if (wasPlaying) {
        await _videoController!.play();
        await _enableWakelock();
      }
    }
  }

  bool get hasNextEpisode {
    if (_currentEpisode == null) return false;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    return currentIndex >= 0 && currentIndex < widget.allEpisodes.length - 1;
  }

  bool get hasPreviousEpisode {
    if (_currentEpisode == null) return false;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    return currentIndex > 0;
  }

  void _playNextEpisode() {
    if (!hasNextEpisode) return;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final nextEpisode = widget.allEpisodes[currentIndex + 1];
    _switchEpisode(nextEpisode);
  }

  void _playPreviousEpisode() {
    if (!hasPreviousEpisode) return;
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final prevEpisode = widget.allEpisodes[currentIndex - 1];
    _switchEpisode(prevEpisode);
  }

  Future<void> _switchEpisode(Episode newEpisode) async {
    // ✅ Proper cleanup before switching episode
    _subtitleTimer?.cancel();
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoStateChanged);
    }
    _chewieController?.pause();
    _chewieController?.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    
    // Reset state tracking
    _previousIsPlaying = false;
    _previousPosition = Duration.zero;
    _previousSubtitle = '';
    
    setState(() {
      _currentEpisode = newEpisode;
      _isPlayerInitialized = false;
      _currentStreamLink = null;
      _allAvailableQualities = [];
      _currentSubtitle = '';
      _subtitles = [];
    });

    await _loadEpisodeAndPlay();
  }

  void _showQualityBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildQualityBottomSheet(),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _extractEpisodeNumber(String title) {
    final match = RegExp(r'Episode\s*(\d+)', caseSensitive: false).firstMatch(title);
    return match?.group(1) ?? title;
  }

  void _showSubtitleBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSubtitleBottomSheet(),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _subtitleTimer?.cancel(); // ✅ Cancel subtitle timer
    
    // ✅ Remove video controller listener before dispose
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoStateChanged);
    }
    
    _disableWakelock();
    WidgetsBinding.instance.removeObserver(this);
    
    // ✅ Dispose controllers in proper order
    _chewieController?.pause();
    _chewieController?.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _showSystemUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    if (isLandscape) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _buildLandscapePlayer()),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: _buildPortraitPlayer(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEpisodeInfo(),
                    _buildEpisodeList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitPlayer() {
    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: _isPlayerInitialized && !_hasError && !_isLoadingEpisode && !_isLoadingPlayer ? _toggleControls : null,
        child: Stack(
          children: [
            if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode && _chewieController != null)
              Center(child: Chewie(controller: _chewieController!)),
            if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
            if (_hasError) _buildErrorWidget(),
            // ✅ Custom subtitle overlay
            if (_isPlayerInitialized && _currentSubtitle.isNotEmpty)
              _buildSubtitleOverlay(),
            if (_showControls && _isPlayerInitialized && !_isInPiP) _buildPortraitTopBar(),
            if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
              _buildPortraitCenterControls(),
            if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
              _buildPortraitBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapePlayer() {
    return GestureDetector(
      onTap: _isPlayerInitialized && !_hasError && !_isLoadingEpisode && !_isLoadingPlayer ? _toggleControls : null,
      child: Stack(
        children: [
          if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode && _chewieController != null)
            Center(child: Chewie(controller: _chewieController!)),
          if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
          if (_hasError) _buildErrorWidget(),
          // Custom subtitle overlay
          if (_isPlayerInitialized && _currentSubtitle.isNotEmpty)
            _buildSubtitleOverlay(),
          if (_showControls && _isPlayerInitialized && !_isInPiP) _buildLandscapeTopBar(),
          if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
            _buildLandscapeCenterControls(),
          if (_showControls && _isPlayerInitialized && !_isInPiP && _videoController != null)
            _buildLandscapeBottomControls(),
        ],
      ),
    );
  }

  // SUBTITLE OVERLAY
  Widget _buildSubtitleOverlay() {
    // Check if landscape or portrait
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: isLandscape ? 15 : 10, // ✅ Lebih rendah, dekat bawah
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isLandscape ? 700 : 500),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6), // ✅ Lebih transparan (60%)
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _currentSubtitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLandscape ? 16 : 14, // ✅ Font lebih kecil
              fontWeight: FontWeight.w500,
              height: 1.3,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // PORTRAIT TOP BAR
  Widget _buildPortraitTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const Spacer(),
            if (_availableSubtitles.isNotEmpty) // ✅ Subtitle button
              IconButton(
                onPressed: _showSubtitleBottomSheet,
                icon: const Icon(Icons.closed_caption_rounded, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            if (_allAvailableQualities.length > 1)
              IconButton(
                onPressed: _showQualityBottomSheet,
                icon: const Icon(Icons.high_quality_rounded, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            if (_isPiPSupported)
              IconButton(
                onPressed: _enterPiP,
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  // PORTRAIT CENTER CONTROLS
  Widget _buildPortraitCenterControls() {
    final isPlaying = _videoController!.value.isPlaying;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasPreviousEpisode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: IconButton(
                onPressed: _playPreviousEpisode,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                iconSize: 28,
                padding: const EdgeInsets.all(10),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
            ),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final newPosition = currentPosition - const Duration(seconds: 10);
                _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              iconSize: 26,
              padding: const EdgeInsets.all(8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (isPlaying) {
                    _videoController!.pause();
                    _hideControlsTimer?.cancel();
                    _disableWakelock();
                  } else {
                    _videoController!.play();
                    _startHideTimer();
                    _enableWakelock();
                  }
                });
              },
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              iconSize: 32,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
            ),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final duration = _videoController!.value.duration;
                final newPosition = currentPosition + const Duration(seconds: 10);
                if (newPosition < duration) _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              iconSize: 26,
              padding: const EdgeInsets.all(8),
            ),
          ),
          if (hasNextEpisode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: IconButton(
                onPressed: _playNextEpisode,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                iconSize: 28,
                padding: const EdgeInsets.all(10),
              ),
            ),
        ],
      ),
    );
  }

  // PORTRAIT BOTTOM CONTROLS
  Widget _buildPortraitBottomControls() {
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (value) => _videoController!.seekTo(duration * value),
                        activeColor: const Color(0xFF6366F1),
                        inactiveColor: Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(duration),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _videoController!.setVolume(_videoController!.value.volume > 0 ? 0 : 1);
                      });
                    },
                    icon: Icon(
                      _videoController!.value.volume > 0 
                          ? Icons.volume_up_rounded 
                          : Icons.volume_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    },
                    icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LANDSCAPE TOP BAR
  Widget _buildLandscapeTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.animeTitle,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Episode ${_extractEpisodeNumber(_currentEpisode!.number)}',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_availableSubtitles.isNotEmpty) // 
              IconButton(
                onPressed: _showSubtitleBottomSheet,
                icon: const Icon(Icons.closed_caption_rounded, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),
            if (_allAvailableQualities.length > 1)
              IconButton(
                onPressed: _showQualityBottomSheet,
                icon: const Icon(Icons.high_quality_rounded, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),
            if (_isPiPSupported)
              IconButton(
                onPressed: _enterPiP,
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),
          ],
        ),
      ),
    );
  }

  // LANDSCAPE CENTER CONTROLS
  Widget _buildLandscapeCenterControls() {
    final isPlaying = _videoController!.value.isPlaying;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasPreviousEpisode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
              ),
              child: IconButton(
                onPressed: _playPreviousEpisode,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                iconSize: 32,
                padding: const EdgeInsets.all(12),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.6),
            ),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final newPosition = currentPosition - const Duration(seconds: 10);
                _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              iconSize: 28,
              padding: const EdgeInsets.all(10),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (isPlaying) {
                    _videoController!.pause();
                    _hideControlsTimer?.cancel();
                    _disableWakelock();
                  } else {
                    _videoController!.play();
                    _startHideTimer();
                    _enableWakelock();
                  }
                });
              },
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              iconSize: 40,
              padding: const EdgeInsets.all(14),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.6),
            ),
            child: IconButton(
              onPressed: () {
                final currentPosition = _videoController!.value.position;
                final duration = _videoController!.value.duration;
                final newPosition = currentPosition + const Duration(seconds: 10);
                if (newPosition < duration) _videoController!.seekTo(newPosition);
                _startHideTimer();
              },
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              iconSize: 28,
              padding: const EdgeInsets.all(10),
            ),
          ),
          if (hasNextEpisode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
              ),
              child: IconButton(
                onPressed: _playNextEpisode,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                iconSize: 32,
                padding: const EdgeInsets.all(12),
              ),
            ),
        ],
      ),
    );
  }

  // LANDSCAPE BOTTOM CONTROLS
  Widget _buildLandscapeBottomControls() {
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) => _videoController!.seekTo(duration * value),
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDuration(duration),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _videoController!.setVolume(_videoController!.value.volume > 0 ? 0 : 1);
                        });
                      },
                      icon: Icon(
                        _videoController!.value.volume > 0 
                            ? Icons.volume_up_rounded 
                            : Icons.volume_off_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                    if (_currentStreamLink?.quality != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _currentStreamLink!.quality!.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF818CF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  },
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 22),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // QUALITY BOTTOM SHEET
  Widget _buildQualityBottomSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.high_quality_rounded,
                    color: Color(0xFF818CF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Quality',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _allAvailableQualities.length,
              itemBuilder: (context, index) {
                final link = _allAvailableQualities[index];
                final isSelected = _currentStreamLink?.url == link.url;
                final quality = link.quality?.toUpperCase() ?? 'AUTO';
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF6366F1).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _changeQuality(link);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1).withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded,
                        color: isSelected ? const Color(0xFF818CF8) : Colors.white60,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      quality,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    subtitle: Text(
                      link.provider ?? 'Unknown',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PLAYING',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // SUBTITLE BOTTOM SHEET
  Widget _buildSubtitleBottomSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.closed_caption_rounded,
                    color: Color(0xFF818CF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Subtitle',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _availableSubtitles.length + 1, // +1 for "OFF" option
              itemBuilder: (context, index) {
                final isOffOption = index == 0;
                final lang = isOffOption ? 'OFF' : _availableSubtitles[index - 1]['lang']!;
                final isSelected = isOffOption 
                    ? _subtitles.isEmpty 
                    : _selectedSubtitleLang == lang;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF6366F1).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      if (isOffOption) {
                        // Turn off subtitles
                        setState(() {
                          _subtitles = [];
                          _currentSubtitle = '';
                          _subtitleTimer?.cancel();
                        });
                      } else {
                        _loadSubtitle(lang);
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Row(
                      children: [
                        Icon(
                          isOffOption ? Icons.subtitles_off_outlined : Icons.closed_caption,
                          color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          lang,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // EPISODE INFO
  Widget _buildEpisodeInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.animeTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Color(0xFF818CF8),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Episode ${_extractEpisodeNumber(_currentEpisode!.number)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF818CF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentStreamLink?.quality != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    _currentStreamLink!.quality!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // EPISODE LIST
  Widget _buildEpisodeList() {
    final allEpisodes = widget.allEpisodes.reversed.toList();
    final totalPages = (allEpisodes.length / _episodesPerPage).ceil();
    final startIndex = _currentPage * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, allEpisodes.length);
    final displayedEpisodes = allEpisodes.sublist(startIndex, endIndex);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Episodes',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  '${startIndex + 1}-$endIndex of ${allEpisodes.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: displayedEpisodes.length,
            itemBuilder: (context, index) {
              final episode = displayedEpisodes[index];
              final isCurrentEpisode = _currentEpisode?.url == episode.url;
              
              return Container(
                decoration: BoxDecoration(
                  color: isCurrentEpisode 
                      ? const Color(0xFF6366F1).withOpacity(0.15)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentEpisode
                        ? const Color(0xFF6366F1)
                        : Colors.white.withOpacity(0.08),
                    width: isCurrentEpisode ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isCurrentEpisode ? null : () => _switchEpisode(episode),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCurrentEpisode
                                  ? const Color(0xFF6366F1).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCurrentEpisode 
                                  ? Icons.play_arrow_rounded 
                                  : Icons.play_circle_outline_rounded,
                              color: isCurrentEpisode
                                  ? const Color(0xFF818CF8)
                                  : Colors.white70,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              '${episode.episodeNumber ?? index + 1 + startIndex}',
                              style: GoogleFonts.inter(
                                color: isCurrentEpisode
                                    ? const Color(0xFF818CF8)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          if (totalPages > 1) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: _currentPage > 0 ? Colors.white : Colors.white24,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '${_currentPage + 1} / $totalPages',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: _currentPage < totalPages - 1 ? Colors.white : Colors.white24,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // LOADING SCREEN
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isLoadingEpisode ? 'Loading episode...' : 'Initializing player...',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_currentStreamLink != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_currentStreamLink!.quality?.toUpperCase() ?? 'AUTO'}',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ERROR WIDGET
  Widget _buildErrorWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Play Video',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ?? 'Unknown error occurred',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  
                  if (_allAvailableQualities.length > 1) ...[
                    Text(
                      'Try another quality:',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _allAvailableQualities
                          .where((l) => l.url != _currentStreamLink?.url)
                          .take(3)
                          .map((link) => ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _hasError = false;
                                    _currentStreamLink = link;
                                  });
                                  _initializePlayer();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  link.quality?.toUpperCase() ?? 'AUTO',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadEpisodeAndPlay,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}