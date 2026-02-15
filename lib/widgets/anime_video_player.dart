// widgets/anime_video_player.dart - Advanced video player with PiP, gestures, and caching
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'dart:async';


// Advanced Features
import 'package:floating/floating.dart';

import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/anime_model.dart';
import '../services/zoro_service.dart';
import '../services/anime_service.dart';
import '../services/subtitle_parser_service.dart';
import '../services/watch_history_service.dart';
import '../services/translation_service.dart';
import '../providers/global_player_provider.dart';
import '../utils/platform_utils.dart';
import 'video_player_controls.dart';
import 'video_player_subtitle_overlay.dart';
import 'video_player_next_episode_overlay.dart';
import 'video_player_seeking_overlay.dart';
import 'video_player_settings_modal.dart';

import '../constants/app_colors.dart';

class AnimeVideoPlayer extends StatefulWidget {
  final Episode episodeToLoad;
  final String animeId;
  final String animeTitle;
  final List<Episode>? allEpisodes;
  final String? animePoster;

  const AnimeVideoPlayer({
    super.key,
    required this.episodeToLoad,
    required this.animeId,
    required this.animeTitle,
    this.allEpisodes,
    this.animePoster,
  });

  @override
  State<AnimeVideoPlayer> createState() => _AnimeVideoPlayerState();
}

class _AnimeVideoPlayerState extends State<AnimeVideoPlayer> with WidgetsBindingObserver {
  // Players
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideoController;
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _positionSubscription;

  // Episode & Stream
  Episode? _currentEpisode;
  List<Episode> _localAllEpisodes = [];
  StreamLink? _currentStreamLink;
  List<StreamLink> _allAvailableQualities = [];
  Map<String, String> _currentHeaders = {};

  // Subtitles
  List<ParsedSubtitle> _subtitles = [];
  String _currentSubtitle = '';
  List<Map<String, String>> _availableSubtitles = [];
  String _selectedSubtitleLang = 'Off';
  String _selectedAILang = 'none';
  bool _isTranslating = false;

  // Player State
  bool _isLoadingEpisode = true;
  bool _isLoadingPlayer = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerInitialized = false;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isFullScreen = false;

  // Timers
  Timer? _hideControlsTimer;
  Timer? _subtitleTimer;
  Timer? _progressSaveTimer;
  Timer? _nextEpisodeTimer;
  Timer? _indicatorTimer;

  // Next Episode
  bool _showNextEpisodeCountdown = false;
  int _nextEpisodeCountdown = 5;
  bool _isAutoPlaying = false;

  // Subtitle Settings
  double _subtitleFontSize = 18.0;
  Color _subtitleColor = Colors.white;
  double _subtitleBackgroundOpacity = 0.5;
  double _subtitleOffset = 80.0;

  // Audio Type
  String _audioType = 'sub'; // 'sub' or 'dub'

  // Watch History
  Duration _lastSavedPosition = Duration.zero;

  // PiP Mode
  Floating? _floating;
  bool _isPipActive = false;

  // Brightness & Volume
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;

  // Gesture Detection
  double _dragStartY = 0;
  double _dragStartValue = 0;
  bool _isDraggingBrightness = false;


  // ========== ADVANCED EPISODE LIST FEATURES ==========
  String _epSearch = '';
  String _epSort = 'desc';
  int _epPage = 1;
  static const int _epsPerPage = 50;
  bool _isGridMode = false;
  bool _isDraggingVolume = false;
  
  // New Features State
  double _playbackSpeed = 1.0;
  bool _isAutoPlayEnabled = true;

  // Double Tap Seek Overlay
  bool _showSeekOverlay = false;
  Duration _seekOverlayDuration = Duration.zero;
  bool _isSeekForward = true;
  Timer? _seekOverlayTimer;
  bool _isSpeedUp = false; // YouTube-style 2x speed hold

  late GlobalPlayerProvider _globalPlayerProvider;



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _floating = Floating();
    _checkPipAvailability();
    _currentEpisode = widget.episodeToLoad;
    _localAllEpisodes = widget.allEpisodes ?? [widget.episodeToLoad];
    _enableWakelock();
    _loadPlayerSettings();
    _globalPlayerProvider = Provider.of<GlobalPlayerProvider>(context, listen: false);
    _loadEpisodeAndPlay();
    
    // Set Full Player Active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GlobalPlayerProvider>(context, listen: false).setFullPlayerActive(true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _subtitleTimer?.cancel();
    _progressSaveTimer?.cancel();
    _nextEpisodeTimer?.cancel();
    _indicatorTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _positionSubscription?.cancel();
    // _floating?.dispose(); // Floating package doesn't have dispose method
    // _mediaKitPlayer?.dispose(); // DO NOT DISPOSE SHARED PLAYER
    // _videoController?.dispose(); 
    
    // Reset Full Player Active using cached provider
    _globalPlayerProvider.setFullPlayerActive(false);
    
    // IMPORTANT: Do NOT dispose _mediaKitPlayer or _videoController 
    // because they are shared from GlobalPlayerProvider!
    
