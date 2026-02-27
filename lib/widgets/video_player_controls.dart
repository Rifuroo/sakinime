// widgets/video_player_controls.dart - Video player controls matching React Native PlayerScreen
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/anime_model.dart';

class VideoPlayerControls extends StatefulWidget {
  final bool showControls;
  final bool isLocked;
  final bool isFullScreen;
  final bool isPlaying;
  final bool isBuffering;
  final String animeTitle;
  final int currentEpisodeNumber;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool hasPrevEpisode;
  final bool hasNextEpisode;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onToggleLock;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onPrevEpisode;
  final VoidCallback onNextEpisode;
  final VoidCallback onToggleFullScreen;
  final List<Episode> allEpisodes;
  final Function(Episode) onEpisodeSelected;
  final Function(double) onSeek;
  final VoidCallback onSeekStart;
  final VoidCallback onToggleControls;
  final VoidCallback onTogglePip;
  final List<Map<String, String>> availableQualities;
  final String selectedQuality;
  final List<Map<String, String>> availableSubtitles;
  final String selectedSubtitle;
  final String selectedAILang;
  final String audioType;
  final Function(String) onQualityChanged;
  final Function(String) onSubtitleChanged;
  final Function(String) onAILangChanged;
  final Function(String) onAudioTypeChanged;
  final double subtitleSize;
  final double subtitleOffset;
  final double subtitleOpacity;
  final String subtitleColor;
  final Function(double) onSubtitleSizeChanged;
  final Function(double) onSubtitleOffsetChanged;
  final Function(double) onSubtitleOpacityChanged;
  final Function(String) onSubtitleColorChanged;
  final double playbackSpeed;
  final Function(double) onPlaybackSpeedChanged;
  final bool isAutoPlayEnabled;
  final Function(bool) onAutoPlayChanged;
  final VoidCallback onOpenStyleSettings;

  const VideoPlayerControls({
    super.key,
    required this.showControls,
    required this.isLocked,
    required this.isFullScreen,
    required this.isPlaying,
    required this.isBuffering,
    required this.animeTitle,
    required this.currentEpisodeNumber,
    required this.currentPosition,
    required this.totalDuration,
    required this.hasPrevEpisode,
    required this.hasNextEpisode,
    required this.onBack,
    required this.onSettings,
    required this.onToggleLock,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onPrevEpisode,
    required this.onNextEpisode,
    required this.onToggleFullScreen,
    required this.allEpisodes,
    required this.onEpisodeSelected,
    required this.onSeek,
    required this.onSeekStart,
    required this.onToggleControls,
    required this.onTogglePip,
    required this.availableQualities,
    required this.selectedQuality,
    required this.availableSubtitles,
    required this.selectedSubtitle,
    required this.selectedAILang,
    required this.audioType,
    required this.onQualityChanged,
    required this.onSubtitleChanged,
    required this.onAILangChanged,
    required this.onAudioTypeChanged,
    required this.subtitleSize,
    required this.subtitleOffset,
    required this.subtitleOpacity,
    required this.subtitleColor,
    required this.onSubtitleSizeChanged,
    required this.onSubtitleOffsetChanged,
    required this.onSubtitleOpacityChanged,
    required this.onSubtitleColorChanged,
    required this.onOpenStyleSettings,
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
    required this.isAutoPlayEnabled,
    required this.onAutoPlayChanged,
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _showSettings = false;

  void _openSettings() {
    if (kDebugMode) {
      print(
          '🛠️ [CONTROLS] Opening Settings. isPortrait: ${MediaQuery.of(context).orientation == Orientation.portrait}');
      print('🛠️ [CONTROLS] Qualities: ${widget.availableQualities.length}');
      print('🛠️ [CONTROLS] Current Quality: ${widget.selectedQuality}');
    }

    if (widget.showControls) {
      widget.onToggleControls();
    }

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Settings',
        barrierColor: Colors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return _buildPortraitSettings(context);
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      );
    } else {
      setState(() => _showSettings = true);
    }
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return Stack(
      children: [
        // Dark Overlay Backdrop (YouTube style) - ONLY when not locked
        IgnorePointer(
          ignoring: !widget.showControls,
          child: AnimatedOpacity(
            opacity: widget.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ),

        // Settings Overlay
        if (_showSettings &&
            MediaQuery.of(context).orientation != Orientation.portrait)
          _buildSettingsOverlay(context),

        IgnorePointer(
          ignoring: !widget.showControls,
          child: AnimatedOpacity(
            opacity: widget.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              children: [
                // Invisible tap area
                if (widget.isLocked)
                  GestureDetector(
                    onTap: widget.onToggleControls,
                    child: Container(color: Colors.transparent),
                  ),

                // Top Bar
                if (!widget.isLocked)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                          stops: [0.0, 1.0],
                        ),
                      ),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top +
                            (isPortrait ? 4 : 8),
                        bottom: isPortrait ? 10 : 20,
                        left: isPortrait ? 8 : 16,
                        right: isPortrait ? 8 : 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: isPortrait ? 24 : 28),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.animeTitle,
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: isPortrait ? 12 : 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Episode ${widget.currentEpisodeNumber}',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white70,
                                    fontSize: isPortrait ? 10 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onTogglePip,
                            icon: Icon(Icons.picture_in_picture_alt_rounded,
                                color: Colors.white,
                                size: isPortrait ? 18 : 22),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _openSettings,
                            icon: Icon(Icons.settings_outlined,
                                color: Colors.white,
                                size: isPortrait ? 18 : 22),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Center Controls
                if (!widget.isLocked)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Seek Backward
                        IconButton(
                          onPressed: widget.onSeekBackward,
                          icon: const Icon(Icons.replay_10_rounded,
                              color: Colors.white, size: 24), // Smaller
                          padding: const EdgeInsets.all(8),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              highlightColor: Colors.white10),
                        ),
                        const SizedBox(width: 32), // Reduced spacing

                        // Play/Pause (Big Center Button)
                        GestureDetector(
                          onTap: widget.onTogglePlay,
                          child: Container(
                            width: 56, // Reduced from 64
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32, // Reduced from 40
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),
                        // Seek Forward
                        IconButton(
                          onPressed: widget.onSeekForward,
                          icon: const Icon(Icons.forward_10_rounded,
                              color: Colors.white, size: 24), // Smaller
                          padding: const EdgeInsets.all(8),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              highlightColor: Colors.white10),
                        ),
                      ],
                    ),
                  ),

