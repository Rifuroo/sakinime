// widgets/video_player_settings_modal.dart - Settings modal matching React Native
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class VideoPlayerSettingsModal extends StatelessWidget {
  final List<Map<String, dynamic>> availableQualities;
  final String selectedQuality;
  final List<Map<String, String>> availableSubtitles;
  final String selectedSubtitle;
  final String selectedAILang;
  final String audioType; // 'sub' or 'dub'
  final double subtitleSize;
  final Color subtitleColor;
  final double subtitleOpacity;
  final double subtitleOffset;
  final double playbackSpeed;
  final bool isAutoPlayEnabled;
  final Function(String) onQualitySelected;
  final Function(String) onSubtitleSelected;
  final Function(String) onAILangChanged;
  final Function(String) onAudioTypeChanged;
  final Function(double) onSubtitleSizeChanged;
  final Function(Color) onSubtitleColorChanged;
  final Function(double) onSubtitleOpacityChanged;
  final Function(double) onSubtitleOffsetChanged;
  final Function(double) onPlaybackSpeedChanged;
  final Function(bool) onAutoPlayChanged;
  final VoidCallback onClose;

  const VideoPlayerSettingsModal({
    super.key,
    required this.availableQualities,
    required this.selectedQuality,
    required this.availableSubtitles,
    required this.selectedSubtitle,
    required this.selectedAILang,
    required this.audioType,
    required this.subtitleSize,
    required this.subtitleColor,
    required this.subtitleOpacity,
    required this.subtitleOffset,
    required this.playbackSpeed,
    required this.isAutoPlayEnabled,
    required this.onQualitySelected,
    required this.onSubtitleSelected,
    required this.onAILangChanged,
    required this.onAudioTypeChanged,
    required this.onSubtitleSizeChanged,
    required this.onSubtitleColorChanged,
    required this.onSubtitleOpacityChanged,
    required this.onSubtitleOffsetChanged,
    required this.onPlaybackSpeedChanged,
    required this.onAutoPlayChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping modal content
            child: GestureDetector(
               onVerticalDragUpdate: (details) {}, // Block vertical drags from passing through
               onHorizontalDragUpdate: (details) {}, // Block horizontal drags
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).orientation == Orientation.portrait 
                      ? MediaQuery.of(context).size.height * 0.5 // Increased height for new settings
                      : MediaQuery.of(context).size.height * 0.9, 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Auto Play Section
                            _buildAutoPlaySwitch(),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 10),

                            // Playback Speed Section
                            _buildSectionTitle('Playback Speed'),
                            const SizedBox(height: 10),
                            _buildPlaybackSpeedGrid(),

                            const SizedBox(height: 20),

                            // Video Quality Section
                            _buildSectionTitle('Video Quality'),
                            const SizedBox(height: 10),
                            _buildQualityGrid(),
                            
                            const SizedBox(height: 20),
                            
                            // Audio Type Section
                            _buildSectionTitle('Audio Type'),
                            const SizedBox(height: 10),
                            _buildAudioTypeGrid(),
                            
                            const SizedBox(height: 20),

                            // AI Translation Section (Matching Expo)
                            _buildSectionTitle('AI Translation'),
                            const SizedBox(height: 10),
                            _buildAITranslationGrid(),

                            const SizedBox(height: 20),
                            
                            // Subtitle Section
                            _buildSectionTitle('Subtitle'),
                            const SizedBox(height: 10),
                            _buildSubtitleGrid(),
                            
                            const SizedBox(height: 20),
                            
                            // Subtitle Styling (Size, Opacity, Color)
                            _buildSubtitleStyling(context),
                            
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildAutoPlaySwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Auto Play Next Episode',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Switch(
          value: isAutoPlayEnabled,
          onChanged: onAutoPlayChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildPlaybackSpeedGrid() {
    final speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: speeds.map((speed) {
        final isSelected = speed == playbackSpeed;
        return GestureDetector(
          onTap: () => onPlaybackSpeedChanged(speed),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${speed}x',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAITranslationGrid() {
     // Languages matching translationService.js
     final languages = {
       'none': 'None',
       'id': 'Indonesian',
       'en': 'English',
       'vi': 'Vietnamese',
       'th': 'Thai',
     };

     return Wrap(
       spacing: 8,
       runSpacing: 8,
       children: languages.entries.map((entry) {
         final isSelected = entry.key == selectedAILang;
         return GestureDetector(
            onTap: () => onAILangChanged(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
         );
       }).toList(),
     );
  }

  Widget _buildQualityGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableQualities.map((quality) {
        final label = quality['quality']?.toString() ?? quality['label']?.toString() ?? 'Auto';
        final isSelected = label == selectedQuality;
        
        return GestureDetector(
          onTap: () => onQualitySelected(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (quality['size'] != null)
                  Text(
                    quality['size'].toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAudioTypeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildAudioTypeButton('Sub', 'sub'),
        _buildAudioTypeButton('Dub', 'dub'),
      ],
    );
  }

  Widget _buildAudioTypeButton(String label, String value) {
    final isSelected = audioType == value;
    return GestureDetector(
      onTap: () => onAudioTypeChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleGrid() {
    final subtitles = [
      {'lang': 'Off', 'label': 'Off'},
      ...availableSubtitles,
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subtitles.map((subtitle) {
        final label = subtitle['label'] ?? subtitle['lang'] ?? 'Unknown';
        final isSelected = label == selectedSubtitle;
        
        return GestureDetector(
          onTap: () => onSubtitleSelected(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubtitleStyling(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Size Slider
        _buildStyleLabel('Size: ${subtitleSize.toInt()}'),
        Slider(
          value: subtitleSize,
          min: 12,
          max: 30, // MATCH EXPO
          divisions: 18,
          activeColor: AppColors.primary,
          inactiveColor: Colors.white.withValues(alpha: 0.2),
          onChanged: onSubtitleSizeChanged,
        ),
        
        const SizedBox(height: 10),
        
        // Opacity Slider
        _buildStyleLabel('Opacity: ${(subtitleOpacity * 100).toInt()}%'),
        Slider(
          value: subtitleOpacity,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          activeColor: AppColors.primary,
          inactiveColor: Colors.white.withValues(alpha: 0.2),
          onChanged: onSubtitleOpacityChanged,
        ),
        
        const SizedBox(height: 10),
        
        // Offset Slider
        _buildStyleLabel('Position: ${subtitleOffset.toInt()}'),
        Slider(
          value: subtitleOffset,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppColors.primary,
          inactiveColor: Colors.white.withValues(alpha: 0.2),
          onChanged: onSubtitleOffsetChanged,
        ),
        
        const SizedBox(height: 15),
        
        // Color Picker
        _buildStyleLabel('Color'),
        const SizedBox(height: 10),
        _buildColorPicker(),
      ],
    );
  }

  Widget _buildStyleLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 13,
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Colors.white,
      Colors.yellow,
      Colors.cyan,
      Colors.green,
      const Color(0xFFFF00FF), // Magenta/Pink (#FF00FF)
      const Color(0xFFFFA500), // Orange (#FFA500)
    ];
    
    return Row(
      children: colors.map((color) {
        final isSelected = subtitleColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onSubtitleColorChanged(color),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