    super.dispose();
  }





  List<Episode> _getFilteredEpisodes() {
    // Filter by search
    List<Episode> filtered = _localAllEpisodes.where((e) {
      final query = _epSearch.toLowerCase();
      final num = e.number.toLowerCase();
      final title = (e.title ?? '').toLowerCase();
      return num.contains(query) || title.contains(query);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final nA = double.tryParse(a.number) ?? 0;
      final nB = double.tryParse(b.number) ?? 0;
      return _epSort == 'asc' ? nA.compareTo(nB) : nB.compareTo(nA);
    });

    return filtered;
  }

  List<Episode> _getVisibleEpisodes(List<Episode> filtered) {
    if (filtered.isEmpty) return [];
    final start = (_epPage - 1) * _epsPerPage;
    final end = (start + _epsPerPage).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  Widget _buildEpisodeControls() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Search Bar & Layout Toggle
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40, // Compact height
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppColors.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search episode...',
                              hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            cursorColor: AppColors.primary,
                            onChanged: (v) => setState(() { 
                              _epSearch = v; 
                              _epPage = 1; // Reset to page 1 on search
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Layout Toggle (List/Grid)
                GestureDetector(
                  onTap: () => setState(() => _isGridMode = !_isGridMode),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Icon(
                      _isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sort & Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _epSort = _epSort == 'asc' ? 'desc' : 'asc';
                    _epPage = 1; // Reset page on sort change
                  }),
                  child: Row(
                    children: [
                      Icon(
                        _epSort == 'asc' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                        color: AppColors.primary, 
                        size: 14
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _epSort == 'asc' ? 'Oldest First' : 'Newest First',
                        style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_getFilteredEpisodes().length} Eps',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    if (totalPages <= 1) return const SliverToBoxAdapter(child: SizedBox(height: 10));

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: _epPage > 1 ? () => setState(() => _epPage--) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.chevron_left_rounded, color: _epPage > 1 ? Colors.white : Colors.white24, size: 20),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'Page $_epPage / $totalPages',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            InkWell(
              onTap: _epPage < totalPages ? () => setState(() => _epPage++) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.chevron_right_rounded, color: _epPage < totalPages ? Colors.white : Colors.white24, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchFullEpisodeList() async {
    try {
      final episodes = await AnimeService().getEpisodes(widget.animeId);
      if (episodes.isNotEmpty && mounted) {
        setState(() {
          _localAllEpisodes = episodes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching full episode list: $e');
    }
  }

  Future<void> _checkPipAvailability() async {
    // Check PiP availability if needed, but 'floating' version varies
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (!mounted) return;
      setState(() {
        _isPipActive = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      setState(() {
        _isPipActive = false;
      });
    }
  }

  Future<void> _togglePip() async {
    if (_floating == null) return;
    try {
      final canPip = await _floating!.isPipAvailable;
      if (canPip) {
        await _floating!.enable(const ImmediatePiP());
        setState(() {
          _isPipActive = true;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error entering PiP: $e');
    }
  }

  void _setLandscapeOrientation() {
    if (PlatformUtils.isDesktop) {
      // Desktop fullscreen using window_manager
      windowManager.setFullScreen(true);
    } else {
      // Mobile fullscreen using system orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _hideSystemUI();
  }

  void _resetOrientation() {
    if (PlatformUtils.isDesktop) {
      // Exit desktop fullscreen
      windowManager.setFullScreen(false);
    } else {
      // Reset mobile orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _showSystemUI();
  }



  // ========== SYSTEM UI ==========
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  void _enableWakelock() {
    WakelockPlus.enable();
  }

  void _disableWakelock() {
    WakelockPlus.disable();
  }

  // ========== SETTINGS ==========
  Future<void> _loadPlayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _subtitleFontSize = prefs.getDouble('subtitle_font_size') ?? 12.0; // Default 12px
        _subtitleBackgroundOpacity = prefs.getDouble('subtitle_bg_opacity') ?? 0.5;
        _subtitleOffset = prefs.getDouble('subtitle_offset') ?? 80.0;
        final colorValue = prefs.getInt('subtitle_color');
        if (colorValue != null) _subtitleColor = Color(colorValue);
        
        // Load preferred languages (default to English + Indo AI if not set)
        _selectedSubtitleLang = prefs.getString('subtitle_lang') ?? 'English'; 
        _selectedAILang = prefs.getString('ai_lang') ?? 'id';
        _globalPlayerProvider.setAISettings(_selectedAILang);
      });
    }
  }

  Future<void> _savePlayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('subtitle_font_size', _subtitleFontSize);
    await prefs.setDouble('subtitle_bg_opacity', _subtitleBackgroundOpacity);
    await prefs.setDouble('subtitle_offset', _subtitleOffset);
    await prefs.setInt('subtitle_color', _subtitleColor.toARGB32());
    await prefs.setString('subtitle_lang', _selectedSubtitleLang);
    await prefs.setString('ai_lang', _selectedAILang);
  }

  // ========== EPISODE LOADING ==========
  Future<void> _loadEpisodeAndPlay() async {
    if (_currentEpisode == null) return;

    debugPrint('🎬 [PLAYER] Loading Episode: ${widget.animeTitle} - ${_currentEpisode?.number}');

    // Check if we are already playing this episode in background
    if (_globalPlayerProvider.isInitialized && 
        _globalPlayerProvider.currentEpisode?.url == _currentEpisode!.url) {
        
        debugPrint('🚀 [PLAYER] BYPASS: Reusing existing global player instance (No reload)');
        
        // Just attach UI to existing player
        setState(() {
            _mediaKitPlayer = _globalPlayerProvider.player;
            _mediaKitVideoController = _globalPlayerProvider.controller;
            _isPlayerInitialized = true;
            _isLoadingEpisode = false;
            
            // Sync subtitle state from provider
            _selectedSubtitleLang = _globalPlayerProvider.selectedSubtitleLang;
            _currentSubtitle = _globalPlayerProvider.currentSubtitle;
            _subtitles = _globalPlayerProvider.subtitles.cast<ParsedSubtitle>();
            
            // Re-fetch additional data if needed (subs/qualities) but DON'T restart player
            // Metadata is fast to reload if needed for UI lists
        });
        
        // Re-setup listener
        _positionSubscription?.cancel();
        _positionSubscription = _mediaKitPlayer!.stream.position.listen((position) {
          if (mounted && _globalPlayerProvider.subtitles.isNotEmpty) {
            _updateSubtitle(position);
          }
          _checkAutoPlay(position);
        });
        
        return; 
    }


    setState(() {
      _isLoadingEpisode = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final episodeId = _currentEpisode!.url;
      final stopwatch = Stopwatch()..start();
      debugPrint('⏳ [PLAYER] Fetching stream qualities for $episodeId...');
      final streamData = await ZoroService().getQualities(episodeId, dub: _audioType == 'dub');
      debugPrint('✅ [PLAYER] Qualities fetched in ${stopwatch.elapsedMilliseconds}ms');

      if (streamData == null || !mounted) {
        throw Exception('Failed to load stream');
      }

      // Parse sources
      final sources = streamData['sources'] as List? ?? [];
      final qualities = <StreamLink>[];
      
      for (var source in sources) {
        if (source is Map) {
          qualities.add(StreamLink(
            provider: 'Primary',
            url: source['url']?.toString() ?? '',
            quality: source['quality']?.toString() ?? 'auto',
            type: source['type']?.toString() ?? 'hls',
          ));
        }
      }

      // Parse subtitles
      final subtitles = streamData['subtitles'] as List? ?? [];
      final availableSubs = <Map<String, String>>[];
      
      for (var sub in subtitles) {
        if (sub is Map) {
          availableSubs.add({
            'url': sub['url']?.toString() ?? '',
            'lang': sub['lang']?.toString() ?? sub['label']?.toString() ?? 'Unknown',
            'label': sub['label']?.toString() ?? sub['lang']?.toString() ?? 'Unknown',
          });
        }
      }

      // Parse headers
      final headers = streamData['headers'] as Map? ?? {};
      final parsedHeaders = <String, String>{};
      headers.forEach((key, value) {
        parsedHeaders[key.toString()] = value.toString();
      });

      if (mounted) {
        // Select default quality (360p preferred for speed)
        StreamLink? initialQuality;
        if (qualities.isNotEmpty) {
          initialQuality = qualities.firstWhere(
            (q) => q.quality?.contains('360') == true,
            orElse: () => qualities.first,
          );
        }

        setState(() {
          _allAvailableQualities = qualities;
          _availableSubtitles = availableSubs;
          _currentHeaders = parsedHeaders;
          _isLoadingEpisode = false;
          _currentStreamLink = initialQuality;
        });
        
        // Update Global Provider Metadata & SMTC
        if (_currentStreamLink != null) {
          _globalPlayerProvider.updateMetadata(
            episode: _currentEpisode,
            title: widget.animeTitle,
            poster: widget.animePoster,
            animeId: widget.animeId,
          );
        }

        if (_currentStreamLink != null) {
          // Check if previous subtitle preference exists in new list
          final prevLang = _selectedSubtitleLang;
          final matchingSub = availableSubs.firstWhere(
            (s) => s['label'] == prevLang || s['lang'] == prevLang,
            orElse: () => {},
          );

          if (matchingSub.isNotEmpty && prevLang != 'Off') {
             _loadSubtitle(prevLang);
          } else {
             // Fallback to English if preferred not found, or maintain 'Off'
             final fallback = availableSubs.firstWhere(
                (s) => s['label']?.contains('English') == true || s['lang']?.contains('English') == true,
                orElse: () => {},
             );
             
             if (fallback.isNotEmpty) {
               _selectedSubtitleLang = fallback['label'] ?? 'English';
               _loadSubtitle(_selectedSubtitleLang);
             } else {
               _subtitles = [];
               _currentSubtitle = '';
               _selectedSubtitleLang = 'Off';
             }
          }

          await _initializePlayer();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEpisode = false;
          _hasError = true;
          _errorMessage = 'Failed to load episode: $e';
        });
      }
    }
  }

  // ========== PLAYER INITIALIZATION ==========
  Future<void> _initializePlayer() async {
    if (_currentStreamLink == null || !mounted) return;
    
    // Ensure Global Player is ready
    if (!_globalPlayerProvider.isInitialized) {
       debugPrint('⚠️ [PLAYER] Provider not initialized, waiting 500ms...');
       await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      // Only show full loading screen if this is a fresh init (not quality switch)
      if (_mediaKitPlayer == null) {
        _isLoadingPlayer = true;
      }
      _hasError = false;
      _isPlayerInitialized = _mediaKitPlayer != null; // Keep current frame if switching quality
    });

    try {
      // Use SHARED Player from GlobalProvider
      _mediaKitPlayer = _globalPlayerProvider.player;
      _mediaKitVideoController = _globalPlayerProvider.controller;

      debugPrint('🎬 [PLAYER] Opening media: ${_currentStreamLink?.url}');
      final headers = _currentStreamLink?.headers ?? 
          (_currentHeaders.isNotEmpty 
              ? _currentHeaders 
              : {'User-Agent': 'Sukinime/2.0', 'Referer': 'https://hianime.to/'});

      // Capture current position before switching stream (for quality change)
      final currentPosition = _mediaKitPlayer!.state.position;
      final shouldRestorePosition = currentPosition > Duration.zero && _mediaKitPlayer!.state.playing;

      await _mediaKitPlayer!.open(
        Media(_currentStreamLink!.url, httpHeaders: headers),
        play: true,
      );
      
      // Restore position if switching quality
      if (shouldRestorePosition) {
        await _mediaKitPlayer!.seek(currentPosition);
      }

      // Cancel previous position subscription if it exists to prevent duplicates
      _positionSubscription?.cancel();
      
      // Setup position listener for subtitles
      _positionSubscription = _mediaKitPlayer!.stream.position.listen((position) {
        if (mounted && _globalPlayerProvider.subtitles.isNotEmpty) {
          _updateSubtitle(position);
        }
        _checkAutoPlay(position);
      });


      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _isPlayerInitialized = true;
          _showControls = true;
        });
        
        _startHideTimer();
        _startProgressTracking();
        
        // Defer background tasks after player is ready
        Future.microtask(() {
          if (mounted) {
            _loadWatchProgress();
            if (_localAllEpisodes.length <= 1) {
              _fetchFullEpisodeList();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlayer = false;
          _hasError = true;
          _errorMessage = 'Player initialization failed: $e';
        });
      }
    }
  }

  // ========== SUBTITLE HANDLING ==========
  Future<void> _loadSubtitle(String lang) async {
    final subtitle = _availableSubtitles.firstWhere(
      (s) => s['lang'] == lang || s['label'] == lang,
      orElse: () => {},
    );

    if (subtitle.isEmpty || subtitle['url'] == null) {
      setState(() {
        _subtitles = [];
        _currentSubtitle = '';
        _selectedSubtitleLang = 'Off';
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(subtitle['url']!));
      if (response.statusCode == 200) {
        final parsed = SubtitleParserService.parseSubtitles(response.body);
        if (mounted) {
          _globalPlayerProvider.setSubtitles(parsed, lang);
          setState(() {
            _subtitles = parsed;
            _selectedSubtitleLang = lang;
          });
        }
      }
    } catch (e) {
      debugPrint('Subtitle load error: $e');
    }
  }
  void _updateSubtitle(Duration position) {
    setState(() {
      _currentSubtitle = _globalPlayerProvider.currentSubtitle;
    });
  }

  void _prefetchTranslations(int startIndex, int count) {
    if (_subtitles.isEmpty || startIndex >= _subtitles.length) return;
    
    final end = (startIndex + count < _subtitles.length) 
        ? startIndex + count 
        : _subtitles.length;
        
    final textsToTranslate = _subtitles
        .sublist(startIndex, end)
        .map((s) => s.text)
        .toList();
        
    TranslationService.batchTranslateTexts(textsToTranslate, _selectedAILang);
  }



  // ========== CONTROLS ==========
  void _toggleControls() {
    // Correct logic: even when locked, we should be able to show/hide the lock icon
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLocked) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlay() {
    if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.playOrPause();
    } else if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    }
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (!_isPlayerInitialized) return;
    
    if (_mediaKitPlayer != null) {
      final current = _mediaKitPlayer!.state.position;
      _mediaKitPlayer!.seek(current + Duration(seconds: seconds));
    } else if (_videoController != null) {
      final current = _videoController!.value.position;
      _videoController!.seekTo(current + Duration(seconds: seconds));
    }
    _startHideTimer();
  }

  void _seekTo(double milliseconds) {
    if (!_isPlayerInitialized) return;
    
    final position = Duration(milliseconds: milliseconds.toInt());
    if (_mediaKitPlayer != null) {
      _mediaKitPlayer!.seek(position);
    } else if (_videoController != null) {
      _videoController!.seekTo(position);
    }
  }

  // ========== EPISODE NAVIGATION ==========
  Future<void> _switchEpisode(Episode episode) async {
    _nextEpisodeTimer?.cancel();
    setState(() {
      _showNextEpisodeCountdown = false;
      _currentEpisode = episode;
      _isAutoPlaying = false;
      // Immediately clear subtitles to prevent showing previous episode's subs
      _subtitles = [];
      _currentSubtitle = '';
    });
    
    await _saveFinalProgress();
    // We don't dispose players here anymore, _initializePlayer handles it better
    // by reusing them. If switching episodes, we just open new media.
    
    await _loadEpisodeAndPlay();
  }

  void _checkAutoPlay(Duration position) {
    if (!_isPlayerInitialized || _isAutoPlaying || _showNextEpisodeCountdown) return;

    final duration = _mediaKitPlayer?.state.duration ?? _videoController?.value.duration ?? Duration.zero;
    if (duration.inSeconds > 0) {
      final progress = position.inMilliseconds / duration.inMilliseconds;
      if (progress >= 0.98 && hasNextEpisode && _isAutoPlayEnabled) {
        _startNextEpisodeCountdown();
      }
    }
  }

  void _startNextEpisodeCountdown() {
    if (_showNextEpisodeCountdown || _isAutoPlaying) return;

    setState(() {
      _showNextEpisodeCountdown = true;
      _nextEpisodeCountdown = 5;
    });

    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_nextEpisodeCountdown > 0) {
          _nextEpisodeCountdown--;
        } else {
          timer.cancel();
          _playNextEpisode();
        }
      });
    });
  }

  Future<void> _playNextEpisode() async {
    if (_isAutoPlaying || !hasNextEpisode) return;
    _isAutoPlaying = true;

    final currentIndex = _localAllEpisodes.indexWhere((e) => e.url == _currentEpisode!.url);
    final nextEpisode = _localAllEpisodes[currentIndex + 1];

    setState(() {
      _showNextEpisodeCountdown = false;
      _isAutoPlaying = false;
    });

    await _switchEpisode(nextEpisode);
  }

  // ========== WATCH HISTORY ==========
  void _startProgressTracking() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _autoSaveProgress();
    });
  }

  Future<void> _autoSaveProgress() async {
    if (!_isPlayerInitialized || _currentEpisode == null) return;

    final position = _mediaKitPlayer?.state.position ?? _videoController?.value.position ?? Duration.zero;
    final duration = _mediaKitPlayer?.state.duration ?? _videoController?.value.duration ?? Duration.zero;
    final isPlaying = _mediaKitPlayer?.state.playing ?? _videoController?.value.isPlaying ?? false;

    if (!isPlaying || position.inSeconds < 5 || duration.inSeconds < 10) return;
    if (position == _lastSavedPosition) return;

    final progress = position.inMilliseconds / duration.inMilliseconds;
    if (progress >= 0.98) return;

    await WatchHistoryService.autoSaveProgress(
      animeId: widget.animeId,
      animeTitle: widget.animeTitle,
      animePoster: widget.animePoster,
      episodeId: _currentEpisode!.url,
      episodeTitle: _currentEpisode!.title ?? 'Episode ${_currentEpisode!.number}',
      episodeNumber: _currentEpisode!.episodeNumber ?? int.tryParse(_currentEpisode!.number) ?? 1,
      currentPosition: position,
      totalDuration: duration,
    );

    _lastSavedPosition = position;
  }

  Future<void> _saveFinalProgress() async {
    if (_currentEpisode == null) return;

    final position = _mediaKitPlayer?.state.position ?? _videoController?.value.position ?? Duration.zero;
    final duration = _mediaKitPlayer?.state.duration ?? _videoController?.value.duration ?? Duration.zero;

    if (duration.inSeconds > 0) {
      await WatchHistoryService.saveWatchProgress(
        animeId: widget.animeId,
        animeTitle: widget.animeTitle,
        animePoster: widget.animePoster,
        episodeId: _currentEpisode!.url,
        episodeTitle: _currentEpisode!.title ?? 'Episode ${_currentEpisode!.number}',
        episodeNumber: _currentEpisode!.episodeNumber ?? int.tryParse(_currentEpisode!.number) ?? 1,
        watchedDuration: position,
        totalDuration: duration,
      );
    }
  }

  Future<void> _loadWatchProgress() async {
    if (_currentEpisode == null) return;

    final progress = await WatchHistoryService.getEpisodeProgress(widget.animeId, _currentEpisode!.url);
    if (progress != null && progress.watchedDuration.inSeconds > 5 && mounted) {
      // ✅ Parity: Auto-resume directly without popup if it's the same episode
      _seekTo(progress.watchedDuration.inMilliseconds.toDouble());
    }
  }

  // ========== HELPERS ==========
  bool get hasNextEpisode {
    final currentIndex = _localAllEpisodes.indexWhere((e) => e.url == _currentEpisode?.url);
    return currentIndex != -1 && currentIndex < _localAllEpisodes.length - 1;
  }

  bool get hasPrevEpisode {
    final currentIndex = _localAllEpisodes.indexWhere((e) => e.url == _currentEpisode?.url);
    return currentIndex > 0;
  }

  void _startIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullScreen && !_isLocked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        if (_isLocked) {
          // Locked - prevent exit
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unlock the player to exit'),
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }

        if (_isFullScreen) {
          _resetOrientation();
          setState(() {
            _isFullScreen = false;
          });
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragStart: (details) {
          if (_isLocked) return;
          final width = MediaQuery.of(context).size.width;
          _dragStartY = details.globalPosition.dy;
          if (details.globalPosition.dx < width / 2) {
            _isDraggingBrightness = true;
            _dragStartValue = _currentBrightness;
          } else {
            _isDraggingVolume = true;
            _dragStartValue = _currentVolume;
          }
        },
        onVerticalDragUpdate: (details) async {
          if (_isLocked) return;
          final height = MediaQuery.of(context).size.height;
          final delta = (_dragStartY - details.globalPosition.dy) / height;
          final newValue = (_dragStartValue + delta).clamp(0.0, 1.0);

          if (_isDraggingBrightness) {
            setState(() {
              _currentBrightness = newValue;
              _showBrightnessIndicator = true;
            });
            await ScreenBrightness().setApplicationScreenBrightness(newValue);
          } else if (_isDraggingVolume) {
            setState(() {
              _currentVolume = newValue;
              _showVolumeIndicator = true;
            });
            VolumeController.instance.setVolume(newValue);
          }
          _startIndicatorTimer();
        },
        onVerticalDragEnd: (_) {
          _isDraggingBrightness = false;
          _isDraggingVolume = false;
        },
        onDoubleTapDown: (details) {
          if (_isLocked) return;
          final width = MediaQuery.of(context).size.width;
          final tapX = details.globalPosition.dx;
          
          bool isForward = false;
          if (tapX < width / 3) {
            isForward = false;
          } else if (tapX > width * 2 / 3) {
            isForward = true;
          } else {
            return; // Ignore middle taps
          }

          // Accumulate seek duration
          final baseSeek = const Duration(seconds: 10);
          setState(() {
            if (_showSeekOverlay && _isSeekForward == isForward) {
              // Add to existing
              _seekOverlayDuration += baseSeek;
            } else {
              // New seek
              _seekOverlayDuration = baseSeek;
              _isSeekForward = isForward;
              _showSeekOverlay = true;
            }
          });

          // Reset timer
          _seekOverlayTimer?.cancel();
          _seekOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
             if (mounted) {
               setState(() => _showSeekOverlay = false);
             }
          });

          // Perform Seek
          _seekRelative(isForward ? 10 : -10);
        },
        onLongPressStart: (_) {
          if (_isLocked) return;
          setState(() {
            _isSpeedUp = true;
          });
          _mediaKitPlayer?.setRate(2.0);
          _videoController?.setPlaybackSpeed(2.0);
        },
        onLongPressEnd: (_) {
          if (_isLocked) return;
          setState(() {
            _isSpeedUp = false;
          });
          // Restore user preference
          _mediaKitPlayer?.setRate(_playbackSpeed);
          _videoController?.setPlaybackSpeed(_playbackSpeed);
        },
        child: Stack(
          children: [
            // Video Player
            if (_isPlayerInitialized && _mediaKitVideoController != null)
              _buildPlayerContainer(),

            // Loading Indicator
            if (_isLoadingEpisode || _isLoadingPlayer)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF59E0B),
                ),
              ),

            // Error Message
            if (_hasError && _errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadEpisodeAndPlay,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            // Speed Up Overlay (YouTube Style)
            if (_isSpeedUp)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text(
                          '2x Speed',
                          style: GoogleFonts.inter(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),

             // Double Tap Seek Overlay
            if (_showSeekOverlay)
              VideoPlayerSeekingOverlay(
                duration: _seekOverlayDuration,
                isForward: _isSeekForward,
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildIndicator(IconData icon, double value) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Container(
              width: 100,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContainer() {
    if (!_isPlayerInitialized || _mediaKitVideoController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait && !_isFullScreen;
    
    final filteredEpisodes = _getFilteredEpisodes();
    final visibleEpisodes = _getVisibleEpisodes(filteredEpisodes);
    final totalPages = (filteredEpisodes.length / _epsPerPage).ceil();
    
    if (isPortrait) {
      return Column(
        children: [
          // Video at top with controls
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Video(
                  controller: _mediaKitVideoController!,
                  controls: NoVideoControls,
                ),
                if (_isPlayerInitialized) _buildPlayerControls(),
              ],
            ),
          ),
          // Scrollable Episode List & Details below
          Expanded(
            child: Container(
              color: AppColors.background,
              child: CustomScrollView(
                slivers: [
                   SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.all(16),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(widget.animeTitle, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              'Currently Playing: Episode ${_currentEpisode?.number}${_currentEpisode?.title != null ? " - ${_currentEpisode!.title}" : ""}', 
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),
                            Text('EPISODES', style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                         ],
                       ),
                     ),
                   ),
                   SliverPadding(
                     padding: EdgeInsets.zero,
                     sliver: _buildEpisodeControls(),
                   ),

                   // Episode List / Grid
                   if (_isGridMode)
                     SliverPadding(
                       padding: const EdgeInsets.symmetric(horizontal: 16),
                       sliver: SliverGrid(
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 5,
                           mainAxisSpacing: 10,
                           crossAxisSpacing: 10,
                           childAspectRatio: 1.0,
                         ),
                         delegate: SliverChildBuilderDelegate(
                           (context, index) {
                             if (index >= visibleEpisodes.length) return null;
                             final ep = visibleEpisodes[index];
                             final isSelected = ep.url == _currentEpisode?.url;
                             return GestureDetector(
                               onTap: () => _switchEpisode(ep),
                               child: Container(
                                 decoration: BoxDecoration(
                                   color: isSelected ? AppColors.primary : AppColors.cardBg,
                                   borderRadius: BorderRadius.circular(8),
                                   border: Border.all(
                                     color: isSelected ? AppColors.primary : Colors.white10,
                                   ),
                                 ),
                                 alignment: Alignment.center,
                                 child: Text(
                                   ep.number,
                                   style: GoogleFonts.inter(
                                     color: isSelected ? Colors.white : Colors.white70,
                                     fontSize: 14,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                             );
                           },
                           childCount: visibleEpisodes.length,
                         ),
                       ),
                     )
                   else
                     SliverList(
                       delegate: SliverChildBuilderDelegate(
                         (context, index) {
                            if (index >= visibleEpisodes.length) return null;
                            final ep = visibleEpisodes[index];
                            final isSelected = ep.url == _currentEpisode?.url;
                            return _buildPortraitEpisodeItem(ep, isSelected);
                         },
                         childCount: visibleEpisodes.length,
                       ),
                     ),
                     
                    // Pagination
                    _buildPagination(totalPages),
                    
                    // Bottom Padding
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Center(
          child: Video(
            controller: _mediaKitVideoController!,
            controls: NoVideoControls,
          ),
        ),
        if (_isPlayerInitialized) _buildPlayerControls(),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Stack(
      children: [
        // Subtitle Overlay (Now inside player area)
        if (_isPlayerInitialized && _currentSubtitle.isNotEmpty)
          VideoPlayerSubtitleOverlay(
            subtitleText: _currentSubtitle,
            fontSize: _subtitleFontSize,
            textColor: _subtitleColor,
            backgroundOpacity: _subtitleBackgroundOpacity,
            bottomOffset: 20, // Relative to video area bottom
            isPip: _isPipActive,
          ),

        // Controls Overlay
        VideoPlayerControls(
          showControls: _showControls,
          isLocked: _isLocked,
          isFullScreen: _isFullScreen,
          isPlaying: _mediaKitPlayer?.state.playing ?? _videoController?.value.isPlaying ?? false,
          isBuffering: _mediaKitPlayer?.state.buffering ?? false,
          animeTitle: widget.animeTitle,
          currentEpisodeNumber: _currentEpisode?.episodeNumber ?? int.tryParse(_currentEpisode?.number ?? '1') ?? 1,
          currentPosition: _mediaKitPlayer?.state.position ?? _videoController?.value.position ?? Duration.zero,
          totalDuration: _mediaKitPlayer?.state.duration ?? _videoController?.value.duration ?? Duration.zero,
          hasPrevEpisode: hasPrevEpisode,
          hasNextEpisode: hasNextEpisode,
          onBack: () {
            if (_isFullScreen) {
              _resetOrientation();
              setState(() {
                _isFullScreen = false;
              });
            } else {
              // Set full player inactive BEFORE pop so mini player shows
              Provider.of<GlobalPlayerProvider>(context, listen: false).setFullPlayerActive(false);
              Navigator.pop(context);
            }
          },
          onSettings: _showSettingsModal,
          onToggleLock: () {
            setState(() {
              _isLocked = !_isLocked;
            });
            _startHideTimer();
          },
          onTogglePlay: _togglePlay,
          onSeekBackward: () => _seekRelative(-10),
          onSeekForward: () => _seekRelative(10),
          onPrevEpisode: () {
            final currentIndex = _localAllEpisodes.indexWhere((e) => e.url == _currentEpisode?.url);
            if (currentIndex > 0) {
              _switchEpisode(_localAllEpisodes[currentIndex - 1]);
            }
          },
          onNextEpisode: () {
            final currentIndex = _localAllEpisodes.indexWhere((e) => e.url == _currentEpisode?.url);
            if (currentIndex < _localAllEpisodes.length - 1) {
              _switchEpisode(_localAllEpisodes[currentIndex + 1]);
            }
          },
          onToggleFullScreen: () {
            setState(() {
              _isFullScreen = !_isFullScreen;
            });
            if (_isFullScreen) {
              _setLandscapeOrientation();
            } else {
              _resetOrientation();
            }
          },
          onSeek: _seekTo,
          onSeekStart: () {
            _hideControlsTimer?.cancel();
          },
          onToggleControls: _toggleControls,
          onTogglePip: _togglePip,
          allEpisodes: _localAllEpisodes,
          onEpisodeSelected: _switchEpisode,
          // Dropdown settings data
          availableQualities: _allAvailableQualities.map((q) => {
            'quality': q.quality ?? 'auto',
            'label': q.quality ?? 'auto',
          }).toList(),
          selectedQuality: _currentStreamLink?.quality ?? 'auto',
          availableSubtitles: _availableSubtitles,
          selectedSubtitle: _selectedSubtitleLang,
          selectedAILang: _selectedAILang,
          audioType: _audioType,
          onQualityChanged: (quality) {
            final selected = _allAvailableQualities.firstWhere(
              (q) => q.quality == quality,
              orElse: () => _allAvailableQualities.first,
            );
            setState(() => _currentStreamLink = selected);
            _initializePlayer();
          },
          onSubtitleChanged: (lang) {
            if (lang == 'Off') {
              setState(() {
                _subtitles = [];
                _currentSubtitle = '';
                _selectedSubtitleLang = 'Off';
                _selectedAILang = 'none';
              });
            } else {
              _loadSubtitle(lang);
            }
            _savePlayerSettings(); // Save preference
          },
          onAILangChanged: (lang) {
            setState(() {
              _selectedAILang = lang;
              if (lang != 'none' && _currentSubtitle.isNotEmpty) {
                _updateSubtitle(_mediaKitPlayer?.state.position ?? _videoController?.value.position ?? Duration.zero);
              }
            });
            _savePlayerSettings(); // Save preference
          },
          onAudioTypeChanged: (type) {
            setState(() {
              _audioType = type;
            });
            _loadEpisodeAndPlay();
          },
          subtitleSize: _subtitleFontSize,
          subtitleOffset: _subtitleOffset,
          subtitleOpacity: _subtitleBackgroundOpacity,
          subtitleColor: '#${_subtitleColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          onSubtitleSizeChanged: (size) {
            setState(() => _subtitleFontSize = size);
            _savePlayerSettings();
          },
          onSubtitleOffsetChanged: (offset) {
            setState(() => _subtitleOffset = offset);
            _savePlayerSettings();
          },
          onSubtitleOpacityChanged: (opacity) {
            setState(() => _subtitleBackgroundOpacity = opacity);
            _savePlayerSettings();
          },
          onSubtitleColorChanged: (colorStr) {
            setState(() {
              if (colorStr == 'white') {
                _subtitleColor = Colors.white;
              } else {
                _subtitleColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
              }
            });
            _savePlayerSettings();
          },
          onOpenStyleSettings: () {
            // No longer used as it's integrated into the settings overlay
          },
          playbackSpeed: _playbackSpeed,
          onPlaybackSpeedChanged: (speed) {
            setState(() {
              _playbackSpeed = speed;
            });
            _mediaKitPlayer?.setRate(speed);
            _videoController?.setPlaybackSpeed(speed);
          },
          isAutoPlayEnabled: _isAutoPlayEnabled,
          onAutoPlayChanged: (enabled) {
            setState(() {
              _isAutoPlayEnabled = enabled;
            });
          },
        ),

        // Next Episode Countdown
        if (_showNextEpisodeCountdown)
          VideoPlayerNextEpisodeOverlay(
            countdown: _nextEpisodeCountdown,
            onCancel: () {
              _nextEpisodeTimer?.cancel();
              setState(() {
                _showNextEpisodeCountdown = false;
              });
            },
            onPlayNow: _playNextEpisode,
          ),

        // Brightness / Volume Indicators
        if (_showBrightnessIndicator)
          _buildIndicator(Icons.brightness_7, _currentBrightness),
        if (_showVolumeIndicator)
          _buildIndicator(_currentVolume > 0 ? Icons.volume_up : Icons.volume_off, _currentVolume),
      ],
    );
  }

  Widget _buildPortraitEpisodeItem(Episode ep, bool isSelected) {
    return GestureDetector(
      onTap: () => _switchEpisode(ep),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                ep.number,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                ep.title ?? 'Episode ${ep.number}',
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 20)
            else
              const Icon(Icons.play_circle_outline, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => VideoPlayerSettingsModal(
        availableQualities: _allAvailableQualities.map((q) => {
          'quality': q.quality ?? 'auto',
          'label': q.quality ?? 'auto',
        }).toList(),
        selectedQuality: _currentStreamLink?.quality ?? 'auto',
        availableSubtitles: _availableSubtitles,
        selectedSubtitle: _selectedSubtitleLang,
        selectedAILang: _selectedAILang,
        audioType: _audioType,
        subtitleSize: _subtitleFontSize,
        subtitleColor: _subtitleColor,
        subtitleOpacity: _subtitleBackgroundOpacity,
        subtitleOffset: _subtitleOffset,
        
        // New Features
        playbackSpeed: _playbackSpeed,
        isAutoPlayEnabled: _isAutoPlayEnabled,
        
        onQualitySelected: (quality) {
          final selected = _allAvailableQualities.firstWhere(
            (q) => q.quality == quality,
            orElse: () => _allAvailableQualities.first,
          );
          setState(() {
            _currentStreamLink = selected;
          });
          Navigator.pop(context);
          _initializePlayer();
        },
        onSubtitleSelected: (lang) {
          Navigator.pop(context);
          if (lang == 'Off') {
            setState(() {
              _subtitles = [];
              _currentSubtitle = '';
              _selectedSubtitleLang = 'Off';
              _selectedAILang = 'none';
            });
          } else {
            _loadSubtitle(lang);
          }
        },
        onAILangChanged: (lang) {
          setState(() {
            _selectedAILang = lang;
            if (lang != 'none' && _currentSubtitle.isNotEmpty) {
               _updateSubtitle(_mediaKitPlayer?.state.position ?? _videoController?.value.position ?? Duration.zero);
            }
          });
          Navigator.pop(context);
        },
        onAudioTypeChanged: (type) {
          setState(() {
            _audioType = type;
          });
          Navigator.pop(context);
          _loadEpisodeAndPlay();
        },
        onSubtitleSizeChanged: (size) {
          setState(() {
            _subtitleFontSize = size;
          });
          _savePlayerSettings();
        },
        onSubtitleColorChanged: (color) {
          setState(() {
            _subtitleColor = color;
          });
          _savePlayerSettings();
        },
        onSubtitleOpacityChanged: (opacity) {
          setState(() {
            _subtitleBackgroundOpacity = opacity;
          });
          _savePlayerSettings();
        },
        onSubtitleOffsetChanged: (offset) {
          setState(() {
            _subtitleOffset = offset;
          });
          _savePlayerSettings();
        },
        
        // New Feature Callbacks
        onPlaybackSpeedChanged: (speed) {
          setState(() {
            _playbackSpeed = speed;
          });
          _mediaKitPlayer?.setRate(speed);
          _videoController?.setPlaybackSpeed(speed);
          Navigator.pop(context);
        },
        onAutoPlayChanged: (enabled) {
          setState(() {
            _isAutoPlayEnabled = enabled;
          });
          // No need to close modal for toggle
        },
        
        onClose: () {
          Navigator.pop(context);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _showControls = true;
        });
        _startHideTimer();
      }
    });
  }
}
