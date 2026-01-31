import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class VideoPlayerSeekingOverlay extends StatelessWidget {
  final Duration duration;
  final bool isForward;
  final VoidCallback? onAnimationEnd;

  const VideoPlayerSeekingOverlay({
    super.key,
    required this.duration,
    required this.isForward,
    this.onAnimationEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4), // 40% dim background
        child: Row(
          children: [
            // Left Side (Backward)
            Expanded(
              child: !isForward
                  ? FadeIn(
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.keyboard_double_arrow_left_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                            Text(
                              '${duration.inSeconds}s',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),

            // Right Side (Forward)
            Expanded(
              child: isForward
                  ? FadeIn(
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.keyboard_double_arrow_right_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                            Text(
                              '${duration.inSeconds}s',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
