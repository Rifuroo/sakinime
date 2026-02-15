import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:smtc_windows/smtc_windows.dart';
import '../models/anime_model.dart';
import '../utils/platform_utils.dart';
import '../services/translation_service.dart';

class GlobalPlayerProvider extends ChangeNotifier {
  // Media Kit Player
  late final Player player;
  late final VideoController controller;

  // SMTC (Windows only)
  SMTCWindows? _smtc;
  StreamSubscription<PressedButton>? _smtcSubscription;

  // State
  bool isInitialized = false;
  bool isPlaying = false;
  bool isBuffering = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  bool isFullPlayerActive = false;

  // Subtitles
  List<dynamic> subtitles =
      []; // Using dynamic to avoid import complexity if not needed
  String currentSubtitle = '';
  String selectedSubtitleLang = 'Off';
  String selectedAILang = 'none';
  bool isTranslating = false;

  // Content Logic
  String? currentAnimeId;
  String? currentAnimeTitle;
  String? currentAnimePoster;
  Episode? currentEpisode;
  List<Episode> playlist = [];

  GlobalPlayerProvider() {
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    player = Player();
    controller = VideoController(player);

    // Listen to streams
    player.stream.playing.listen((val) {
      if (isPlaying != val) {
        isPlaying = val;
        notifyListeners();
      }
    });

    player.stream.buffering.listen((val) {
      if (isBuffering != val) {
        isBuffering = val;
        notifyListeners();
      }
    });

    player.stream.position.listen((val) {
      // Only notify if position changes by a significant amount or for subtitle updates
      // However,SMTC needs frequent updates. Let's keep position data but notify sparingly.
      currentPosition = val;
      _updateSubtitle(val);

      // Update SMTC but don't notify all UI listeners just for position
      _updateSMTCTimeline();
    });

    player.stream.duration.listen((val) {
      totalDuration = val;
      _updateSMTCTimeline();
      notifyListeners();
    });

    player.stream.completed.listen((val) {
      if (val) {
        // Auto-next logic could go here
        _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
      }
    });

    // Initialize SMTC for Windows
    if (PlatformUtils.isWindows) {
      // Delay initialization to avoid race conditions with Window creation/Hot Restart
      Future.delayed(const Duration(seconds: 2), () {
        _initializeSMTC();
      });
    }

    isInitialized = true;
    notifyListeners();
  }

  // ================= SMTC LOGIC =================

  void _initializeSMTC() {
    try {
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(
          title: 'Sukinime',
          album: 'Anime Streaming',
          albumArtist: 'Sukinime',
          artist: 'Sukinime',
          thumbnail: null,
        ),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 0,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 0,
        ),
        config: const SMTCConfig(
          fastForwardEnabled: false,
          rewindEnabled: false,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
        ),
      );

      // Listen to button events
      _smtcSubscription = _smtc!.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play:
            player.play();
            break;
          case PressedButton.pause:
            player.pause();
            break;
          case PressedButton.next:
            // TODO: Implement next episode
            break;
          case PressedButton.previous:
            // TODO: Implement previous episode
            break;
          case PressedButton.stop:
            player.pause();
            _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
            break;
          default:
            break;
        }
      });

      debugPrint('SMTC initialized successfully');

      // Ensure controls are active by enforcing state
      if (isPlaying) {
        _smtc?.setPlaybackStatus(PlaybackStatus.playing);
      } else {
        _smtc?.setPlaybackStatus(PlaybackStatus.paused);
      }
    } catch (e) {
      debugPrint('Failed to init SMTC: $e');
    }
  }

  Future<void> updateMetadata(
      {Episode? episode,
      String? title,
      String? poster,
      String? animeId}) async {
    if (episode != null) currentEpisode = episode;
    if (title != null) currentAnimeTitle = title;
    if (poster != null) currentAnimePoster = poster;
    if (animeId != null) currentAnimeId = animeId;

    if (_smtc == null || currentEpisode == null) return;
    try {
      final metaTitle =
          currentEpisode!.title ?? 'Episode ${currentEpisode!.number}';
      final metaArtist = currentAnimeTitle ?? 'Sukinime';
      final thumb =
          (currentAnimePoster?.isNotEmpty == true) ? currentAnimePoster : null;

      await _smtc!
          .updateMetadata(MusicMetadata(
        title: metaTitle,
        album: metaArtist,
        albumArtist: metaArtist,
        artist: metaArtist,
        thumbnail: thumb,
      ))
          .catchError((e) {
        debugPrint('SMTC metadata update error: $e');
      });
    } catch (e) {
      debugPrint('SMTC metadata update error: $e');
    }
  }

  void _updateSMTCMetadata() {
    updateMetadata();
  }

  void _updateSMTCTimeline() {
    if (_smtc == null || totalDuration.inMilliseconds == 0) return;
    try {
      _smtc!
          .updateTimeline(PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: totalDuration.inMilliseconds,
        positionMs: currentPosition.inMilliseconds,
        minSeekTimeMs: 0,
        maxSeekTimeMs: totalDuration.inMilliseconds,
      ))
          .catchError((e) {
        // Silently ignore timeline errors
      });
    } catch (e) {
      // Silently ignore
    }
  }

  // ================= CONTROL METHODS =================

  Future<void> loadAndPlay(String url,
      {required Episode episode,
      required String animeTitle,
      String? poster}) async {
    currentEpisode = episode;
    currentAnimeTitle = animeTitle;
    currentAnimePoster = poster;

    await player.open(Media(url));
    await player.play();

    _updateSMTCMetadata();
    notifyListeners();
  }

  Future<void> play() async {
    // Basic check if player is valid
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  void setFullPlayerActive(bool active) {
    if (isFullPlayerActive != active) {
      isFullPlayerActive = active;
      notifyListeners();
    }
  }

  void setSubtitles(List<dynamic> subs, String lang) {
    subtitles = subs;
    selectedSubtitleLang = lang;
    currentSubtitle = '';
    notifyListeners();
  }

  void setAISettings(String lang) {
    selectedAILang = lang;
    notifyListeners();
  }

  void _updateSubtitle(Duration position) {
    if (subtitles.isEmpty) return;

    String newSubtitle = '';
    for (var sub in subtitles) {
      if (position >= sub.start && position <= sub.end) {
        newSubtitle = sub.text;
        break;
      }
    }

    if (newSubtitle != currentSubtitle) {
      if (selectedAILang != 'none' && newSubtitle.isNotEmpty) {
        _translateCurrentSubtitle(newSubtitle);
      } else {
        currentSubtitle = newSubtitle;
        notifyListeners();
      }
    }
  }

  Future<void> _translateCurrentSubtitle(String text) async {
    if (selectedAILang == 'none' || text.isEmpty) return;

    isTranslating = true;
    notifyListeners();

    try {
      final translated =
          await TranslationService.translateText(text, selectedAILang);
      currentSubtitle = translated;
    } catch (e) {
      debugPrint('Global translation error: $e');
    } finally {
      isTranslating = false;
      notifyListeners();
    }
  }

  void updateCurrentSubtitleManual(String text) {
    currentSubtitle = text;
    notifyListeners();
  }

  void clearCurrentEpisode() {
    currentEpisode = null;
    currentAnimeTitle = null;
    currentAnimePoster = null;
    subtitles = [];
    currentSubtitle = '';
    player.stop();
    _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    _smtcSubscription?.cancel();
    _smtc?.dispose();
    super.dispose();
  }
}