                // Lock Button (Fullscreen only)
                if (widget.isFullScreen)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: IconButton(
                        onPressed: widget.onToggleLock,
                        icon: Icon(
                            widget.isLocked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: Colors.white,
                            size: 28),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: const EdgeInsets.all(12)),
                      ),
                    ),
                  ),

                // Bottom Bar
                if (!widget.isLocked)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.0, 1.0],
                        ),
                      ),
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: MediaQuery.of(context).padding.bottom +
                            (isPortrait ? 4 : 8),
                        top: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Time Display
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${_formatTime(widget.currentPosition)} / ${_formatTime(widget.totalDuration)}',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white70,
                                  fontSize: isPortrait ? 10 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          // Row 2: Slider & Fullscreen
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 24,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 1.5,
                                      thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius:
                                              isPortrait ? 4 : 5),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 10),
                                      activeTrackColor: const Color(0xFFFF0000),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFFF0000),
                                      overlayColor: const Color(0xFFFF0000)
                                          .withValues(alpha: 0.2),
                                      trackShape:
                                          const RoundedRectSliderTrackShape(),
                                    ),
                                    child: Slider(
                                      value:
                                          widget.totalDuration.inMilliseconds >
                                                  0
                                              ? widget.currentPosition
                                                  .inMilliseconds
                                                  .toDouble()
                                                  .clamp(
                                                      0,
                                                      widget.totalDuration
                                                          .inMilliseconds
                                                          .toDouble())
                                              : 0,
                                      min: 0,
                                      max: widget.totalDuration.inMilliseconds
                                          .toDouble(),
                                      onChangeStart: (_) =>
                                          widget.onSeekStart(),
                                      onChanged: (value) =>
                                          widget.onSeek(value),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: widget.onToggleFullScreen,
                                icon: Icon(
                                    widget.isFullScreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: isPortrait ? 20 : 24),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          // Row 3: Episode Controls (Landscape Only)
                          if (!isPortrait)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          onPressed: widget.hasPrevEpisode
                                              ? widget.onPrevEpisode
                                              : null,
                                          icon: Icon(
                                              Icons.skip_previous_rounded,
                                              color: widget.hasPrevEpisode
                                                  ? Colors.white
                                                  : Colors.white24,
                                              size: 22),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          onPressed: widget.hasNextEpisode
                                              ? widget.onNextEpisode
                                              : null,
                                          icon: Icon(Icons.skip_next_rounded,
                                              color: widget.hasNextEpisode
                                                  ? Colors.white
                                                  : Colors.white24,
                                              size: 22),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                      width: 24), // Match FS button width
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Buffering Indicator
        if (widget.isBuffering)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF0000),
              strokeWidth: 4,
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsOverlay(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return _buildPortraitSettings(context);
    }

    final panelWidth = MediaQuery.of(context).size.width * 0.4;
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _showSettings = false),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),
        // Settings Panel (Landscape)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: panelWidth,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            child: _buildSettingsContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitSettings(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (_showSettings) {
                setState(() => _showSettings = false);
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        // Glassmorphic Modal
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212).withValues(alpha: 0.85),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      // Drag Handle
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(child: _buildSettingsContent(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Player Settings',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_showSettings) {
                    setState(() => _showSettings = false);
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('PLAYBACK SPEED'),
                _buildGrid(
                  items: const ['0.5', '1.0', '1.25', '1.5', '2.0'],
                  current: widget.playbackSpeed.toString(),
                  onSelected: (v) =>
                      widget.onPlaybackSpeedChanged(double.parse(v)),
                  itemLabel: (item) => '${item}x',
                ),
                const SizedBox(height: 8),
                _buildAutoPlaySwitch(),
                _buildSectionTitle('VIDEO QUALITY'),
                if (kDebugMode && widget.availableQualities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text('No qualities available',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                _buildGrid(
                  items: widget.availableQualities.isNotEmpty
                      ? widget.availableQualities
                          .map((q) => q['label']!)
                          .toList()
                      : ['auto'],
                  current: widget.selectedQuality,
                  onSelected: widget.onQualityChanged,
                ),
                _buildSectionTitle('AUDIO CONTENT'),
                _buildGrid(
                  items: const ['sub', 'dub'],
                  current: widget.audioType,
                  onSelected: widget.onAudioTypeChanged,
                  itemLabel: (item) => item == 'sub' ? 'SUBTITLED' : 'DUBBED',
                ),
                _buildSectionTitle('SUBTITLE LANGUAGE'),
                _buildGrid(
                  items: [
                    'Off',
                    ...widget.availableSubtitles.map((s) => s['label']!)
                  ],
                  current: widget.selectedSubtitle,
                  onSelected: widget.onSubtitleChanged,
                ),
                _buildSectionTitle('AI REAL-TIME TRANSLATION'),
                _buildGrid(
                  items: const ['none', 'id', 'en'],
                  current: widget.selectedAILang,
                  onSelected: widget.onAILangChanged,
                  itemLabel: (item) => item == 'none'
                      ? 'OFF'
                      : item == 'id'
                          ? 'INDONESIAN'
                          : 'ENGLISH',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Text(
                  'APPEARANCE & STYLE',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStyleSlider(
                  label: 'Text Size',
                  value: widget.subtitleSize,
                  min: 12,
                  max: 30,
                  onChanged: widget.onSubtitleSizeChanged,
                  displayValue: '${widget.subtitleSize.toInt()}px',
                ),
                _buildStyleSlider(
                  label: 'Vertical Offset',
                  value: widget.subtitleOffset,
                  min: 0,
                  max: 150,
                  onChanged: widget.onSubtitleOffsetChanged,
                  displayValue: '${widget.subtitleOffset.toInt()}',
                ),
                _buildStyleSlider(
                  label: 'Background Opacity',
                  value: widget.subtitleOpacity,
                  min: 0,
                  max: 1,
                  onChanged: widget.onSubtitleOpacityChanged,
                  displayValue: '${(widget.subtitleOpacity * 100).toInt()}%',
                ),
                _buildSectionTitle('SUBTITLE COLOR'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      'white',
                      '#FFFF00',
                      '#00FFFF',
                      '#00FF00',
                      '#FF00FF',
                      '#FFA500'
                    ].map((colorStr) {
                      final color = _parseColor(colorStr);
                      final isSelected = widget.subtitleColor == colorStr;
                      return GestureDetector(
                        onTap: () => widget.onSubtitleColorChanged(colorStr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 10)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 20, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                displayValue,
                style: GoogleFonts.robotoMono(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGrid({
    required List<String> items,
    required String current,
    required Function(String) onSelected,
    String Function(String)? itemLabel,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = item == current;
        return InkWell(
          onTap: () {
            onSelected(item);
            if (items.length < 5) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                setState(() => _showSettings = false);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            constraints: const BoxConstraints(minWidth: 80),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Text(
              itemLabel != null ? itemLabel(item) : item,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String colorStr) {
    if (colorStr == 'white') return Colors.white;
    return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
  }

  Widget _buildAutoPlaySwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto Play',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('Next episode automatically',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          Switch(
            value: widget.isAutoPlayEnabled,
            onChanged: widget.onAutoPlayChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
