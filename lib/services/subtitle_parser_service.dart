// services/subtitle_parser_service.dart - Parallel VTT/SRT parser
import 'package:flutter/foundation.dart';

// Simple Subtitle model matching JS structure
class ParsedSubtitle {
  final Duration start;
  final Duration end;
  final String text;

  ParsedSubtitle({
    required this.start,
    required this.end,
    required this.text,
  });
}

class SubtitleParserService {
  // Async parallel parsing using isolate
  static Future<List<ParsedSubtitle>> parseSubtitlesAsync(String content) async {
    if (content.trim().isEmpty) return [];
    
    try {
      // Run parsing in separate isolate for better performance
      return await compute(_parseSubtitlesInIsolate, content);
    } catch (e) {
      debugPrint('Subtitle parsing error: $e');
      return [];
    }
  }

  // Isolate-safe parsing function
  static List<ParsedSubtitle> _parseSubtitlesInIsolate(String content) {
    if (content.contains('WEBVTT') || content.contains('-->')) {
      return _parseVTT(content);
    } else {
      return _parseSRT(content);
    }
  }

  // Synchronous fallback (for backwards compatibility)
  static List<ParsedSubtitle> parseSubtitles(String content) {
    if (content.trim().isEmpty) return [];

    try {
      if (content.contains('WEBVTT') || content.contains('-->')) {
        return _parseVTT(content);
      } else {
        return _parseSRT(content);
      }
    } catch (e) {
      debugPrint('Subtitle parsing error: $e');
      return [];
    }
  }

  static List<ParsedSubtitle> _parseVTT(String content) {
    final subtitles = <ParsedSubtitle>[];
    // Split by double newlines to get cue blocks
    final blocks = content.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      if (block.trim().isEmpty || block.contains('WEBVTT')) continue;

      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 2) continue;

      int timingIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timingIndex = i;
          break;
        }
      }

      if (timingIndex == -1) continue;

      final timingLine = lines[timingIndex];
      final textLines = lines.sublist(timingIndex + 1);

      if (textLines.isEmpty) continue;

      try {
        final timing = _parseTimestamp(timingLine);
        if (timing == null) continue;

        String text = textLines.join(' ');
        text = _cleanSubtitleText(text);

        if (text.trim().isNotEmpty) {
          subtitles.add(ParsedSubtitle(
            start: timing['start']!,
            end: timing['end']!,
            text: text,
          ));
        }
      } catch (e) {
        debugPrint('Failed to parse VTT cue: $e');
      }
    }

    subtitles.sort((a, b) => a.start.compareTo(b.start));
    return subtitles;
  }

  static List<ParsedSubtitle> _parseSRT(String content) {
    final subtitles = <ParsedSubtitle>[];
    final blocks = content.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;

      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 3) continue;

      try {
        // SRT: Line 1 is index, Line 2 is timing, Lines 3+ are text
        final timingLine = lines[1];
        final textLines = lines.sublist(2);

        final timing = _parseTimestamp(timingLine);
        if (timing == null) continue;

        String text = textLines.join(' ');
        text = _cleanSubtitleText(text);

        if (text.trim().isNotEmpty) {
          subtitles.add(ParsedSubtitle(
            start: timing['start']!,
            end: timing['end']!,
            text: text,
          ));
        }
      } catch (e) {
        debugPrint('Failed to parse SRT block: $e');
      }
    }

    subtitles.sort((a, b) => a.start.compareTo(b.start));
    return subtitles;
  }

  static Map<String, Duration>? _parseTimestamp(String line) {
    try {
      final parts = line.split('-->').map((s) => s.trim()).toList();
      if (parts.length != 2) return null;

      final start = _parseDuration(parts[0]);
      final end = _parseDuration(parts[1]);

      if (start == null || end == null) return null;

      return {'start': start, 'end': end};
    } catch (e) {
      return null;
    }
  }

  static Duration? _parseDuration(String timestamp) {
    try {
      timestamp = timestamp.split(' ').first.trim().replaceAll(',', '.');
      final parts = timestamp.split(':');
      if (parts.length < 2) return null;

      int hours = 0;
      int minutes = 0;
      double seconds = 0;

      if (parts.length == 3) {
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
        seconds = double.parse(parts[2]);
      } else if (parts.length == 2) {
        minutes = int.parse(parts[0]);
        seconds = double.parse(parts[1]);
      }

      final totalMilliseconds = (hours * 3600 + minutes * 60) * 1000 + (seconds * 1000).round();
      return Duration(milliseconds: totalMilliseconds);
    } catch (e) {
      return null;
    }
  }

  static String _cleanSubtitleText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}