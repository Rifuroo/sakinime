// widgets/video_player_subtitle_overlay.dart - Subtitle display matching React Native
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoPlayerSubtitleOverlay extends StatelessWidget {
  final String subtitleText;
  final double fontSize;
  final Color textColor;
  final double backgroundOpacity;
  final double bottomOffset;
  final bool isPip;

  const VideoPlayerSubtitleOverlay({
    super.key,
    required this.subtitleText,
    this.fontSize = 18.0,
    this.textColor = Colors.white,
    this.backgroundOpacity = 0.5,
    this.bottomOffset = 20.0,
    this.isPip = false,
  });

  double _calculateFontSize(String text) {
    // Smart subtitle sizing based on text length (matching React Native logic)
    var baseSize = fontSize;
    if (isPip) baseSize = baseSize * 0.5; // Scale down for PiP
    
    final length = text.length;
    
    if (length > 100) return baseSize * 0.7;
    if (length > 60) return baseSize * 0.85;
    return baseSize;
  }

  @override
  Widget build(BuildContext context) {
    if (subtitleText.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 10,
      right: 10,
      bottom: isPip ? 10 : bottomOffset,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isPip ? 8 : 15,
            vertical: isPip ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: backgroundOpacity),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            subtitleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: _calculateFontSize(subtitleText),
              fontWeight: FontWeight.w700,
              height: 1.4,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  offset: Offset(isPip ? 0.5 : 1, isPip ? 0.5 : 1),
                  blurRadius: isPip ? 1.5 : 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
