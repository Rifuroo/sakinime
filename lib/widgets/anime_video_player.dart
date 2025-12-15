// widgets/anime_video_player.dart - PROFESSIONAL STREAMING UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;

import '../models/anime_model.dart';
import '../services/zoro_service.dart';
import '../services/subtitle_parser_service.dart';
import '../services/translation_service.dart';
import '../services/watch_history_service.dart';
import 'anime_webview_player.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  // MediaKit - Primary player for Windows
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  bool _useMediaKit = false;
  
  // Fallback video player (kept for compatibility)
  VideoPlayerController? _videoController;
  
  StreamLink? _currentStreamLink;
  List<StreamLink> _allAvailableQualities = [];
  Episode? _currentEpisode;
  List<ParsedSubtitle> _subtitles = []; // ✅ Parsed subtitles
  String _currentSubtitle = ''; // ✅ Current subtitle text to display
  List<Map<String, String>> _availableSubtitles = []; // ✅ Available subtitle languages
  String _selectedSubtitleLang = 'English'; // ✅ Selected subtitle language
  
  // AI Translation
  String _translationLang = 'none'; // Selected translation language
  Map<String, String> _translatedSubtitles = {}; // Cache for translated subtitles
  bool _isTranslating = false; // Translation in progress
  String _translationStyle = 'anime'; // Translation style: 'anime', 'formal', 'casual'
  
  bool _isLoadingEpisode = true;
  bool _isLoadingPlayer = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _subtitleTimer; // ✅ Timer to update subtitles
  Timer? _progressSaveTimer; // ✅ Timer to auto-save watch progress
  
  // Performance optimization: track previous states to avoid unnecessary rebuilds
  bool _previousIsPlaying = false;
  Duration _previousPosition = Duration.zero;
  String _previousSubtitle = '';
  
  // Watch history tracking
  DateTime? _watchStartTime;
  Duration _lastSavedPosition = Duration.zero;
  
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
    _watchStartTime = DateTime.now();
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
    
    bool isPlaying = false;
    if (_useMediaKit && _mediaKitPlayer != null) {
      isPlaying = _mediaKitPlayer!.state.playing;
    } else if (_videoController != null) {
      isPlaying = _videoController!.value.isPlaying;
    }
    
    if (isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls) {
          bool stillPlaying = false;
          if (_useMediaKit && _mediaKitPlayer != null) {
            stillPlaying = _mediaKitPlayer!.state.playing;
          } else if (_videoController != null) {
            stillPlaying = _videoController!.value.isPlaying;
          }
          
          if (stillPlaying) {
            setState(() => _showControls = false);
          }
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

  // LOAD PREVIOUS WATCH PROGRESS
  Future<void> _loadWatchProgress() async {
    if (_currentEpisode == null) return;
    
    try {
      if (kDebugMode) print('🔍 Loading watch progress for episode: ${_currentEpisode!.url}');
      
      final progress = await WatchHistoryService.getEpisodeProgress(
        widget.animeTitle, // Use anime title as animeId
        _currentEpisode!.url,
      );
      
      if (progress != null && progress.watchedDuration.inSeconds > 30) {
        if (kDebugMode) {
          print('📺 Found previous progress: ${progress.progressText} (${(progress.progressPercentage * 100).toStringAsFixed(1)}%)');
          print('🔍 Progress details: ${progress.watchedDuration.inSeconds}s watched, ${progress.totalDuration.inSeconds}s total');
        }
        
        // Show resume dialog if significant progress exists (>5% and <90%)
        if (progress.progressPercentage > 0.05 && progress.progressPercentage < 0.9) {
          if (kDebugMode) {
            print('✅ Progress ${(progress.progressPercentage * 100).toStringAsFixed(1)}% is in range 5%-90% - SHOWING RESUME DIALOG');
            print('🔍 Context check: mounted=$mounted, context=${context.mounted}');
          }
          
          // Test if we can show dialogs by trying a simple test first
          _testDialogAndShowResume(progress.watchedDuration);
        } else if (progress.progressPercentage >= 0.9) {
          // Auto-resume for high progress (>=90%) without dialog
          if (kDebugMode) {
            print('🎬 Auto-resuming from ${(progress.progressPercentage * 100).toStringAsFixed(1)}% progress (>=90%)');
          }
          _resumeFromPosition(progress.watchedDuration);
        } else {
          if (kDebugMode) {
            print('❌ Progress ${(progress.progressPercentage * 100).toStringAsFixed(1)}% - too low for resume (<5%)');
          }
        }
      } else {
        if (kDebugMode) {
          if (progress == null) {
            print('📺 No previous progress found');
          } else {
            print('📺 Progress found but too short: ${progress.watchedDuration.inSeconds}s (need >30s)');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load watch progress: $e');
    }
  }
  
  // TEST DIALOG CAPABILITY AND SHOW RESUME
  void _testDialogAndShowResume(Duration savedPosition) {
    if (!mounted) return;
    
    if (kDebugMode) {
      print('🧪 Testing dialog capability before showing resume dialog');
    }
    
    // Try to show a simple test dialog first to verify context works
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext testContext) {
          if (kDebugMode) {
            print('🧪 Test dialog builder called - context is working');
          }
          
          // Immediately close test dialog and show real resume dialog
          Future.delayed(const Duration(milliseconds: 100), () {
            Navigator.of(testContext).pop();
            _showResumeDialog(savedPosition);
          });
          
          return Container(); // Empty container, will be closed immediately
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Dialog test failed: $e');
        print('🔄 Falling back to auto-resume');
      }
      // Fallback to auto-resume if dialog fails
      _resumeFromPosition(savedPosition);
    }
  }

  // SHOW RESUME DIALOG
  void _showResumeDialog(Duration savedPosition) {
    if (!mounted) return;
    
    if (kDebugMode) {
      print('🎬 _showResumeDialog called for position: ${_formatDuration(savedPosition)}');
    }
    
    // Add a longer delay to ensure UI is completely stable and context is ready
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      
      if (kDebugMode) {
        print('🎬 Attempting to show resume dialog after delay');
      }
      
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            if (kDebugMode) {
              print('🎬 Resume dialog builder called - dialog should be visible now');
            }
            
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Resume Watching?',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Text(
                'You were watching this episode at ${_formatDuration(savedPosition)}. Would you like to continue from where you left off?',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (kDebugMode) print('🎬 User selected: Start Over');
                    Navigator.of(dialogContext).pop();
                    // Start from beginning - no action needed
                  },
                  child: Text(
                    'Start Over',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) print('🎬 User selected: Resume');
                    Navigator.of(dialogContext).pop();
                    // Resume from saved position
                    _resumeFromPosition(savedPosition);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Resume',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ).then((_) {
          if (kDebugMode) print('🎬 Resume dialog closed');
        });
      } catch (e) {
        if (kDebugMode) print('❌ Failed to show resume dialog: $e');
        // Fallback: auto-resume if dialog fails
        _resumeFromPosition(savedPosition);
      }
    });
  }
  
  // RESUME FROM SAVED POSITION
  Future<void> _resumeFromPosition(Duration position) async {
    if (kDebugMode) {
      print('🎬 _resumeFromPosition called with: ${_formatDuration(position)}');
    }
    
    // Wait for player to be initialized
    int attempts = 0;
    while (!_isPlayerInitialized && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (_isPlayerInitialized) {
      try {
        if (_useMediaKit && _mediaKitPlayer != null) {
          if (kDebugMode) {
            print('🎬 MediaKit seeking to: ${_formatDuration(position)}');
            print('🔍 Current MediaKit position before seek: ${_formatDuration(_mediaKitPlayer!.state.position)}');
            print('🔍 MediaKit duration: ${_formatDuration(_mediaKitPlayer!.state.duration)}');
          }
          
          // Wait for MediaKit to have valid duration (video fully loaded)
          int durationAttempts = 0;
          while (_mediaKitPlayer!.state.duration.inSeconds <= 0 && durationAttempts < 30) {
            if (kDebugMode) print('⏳ Waiting for MediaKit duration... (${durationAttempts + 1}/30)');
            await Future.delayed(const Duration(milliseconds: 500));
            durationAttempts++;
          }
          
          final duration = _mediaKitPlayer!.state.duration;
          if (duration.inSeconds <= 0) {
            if (kDebugMode) print('❌ MediaKit duration still invalid after waiting');
            return;
          }
          
          if (kDebugMode) {
            print('✅ MediaKit ready with duration: ${_formatDuration(duration)}');
          }
          
          // Ensure position is within valid range
          final safePosition = position > duration ? duration : position;
          
          // Pause first to ensure clean seek
          await _mediaKitPlayer!.pause();
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Perform seek
          await _mediaKitPlayer!.seek(safePosition);
          
          // Wait for seek to complete
          await Future.delayed(const Duration(milliseconds: 800));
          
          // Verify seek worked
          final currentPos = _mediaKitPlayer!.state.position;
          if (kDebugMode) {
            print('🔍 MediaKit position after seek: ${_formatDuration(currentPos)}');
            print('🔍 Seek difference: ${(safePosition - currentPos).abs().inSeconds}s');
          }
          
          // If seek didn't work properly, try one more time
          if ((safePosition - currentPos).abs().inSeconds > 10) {
            if (kDebugMode) print('🔄 Seek didn\'t work well, trying once more...');
            await _mediaKitPlayer!.seek(safePosition);
            await Future.delayed(const Duration(milliseconds: 500));
            
            final finalPos = _mediaKitPlayer!.state.position;
            if (kDebugMode) {
              print('🔍 Final MediaKit position: ${_formatDuration(finalPos)}');
            }
          }
          
          // Start playing after seek
          await _mediaKitPlayer!.play();
          
          if (kDebugMode) {
            print('▶️ MediaKit resumed from: ${_formatDuration(_mediaKitPlayer!.state.position)}');
          }
          
        } else if (_videoController != null) {
          if (kDebugMode) {
            print('🎬 VideoPlayer seeking to: ${_formatDuration(position)}');
            print('🔍 Current VideoPlayer position before seek: ${_formatDuration(_videoController!.value.position)}');
          }
          
          await _videoController!.seekTo(position);
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Verify seek worked
          final currentPos = _videoController!.value.position;
          if (kDebugMode) {
            print('🔍 VideoPlayer position after seek: ${_formatDuration(currentPos)}');
          }
          
          // Start playing after seek
          await _videoController!.play();
          
          if (kDebugMode) {
            print('▶️ VideoPlayer resumed from: ${_formatDuration(currentPos)}');
          }
        }
        
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to resume: $e');
      }
    } else {
      if (kDebugMode) print('⚠️ Player not initialized, cannot resume');
    }
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
        
        // ✅ Auto-load preferred subtitle (English first, then first available)
        if (cachedSubs.isNotEmpty) {
          final preferredSub = _findPreferredSubtitle(cachedSubs);
          await _loadSubtitle(preferredSub);
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
            print('📝 Available subtitles (${availableSubs.length}): ${availableSubs.map((s) => s['lang']).join(', ')}');
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
          
          // ✅ Auto-load preferred subtitle (English first, then first available)
          if (availableSubs.isNotEmpty) {
            final preferredSub = _findPreferredSubtitle(availableSubs);
            await _loadSubtitle(preferredSub);
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

  // FIND PREFERRED SUBTITLE LANGUAGE
  String _findPreferredSubtitle(List<Map<String, String>> availableSubs) {
    // Priority order: English > Spanish > French > Portuguese > Others
    final priorities = ['English', 'Spanish', 'French', 'Portuguese', 'Italian', 'Russian'];
    
    for (final priority in priorities) {
      final found = availableSubs.firstWhere(
        (sub) => sub['lang']?.toLowerCase().contains(priority.toLowerCase()) == true,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        if (kDebugMode) print('🎯 Found preferred subtitle: ${found['lang']}');
        return found['lang']!;
      }
    }
    
    // Fallback to first available (but avoid Arabic if possible)
    final nonArabic = availableSubs.firstWhere(
      (sub) => sub['lang']?.toLowerCase() != 'arabic',
      orElse: () => availableSubs.first,
    );
    
    if (kDebugMode) print('🎯 Using fallback subtitle: ${nonArabic['lang']}');
    return nonArabic['lang']!;
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
        
        if (kDebugMode) {
          print('✅ Loaded $lang: ${parsed.length} entries');
          if (parsed.isNotEmpty) {
            print('   First subtitle: "${parsed.first.text}" at ${parsed.first.start}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Subtitle load error: $e');
    }
  }

  // FETCH AND PARSE VTT SUBTITLE FILE
  Future<List<ParsedSubtitle>> _fetchAndParseVTT(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        return [];
      }
      
      // Use the subtitle parser service
      return SubtitleParserService.parseSubtitles(response.body, language: 'English');
    } catch (e) {
      if (kDebugMode) print('VTT parse error: $e');
      return [];
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
      
      // Windows-specific multi-fallback approach
      bool initialized = false;
      Exception? lastError;
      
      // Strategy 1: MediaKit (Primary for Windows)
      if (!initialized && defaultTargetPlatform == TargetPlatform.windows) {
        try {
          if (kDebugMode) {
            print('🔄 Strategy 1: MediaKit (Windows Primary)');
            print('   URL: ${_currentStreamLink!.url.length > 100 ? '${_currentStreamLink!.url.substring(0, 100)}...' : _currentStreamLink!.url}');
          }
          
          _mediaKitPlayer = Player();
          _mediaKitVideoController = VideoController(_mediaKitPlayer!);
          
          await _mediaKitPlayer!.open(Media(_currentStreamLink!.url));
          
          // Setup MediaKit position listener for subtitles
          _mediaKitPlayer!.stream.position.listen((position) {
            if (mounted && _subtitles.isNotEmpty) {
              _updateSubtitleForMediaKit(position);
            }
          });
          
          // Wait a bit for MediaKit to initialize
          await Future.delayed(const Duration(seconds: 2));
          
          _useMediaKit = true;
          initialized = true;
          if (kDebugMode) print('✅ Strategy 1 successful with MediaKit');
          
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (kDebugMode) print('❌ Strategy 1 (MediaKit) failed: $e');
          _mediaKitPlayer?.dispose();
          _mediaKitVideoController = null;
        }
      }
      
      // Strategy 2: VideoPlayer fallback (minimal headers)
      if (!initialized) {
        try {
          if (kDebugMode) print('🔄 Strategy 2: VideoPlayer fallback');
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(_currentStreamLink!.url),
            httpHeaders: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'Accept': '*/*',
            },
          );
          
          await _videoController!.initialize().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Timeout'),
          );
          
          initialized = true;
          if (kDebugMode) print('✅ Strategy 2 successful');
          
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (kDebugMode) print('❌ Strategy 2 failed: $e');
          _videoController?.dispose();
        }
      }
      
      // Strategy 3: Try different quality if available
      if (!initialized && _allAvailableQualities.length > 1) {
        for (var quality in _allAvailableQualities) {
          if (quality.url != _currentStreamLink!.url) {
            // Try with MediaKit first on Windows
            if (defaultTargetPlatform == TargetPlatform.windows) {
              try {
                if (kDebugMode) print('🔄 Strategy 3a: Different quality with MediaKit (${quality.quality})');
                
                _mediaKitPlayer = Player();
                _mediaKitVideoController = VideoController(_mediaKitPlayer!);
                
                await _mediaKitPlayer!.open(Media(quality.url));
                
                // Setup subtitle listener
                _mediaKitPlayer!.stream.position.listen((position) {
                  if (mounted && _subtitles.isNotEmpty) {
                    _updateSubtitleForMediaKit(position);
                  }
                });
                
                await Future.delayed(const Duration(seconds: 2));
                
                // Update to working quality
                setState(() {
                  _currentStreamLink = quality;
                });
                
                _useMediaKit = true;
                initialized = true;
                if (kDebugMode) print('✅ Strategy 3a successful with MediaKit ${quality.quality}');
                break;
                
              } catch (e) {
                if (kDebugMode) print('❌ Strategy 3a failed for ${quality.quality}: $e');
                _mediaKitPlayer?.dispose();
                _mediaKitVideoController = null;
              }
            }
            
            // Fallback to VideoPlayer
            try {
              if (kDebugMode) print('🔄 Strategy 3b: Different quality with VideoPlayer (${quality.quality})');
              _videoController = VideoPlayerController.networkUrl(
                Uri.parse(quality.url),
              );
              
              await _videoController!.initialize().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw Exception('Timeout'),
              );
              
              // Update to working quality
              setState(() {
                _currentStreamLink = quality;
              });
              
              initialized = true;
              if (kDebugMode) print('✅ Strategy 3b successful with ${quality.quality}');
              break;
              
            } catch (e) {
              lastError = e is Exception ? e : Exception(e.toString());
              if (kDebugMode) print('❌ Strategy 3b failed for ${quality.quality}: $e');
              _videoController?.dispose();
            }
          }
        }
      }
      
      if (!initialized) {
        throw lastError ?? Exception('All initialization strategies failed');
      }
      
      // Setup player controls based on which player is being used
      if (!_useMediaKit && _videoController != null) {
        // ✅ Optimized listener: only update on important state changes
        _videoController!.addListener(_onVideoStateChanged);
        if (kDebugMode) print('🎬 Using VideoPlayer fallback');
      } else if (_useMediaKit && _mediaKitPlayer != null) {
        // MediaKit is primary player for Windows
        if (kDebugMode) print('🎬 Using MediaKit player for Windows');
      }
      
      // ✅ Start subtitle timer if subtitles are available
      if (_subtitles.isNotEmpty) {
        _startSubtitleTimer();
      }
      
      // ✅ Start progress tracking timer
      _startProgressTracking();

      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _isPlayerInitialized = true;
          _showControls = true; // Show controls when player is ready
        });
        _startHideTimer();
      }
      
      if (kDebugMode) print('✅ Player initialized successfully');
      
      // ✅ Load watch progress after player is ready and UI is stable
      // Add extra delay to ensure UI is completely ready for dialogs
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadWatchProgress();
        }
      });
      
    } catch (e) {
      if (kDebugMode) print('❌ Player error: $e');
      
      String errorMessage = e.toString();
      
      // Provide more helpful error messages for Windows
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (errorMessage.contains('12029')) {
          errorMessage = 'Windows Network Error (12029)\n\nThis is a known Windows compatibility issue with certain streaming servers.\n\nSolutions:\n• Try different video quality from the quality menu\n• Try a different episode\n• Check your internet connection\n• Some streaming sources work better than others on Windows';
        } else if (errorMessage.contains('file not found') || errorMessage.contains('corrupted')) {
          errorMessage = 'Video Source Error\n\nThe video file is not accessible or corrupted.\n\nSolutions:\n• Try different video quality\n• Try different episode\n• Try again later';
        } else if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
          errorMessage = 'Connection Timeout\n\nVideo loading took too long.\n\nSolutions:\n• Try different video quality\n• Check internet connection\n• Try again later';
        } else if (errorMessage.contains('All initialization strategies failed')) {
          errorMessage = 'All Video Players Failed\n\nMultiple video loading methods were attempted but all failed.\n\nSolutions:\n• Try different episode\n• Check internet connection\n• Restart the app\n• Try again later';
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _hasError = true;
          _errorMessage = errorMessage;
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

  // Build MediaKit video player with subtitle overlay
  Widget _buildVideoPlayer() {
    if (_useMediaKit && _mediaKitVideoController != null) {
      // MediaKit Video WITHOUT native controls
      return Video(
        controller: _mediaKitVideoController!,
        controls: NoVideoControls, // Disable native controls
      );
    } else if (_videoController != null) {
      // Fallback to basic VideoPlayer
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio == 0 
            ? 16 / 9 
            : _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      // Loading state
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }
  }

  // Update subtitle for MediaKit player
  void _updateSubtitleForMediaKit(Duration position) {
    try {
      String newSubtitle = '';

      // Find subtitle that matches current position
      for (final sub in _subtitles) {
        if (position >= sub.start && position <= sub.end) {
          newSubtitle = sub.text;
          break;
        }
      }

      // Only update if subtitle changed (prevent unnecessary rebuilds)
      if (newSubtitle != _currentSubtitle && mounted) {
        if (kDebugMode && newSubtitle.isNotEmpty) {
          print('📝 MediaKit subtitle: $newSubtitle');
        }
        
        // Apply translation if enabled
        if (_translationLang != 'none' && newSubtitle.isNotEmpty) {
          _translateSubtitle(newSubtitle).then((translated) {
            if (mounted) {
              setState(() {
                _currentSubtitle = translated;
              });
            }
          });
        } else {
          setState(() {
            _currentSubtitle = newSubtitle;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ MediaKit subtitle update error: $e');
    }
  }

  // ✅ Optimized video state change handler
  void _onVideoStateChanged() {
    if (!mounted || _videoController == null || _useMediaKit) return;
    
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
  
  // START PROGRESS TRACKING TIMER
  void _startProgressTracking() {
    _progressSaveTimer?.cancel();
    // ✅ Auto-save progress every 30 seconds
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _autoSaveProgress();
    });
    if (kDebugMode) print('💾 Progress tracking started (auto-save every 30s)');
  }
  
  // AUTO-SAVE WATCH PROGRESS
  Future<void> _autoSaveProgress() async {
    if (!_isPlayerInitialized || _currentEpisode == null) return;
    
    try {
      Duration currentPosition = Duration.zero;
      Duration totalDuration = Duration.zero;
      bool isPlaying = false;
      
      // Get current state from appropriate player
      if (_useMediaKit && _mediaKitPlayer != null) {
        currentPosition = _mediaKitPlayer!.state.position;
        totalDuration = _mediaKitPlayer!.state.duration;
        isPlaying = _mediaKitPlayer!.state.playing;
      } else if (_videoController != null) {
        currentPosition = _videoController!.value.position;
        totalDuration = _videoController!.value.duration;
        isPlaying = _videoController!.value.isPlaying;
      }
      
      // Only save if video is playing and has meaningful progress
      if (!isPlaying || 
          currentPosition.inSeconds < 30 || 
          totalDuration.inSeconds < 60 ||
          currentPosition == _lastSavedPosition) {
        return;
      }
      
      // Don't save if at the very end (last 2%)
      final progressPercentage = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
      if (progressPercentage >= 0.98) {
        return;
      }
      
      await WatchHistoryService.autoSaveProgress(
        animeId: widget.animeTitle, // Use anime title as animeId
        animeTitle: widget.animeTitle,
        animePoster: widget.animePoster,
        episodeId: _currentEpisode!.url,
        episodeTitle: _currentEpisode!.title ?? 'Episode ${_currentEpisode!.number}',
        episodeNumber: _currentEpisode!.episodeNumber ?? int.tryParse(_currentEpisode!.number) ?? 1,
        currentPosition: currentPosition,
        totalDuration: totalDuration,
      );
      
      _lastSavedPosition = currentPosition;
      
      if (kDebugMode) {
        print('💾 Auto-saved progress: ${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)} (${(progressPercentage * 100).toStringAsFixed(1)}%)');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Auto-save failed: $e');
    }
  }
  
  // SAVE FINAL PROGRESS ON EPISODE COMPLETION
  Future<void> _saveFinalProgress() async {
    if (_currentEpisode == null) return;
    
    try {
      Duration currentPosition = Duration.zero;
      Duration totalDuration = Duration.zero;
      
      if (_useMediaKit && _mediaKitPlayer != null) {
        currentPosition = _mediaKitPlayer!.state.position;
        totalDuration = _mediaKitPlayer!.state.duration;
      } else if (_videoController != null) {
        currentPosition = _videoController!.value.position;
        totalDuration = _videoController!.value.duration;
      }
      
      // Save final progress even if at the end
      if (totalDuration.inSeconds > 0) {
        await WatchHistoryService.saveWatchProgress(
          animeId: widget.animeTitle,
          animeTitle: widget.animeTitle,
          animePoster: widget.animePoster,
          episodeId: _currentEpisode!.url,
          episodeTitle: _currentEpisode!.title ?? 'Episode ${_currentEpisode!.number}',
          episodeNumber: _currentEpisode!.episodeNumber ?? int.tryParse(_currentEpisode!.number) ?? 1,
          watchedDuration: currentPosition,
          totalDuration: totalDuration,
        );
        
        if (kDebugMode) {
          print('💾 Final progress saved: ${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Final save failed: $e');
    }
  }

  // UPDATE CURRENT SUBTITLE BASED ON VIDEO POSITION - Works for both players
  void _updateSubtitle() {
    // Skip if no player is initialized
    if (_useMediaKit && _mediaKitPlayer == null) return;
    if (!_useMediaKit && (_videoController == null || !_videoController!.value.isInitialized)) return;

    try {
      Duration position = Duration.zero;
      bool isPlaying = false;
      
      // Get position and playing state from appropriate player
      if (_useMediaKit && _mediaKitPlayer != null) {
        position = _mediaKitPlayer!.state.position;
        isPlaying = _mediaKitPlayer!.state.playing;
      } else if (_videoController != null) {
        position = _videoController!.value.position;
        isPlaying = _videoController!.value.isPlaying;
      }

      // ✅ Skip update if video is paused (performance optimization)
      if (!isPlaying) {
        // Clear subtitle when paused
        if (_currentSubtitle.isNotEmpty && mounted) {
          setState(() {
            _currentSubtitle = '';
            _previousSubtitle = '';
          });
        }
        return;
      }

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
        if (kDebugMode && newSubtitle.isNotEmpty) {
          print('📝 Timer subtitle: $newSubtitle');
        }
        
        // Apply translation if enabled
        if (_translationLang != 'none' && newSubtitle.isNotEmpty) {
          _translateSubtitle(newSubtitle).then((translated) {
            if (mounted) {
              setState(() {
                _currentSubtitle = translated;
              });
            }
          });
        } else {
          setState(() {
            _currentSubtitle = newSubtitle;
          });
        }
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
    if (kDebugMode) print('🎬 Playing next episode');
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final nextEpisode = widget.allEpisodes[currentIndex + 1];
    _switchEpisode(nextEpisode);
  }

  void _playPreviousEpisode() {
    if (!hasPreviousEpisode) return;
    if (kDebugMode) print('🎬 Playing previous episode');
    final currentIndex = widget.allEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final prevEpisode = widget.allEpisodes[currentIndex - 1];
    _switchEpisode(prevEpisode);
  }

  Future<void> _switchEpisode(Episode newEpisode) async {
    // ✅ Save progress for current episode before switching
    await _saveFinalProgress();
    
    // ✅ Proper cleanup before switching episode
    _subtitleTimer?.cancel();
    _progressSaveTimer?.cancel();
    
    // Clean up MediaKit
    if (_useMediaKit && _mediaKitPlayer != null) {
      try {
        _mediaKitPlayer?.dispose();
        _mediaKitVideoController = null;
      } catch (e) {
        if (kDebugMode) print('⚠️ MediaKit cleanup error: $e');
      }
    }
    
    // Clean up VideoPlayer
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoStateChanged);
      _videoController?.pause();
      _videoController?.dispose();
    }
    
    // Reset state tracking
    _previousIsPlaying = false;
    _previousPosition = Duration.zero;
    _previousSubtitle = '';
    _useMediaKit = false;
    _lastSavedPosition = Duration.zero;
    _watchStartTime = DateTime.now();
    
    setState(() {
      _currentEpisode = newEpisode;
      _isPlayerInitialized = false;
      _currentStreamLink = null;
      _allAvailableQualities = [];
      _currentSubtitle = '';
      _subtitles = [];
    });

    await _loadEpisodeAndPlay();
    await _loadWatchProgress(); // ✅ Load progress for new episode
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
    if (kDebugMode) print('📝 Subtitle button pressed');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSubtitleBottomSheet(),
    );
  }
  
  // TRANSLATE SUBTITLE TEXT WITH STYLE
  Future<String> _translateSubtitle(String text) async {
    if (_translationLang == 'none' || text.isEmpty) return text;
    
    // Check cache first (include style in cache key)
    final cacheKey = '${text.hashCode}_${_translationLang}_$_translationStyle';
    if (_translatedSubtitles.containsKey(cacheKey)) {
      return _translatedSubtitles[cacheKey]!;
    }
    
    try {
      final translated = await TranslationService.translateText(
        text, 
        _translationLang, 
        style: _translationStyle,
      );
      _translatedSubtitles[cacheKey] = translated;
      return translated;
    } catch (e) {
      if (kDebugMode) print('❌ Translation error: $e');
      return text;
    }
  }
  
  // SET TRANSLATION LANGUAGE
  Future<void> _setTranslationLanguage(String langCode) async {
    if (_translationLang == langCode) return;
    
    setState(() {
      _translationLang = langCode;
      _isTranslating = langCode != 'none';
    });
    
    if (langCode == 'none') {
      _translatedSubtitles.clear();
      if (kDebugMode) print('🌐 Translation disabled');
    } else {
      if (kDebugMode) print('🌐 Translation enabled: ${TranslationService.getLanguageName(langCode)} ($_translationStyle style)');
      
      // Clear cache when language changes to force re-translation
      _translatedSubtitles.clear();
      
      // Pre-translate current subtitle if exists
      if (_currentSubtitle.isNotEmpty) {
        final translated = await _translateSubtitle(_currentSubtitle);
        if (mounted) {
          setState(() {
            _currentSubtitle = translated;
            _isTranslating = false;
          });
        }
      }
    }
  }
  
  // SET TRANSLATION STYLE
  void _setTranslationStyle(String style) {
    if (_translationStyle == style) return;
    
    setState(() {
      _translationStyle = style;
    });
    
    // Clear cache to force re-translation with new style
    _translatedSubtitles.clear();
    
    if (kDebugMode) print('🎌 Translation style changed to: $style');
    
    // Re-translate current subtitle if translation is active
    if (_translationLang != 'none' && _currentSubtitle.isNotEmpty) {
      _translateSubtitle(_currentSubtitle).then((translated) {
        if (mounted) {
          setState(() {
            _currentSubtitle = translated;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // ✅ Save final progress before disposing
    _saveFinalProgress();
    
    _hideControlsTimer?.cancel();
    _subtitleTimer?.cancel(); // ✅ Cancel subtitle timer
    _progressSaveTimer?.cancel(); // ✅ Cancel progress timer
    
    // ✅ Remove video controller listener before dispose
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoStateChanged);
    }
    
    _disableWakelock();
    WidgetsBinding.instance.removeObserver(this);
    
    // ✅ Dispose MediaKit if being used
    if (_useMediaKit && _mediaKitPlayer != null) {
      try {
        _mediaKitPlayer?.dispose();
        _mediaKitVideoController = null;
        if (kDebugMode) print('🧹 MediaKit disposed');
      } catch (e) {
        if (kDebugMode) print('⚠️ MediaKit dispose error: $e');
      }
    }
    
    // ✅ Dispose VideoPlayer if exists
    if (_videoController != null) {
      try {
        _videoController?.pause();
        _videoController?.dispose();
        if (kDebugMode) print('🧹 VideoPlayer disposed');
      } catch (e) {
        if (kDebugMode) print('⚠️ VideoPlayer dispose error: $e');
      }
    }
    
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
            if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode)
              Center(child: _buildVideoPlayer()),
            if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
            if (_hasError) _buildErrorWidget(),
            // ✅ Custom subtitle overlay - Show when there's subtitle text
            if (_isPlayerInitialized && _currentSubtitle.isNotEmpty)
              _buildSubtitleOverlay(),
            // Show/hide controls based on _showControls
            if (_showControls && _isPlayerInitialized && !_isInPiP) _buildPortraitTopBar(),
            if (_showControls && _isPlayerInitialized && !_isInPiP)
              _buildPortraitCenterControls(),
            if (_showControls && _isPlayerInitialized && !_isInPiP)
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
          if (_isPlayerInitialized && !_hasError && !_isLoadingEpisode)
            Center(child: _buildVideoPlayer()),
          if (_isLoadingEpisode || _isLoadingPlayer) _buildLoadingScreen(),
          if (_hasError) _buildErrorWidget(),
          // Custom subtitle overlay - Show when there's subtitle text
          if (_isPlayerInitialized && _currentSubtitle.isNotEmpty)
            _buildSubtitleOverlay(),
          // Show/hide controls based on _showControls
          if (_showControls && _isPlayerInitialized && !_isInPiP) _buildLandscapeTopBar(),
          if (_showControls && _isPlayerInitialized && !_isInPiP)
            _buildLandscapeCenterControls(),
          if (_showControls && _isPlayerInitialized && !_isInPiP)
            _buildLandscapeBottomControls(),
        ],
      ),
    );
  }

  // SUBTITLE OVERLAY WITH TRANSLATION INDICATOR
  Widget _buildSubtitleOverlay() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: isLandscape ? 120 : 80, // Higher position to avoid controls
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Translation indicator
            if (_translationLang != 'none')
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.translate,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      TranslationService.getLanguageName(_translationLang),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isTranslating) ...[
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            
            // Subtitle text
            Container(
              constraints: BoxConstraints(maxWidth: isLandscape ? 1000 : 400),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9), // Very visible
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _translationLang != 'none' 
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _currentSubtitle,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: isLandscape ? 22 : 18, // Larger font
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
              onPressed: () {
                if (kDebugMode) print('🔙 Back button pressed');
                // Proper cleanup before navigation
                _subtitleTimer?.cancel();
                _hideControlsTimer?.cancel();
                Navigator.of(context).pop();
              },
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

  // PORTRAIT CENTER CONTROLS - Works for both MediaKit and VideoPlayer
  Widget _buildPortraitCenterControls() {
    bool isPlaying = false;
    
    // Get playing state from appropriate player
    if (_useMediaKit && _mediaKitPlayer != null) {
      isPlaying = _mediaKitPlayer!.state.playing;
    } else if (_videoController != null) {
      isPlaying = _videoController!.value.isPlaying;
    }
    
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
                if (_useMediaKit && _mediaKitPlayer != null) {
                  final currentPosition = _mediaKitPlayer!.state.position;
                  final newPosition = currentPosition - const Duration(seconds: 10);
                  _mediaKitPlayer!.seek(newPosition);
                } else if (_videoController != null) {
                  final currentPosition = _videoController!.value.position;
                  final newPosition = currentPosition - const Duration(seconds: 10);
                  _videoController!.seekTo(newPosition);
                }
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
                  if (_useMediaKit && _mediaKitPlayer != null) {
                    if (isPlaying) {
                      _mediaKitPlayer!.pause();
                      _hideControlsTimer?.cancel();
                      _disableWakelock();
                    } else {
                      _mediaKitPlayer!.play();
                      _startHideTimer();
                      _enableWakelock();
                    }
                  } else if (_videoController != null) {
                    if (isPlaying) {
                      _videoController!.pause();
                      _hideControlsTimer?.cancel();
                      _disableWakelock();
                    } else {
                      _videoController!.play();
                      _startHideTimer();
                      _enableWakelock();
                    }
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
                if (_useMediaKit && _mediaKitPlayer != null) {
                  final currentPosition = _mediaKitPlayer!.state.position;
                  final duration = _mediaKitPlayer!.state.duration;
                  final newPosition = currentPosition + const Duration(seconds: 10);
                  if (newPosition < duration) _mediaKitPlayer!.seek(newPosition);
                } else if (_videoController != null) {
                  final currentPosition = _videoController!.value.position;
                  final duration = _videoController!.value.duration;
                  final newPosition = currentPosition + const Duration(seconds: 10);
                  if (newPosition < duration) _videoController!.seekTo(newPosition);
                }
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

  // PORTRAIT BOTTOM CONTROLS - Works for both MediaKit and VideoPlayer
  Widget _buildPortraitBottomControls() {
    Duration position = Duration.zero;
    Duration duration = Duration.zero;
    double volume = 1.0;
    
    // Get state from appropriate player
    if (_useMediaKit && _mediaKitPlayer != null) {
      position = _mediaKitPlayer!.state.position;
      duration = _mediaKitPlayer!.state.duration;
      volume = _mediaKitPlayer!.state.volume / 100.0; // MediaKit uses 0-100
    } else if (_videoController != null) {
      position = _videoController!.value.position;
      duration = _videoController!.value.duration;
      volume = _videoController!.value.volume;
    }
    
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
                        onChanged: (value) {
                          final newPosition = duration * value;
                          if (_useMediaKit && _mediaKitPlayer != null) {
                            _mediaKitPlayer!.seek(newPosition);
                          } else if (_videoController != null) {
                            _videoController!.seekTo(newPosition);
                          }
                        },
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
                        if (_useMediaKit && _mediaKitPlayer != null) {
                          _mediaKitPlayer!.setVolume(volume > 0 ? 0 : 100);
                        } else if (_videoController != null) {
                          _videoController!.setVolume(volume > 0 ? 0 : 1);
                        }
                      });
                    },
                    icon: Icon(
                      volume > 0 
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
                // Exit fullscreen first, then navigate back
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    _subtitleTimer?.cancel();
                    _hideControlsTimer?.cancel();
                    Navigator.of(context).pop();
                  }
                });
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

  // LANDSCAPE CENTER CONTROLS - Works for both MediaKit and VideoPlayer
  Widget _buildLandscapeCenterControls() {
    bool isPlaying = false;
    
    // Get playing state from appropriate player
    if (_useMediaKit && _mediaKitPlayer != null) {
      isPlaying = _mediaKitPlayer!.state.playing;
    } else if (_videoController != null) {
      isPlaying = _videoController!.value.isPlaying;
    }
    
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
                if (_useMediaKit && _mediaKitPlayer != null) {
                  final currentPosition = _mediaKitPlayer!.state.position;
                  final newPosition = currentPosition - const Duration(seconds: 10);
                  _mediaKitPlayer!.seek(newPosition);
                } else if (_videoController != null) {
                  final currentPosition = _videoController!.value.position;
                  final newPosition = currentPosition - const Duration(seconds: 10);
                  _videoController!.seekTo(newPosition);
                }
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
                  if (_useMediaKit && _mediaKitPlayer != null) {
                    if (isPlaying) {
                      _mediaKitPlayer!.pause();
                      _hideControlsTimer?.cancel();
                      _disableWakelock();
                    } else {
                      _mediaKitPlayer!.play();
                      _startHideTimer();
                      _enableWakelock();
                    }
                  } else if (_videoController != null) {
                    if (isPlaying) {
                      _videoController!.pause();
                      _hideControlsTimer?.cancel();
                      _disableWakelock();
                    } else {
                      _videoController!.play();
                      _startHideTimer();
                      _enableWakelock();
                    }
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
                if (_useMediaKit && _mediaKitPlayer != null) {
                  final currentPosition = _mediaKitPlayer!.state.position;
                  final duration = _mediaKitPlayer!.state.duration;
                  final newPosition = currentPosition + const Duration(seconds: 10);
                  if (newPosition < duration) _mediaKitPlayer!.seek(newPosition);
                } else if (_videoController != null) {
                  final currentPosition = _videoController!.value.position;
                  final duration = _videoController!.value.duration;
                  final newPosition = currentPosition + const Duration(seconds: 10);
                  if (newPosition < duration) _videoController!.seekTo(newPosition);
                }
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

  // LANDSCAPE BOTTOM CONTROLS - Works for both MediaKit and VideoPlayer
  Widget _buildLandscapeBottomControls() {
    Duration position = Duration.zero;
    Duration duration = Duration.zero;
    double volume = 1.0;
    
    if (_useMediaKit && _mediaKitPlayer != null) {
      position = _mediaKitPlayer!.state.position;
      duration = _mediaKitPlayer!.state.duration;
      volume = _mediaKitPlayer!.state.volume / 100.0;
    } else if (_videoController != null) {
      position = _videoController!.value.position;
      duration = _videoController!.value.duration;
      volume = _videoController!.value.volume;
    }
    
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
                      onChanged: (value) {
                        final newPosition = duration * value;
                        if (_useMediaKit && _mediaKitPlayer != null) {
                          _mediaKitPlayer!.seek(newPosition);
                        } else if (_videoController != null) {
                          _videoController!.seekTo(newPosition);
                        }
                      },
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
                          if (_useMediaKit && _mediaKitPlayer != null) {
                            _mediaKitPlayer!.setVolume(volume > 0 ? 0 : 100);
                          } else if (_videoController != null) {
                            _videoController!.setVolume(volume > 0 ? 0 : 1);
                          }
                        });
                      },
                      icon: Icon(
                        volume > 0 
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

  // SUBTITLE BOTTOM SHEET WITH TRANSLATION
  Widget _buildSubtitleBottomSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                  'Subtitle & Translation',
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
          
          // SUBTITLE SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.subtitles, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Subtitle Source',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Subtitle options - Show all available subtitles
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200), // Increased height
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _availableSubtitles.length + 1,
              itemBuilder: (context, index) {
                final isOffOption = index == 0;
                final lang = isOffOption ? 'OFF' : _availableSubtitles[index - 1]['lang']!;
                final isSelected = isOffOption 
                    ? _subtitles.isEmpty 
                    : _selectedSubtitleLang == lang;
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    onTap: () {
                      if (isOffOption) {
                        setState(() {
                          _subtitles = [];
                          _currentSubtitle = '';
                          _subtitleTimer?.cancel();
                        });
                      } else {
                        _loadSubtitle(lang);
                      }
                    },
                    leading: Icon(
                      isOffOption ? Icons.subtitles_off_outlined : Icons.closed_caption,
                      color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
                      size: 18,
                    ),
                    title: Text(
                      lang,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    subtitle: isOffOption ? null : Text(
                      'VTT Subtitle',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),
          
          // TRANSLATION SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.translate, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI Translation',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Translation Style Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _translationStyle,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF818CF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'anime', child: Text('🎌 Anime')),
                      DropdownMenuItem(value: 'casual', child: Text('😎 Casual')),
                      DropdownMenuItem(value: 'formal', child: Text('👔 Formal')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _setTranslationStyle(value);
                      }
                    },
                  ),
                ),
                if (_isTranslating) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Translation options
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: TranslationService.supportedLanguages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // No translation option
                  return ListTile(
                    onTap: () => _setTranslationLanguage('none'),
                    leading: Icon(
                      Icons.translate_outlined,
                      color: _translationLang == 'none' ? const Color(0xFF818CF8) : Colors.white70,
                      size: 18,
                    ),
                    title: Text(
                      'No Translation',
                      style: GoogleFonts.inter(
                        color: _translationLang == 'none' ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: _translationLang == 'none' ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    trailing: _translationLang == 'none'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  );
                }
                
                final langEntry = TranslationService.supportedLanguages.entries.elementAt(index - 1);
                final langCode = langEntry.key;
                final langName = langEntry.value;
                final isSelected = _translationLang == langCode;
                
                return ListTile(
                  onTap: () => _setTranslationLanguage(langCode),
                  leading: Icon(
                    Icons.translate,
                    color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
                    size: 18,
                  ),
                  title: Text(
                    langName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
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