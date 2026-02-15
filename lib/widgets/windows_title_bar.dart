import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:google_fonts/google_fonts.dart';

class WindowsTitleBar extends StatelessWidget {
  const WindowsTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: const Color(0xFF1a1f3a), // Match app bar or sidebar
      child: Row(
        children: [
          // Drag Handle
          Expanded(child: MoveWindow(
            child: Row(
              children: [
                const SizedBox(width: 12),
                // Optional Icon
                Image.asset('assets/icon.png', width: 16, height: 16),
                const SizedBox(width: 8),
                Text(
                  'Sukinime', 
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          )),
          
          // Window Controls
          const WindowButtons(),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = WindowButtonColors(
      iconNormal: const Color(0xFFC0C0C5),
      mouseOver: const Color(0xFF333742),
      mouseDown: const Color(0xFF222630),
      iconMouseOver: const Color(0xFFFFFFFF),
      iconMouseDown: const Color(0xFFF0F0F0),
    );

    final closeColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: const Color(0xFFC0C0C5),
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: colors),
        MaximizeWindowButton(colors: colors),
        CloseWindowButton(colors: closeColors),
      ],
    );
  }
}
