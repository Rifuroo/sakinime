// services/subtitle_parser_service.dart - Enhanced subtitle parser with Unicode support
import 'dart:convert';
import 'package:flutter/foundation.dart';

// ✅ Simple Subtitle model for parsing
class ParsedSubtitle {
  final Duration start;
  final Duration end;
  final String text;
  final String language;

  ParsedSubtitle({
    required this.start,
    required this.end,
    required this.text,
    required this.language,
  });
}

class SubtitleParserService {
  /// Parse VTT/SRT subtitles with full Unicode support for Arabic, Chinese, Japanese, etc.
  static List<ParsedSubtitle> parseSubtitles(String content, {String? language}) {
    if (content.trim().isEmpty) return [];

    try {
      // ✅ Ensure proper UTF-8 decoding
      String cleanContent = _ensureUtf8(content);
      
      if (kDebugMode) {
        print('🔤 Parsing subtitles for language: ${language ?? "unknown"}');
        print('   Content length: ${cleanContent.length} chars');
        print('   First 100 chars: ${cleanContent.substring(0, cleanContent.length > 100 ? 100 : cleanContent.length)}');
      }

      // Detect format and parse accordingly
      if (cleanContent.contains('WEBVTT') || cleanContent.contains('-->')) {
        return _parseVTT(cleanContent, language);
      } else {
        return _parseSRT(cleanContent, language);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Subtitle parsing error: $e');
      }
      return [];
    }
  }

  /// Ensure proper UTF-8 encoding for international characters
  static String _ensureUtf8(String content) {
    try {
      // Check if content has mojibake (UTF-8 decoded as Latin-1)
      // Common pattern: â, Ã, etc. appearing where they shouldn't
      if (content.contains(RegExp(r'[ÃÂ][^a-zA-Z\s]'))) {
        // Try to fix by re-encoding as Latin-1 then decoding as UTF-8
        try {
          final bytes = latin1.encode(content);
          final fixed = utf8.decode(bytes, allowMalformed: false);
          if (kDebugMode) print('✅ Fixed UTF-8 mojibake');
          return fixed;
        } catch (e) {
          // If that fails, return original
          if (kDebugMode) print('⚠️ Could not fix encoding, using original');
        }
      }
      
      // Content is already properly encoded
      return content;
    } catch (e) {
      if (kDebugMode) print('⚠️ Encoding check failed: $e');
      return content;
    }
  }

  /// Parse WebVTT format with Unicode support
  static List<ParsedSubtitle> _parseVTT(String content, String? language) {
    final subtitles = <ParsedSubtitle>[];
    
    // Split by double newlines to get cue blocks
    final blocks = content.split(RegExp(r'\n\s*\n'));
    
    for (final block in blocks) {
      if (block.trim().isEmpty || block.contains('WEBVTT')) continue;
      
      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 2) continue;
      
      // Find the timing line (contains -->)
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
        
        // ✅ Join text lines and clean HTML/VTT tags while preserving Unicode
        String text = textLines.join(' ');
        text = _cleanSubtitleText(text);
        
        if (text.trim().isNotEmpty) {
          subtitles.add(ParsedSubtitle(
            start: timing['start']!,
            end: timing['end']!,
            text: text,
            language: language ?? 'unknown',
          ));
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to parse VTT cue: $e');
        }
      }
    }
    
    // Sort by start time
    subtitles.sort((a, b) => a.start.compareTo(b.start));
    
    if (kDebugMode) {
      print('✅ Parsed ${subtitles.length} VTT subtitles');
      if (subtitles.isNotEmpty) {
        print('   Sample: "${subtitles.first.text}"');
      }
    }
    
    return subtitles;
  }

  /// Parse SRT format with Unicode support
  static List<ParsedSubtitle> _parseSRT(String content, String? language) {
    final subtitles = <ParsedSubtitle>[];
    
    // Split by double newlines to get subtitle blocks
    final blocks = content.split(RegExp(r'\n\s*\n'));
    
    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      
      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 3) continue;
      
      try {
        // Skip sequence number (first line)
        final timingLine = lines[1];
        final textLines = lines.sublist(2);
        
        final timing = _parseTimestamp(timingLine);
        if (timing == null) continue;
        
        // ✅ Join text lines and preserve Unicode characters
        String text = textLines.join(' ');
        text = _cleanSubtitleText(text);
        
        if (text.trim().isNotEmpty) {
          subtitles.add(ParsedSubtitle(
            start: timing['start']!,
            end: timing['end']!,
            text: text,
            language: language ?? 'unknown',
          ));
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to parse SRT block: $e');
        }
      }
    }
    
    // Sort by start time
    subtitles.sort((a, b) => a.start.compareTo(b.start));
    
    if (kDebugMode) {
      print('✅ Parsed ${subtitles.length} SRT subtitles');
      if (subtitles.isNotEmpty) {
        print('   Sample: "${subtitles.first.text}"');
      }
    }
    
    return subtitles;
  }

  /// Parse timestamp from VTT/SRT format
  static Map<String, Duration>? _parseTimestamp(String line) {
    try {
      // Handle both VTT (00:00:00.000) and SRT (00:00:00,000) formats
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

  /// Parse duration from timestamp string
  static Duration? _parseDuration(String timestamp) {
    try {
      // Remove any extra whitespace and settings
      timestamp = timestamp.split(' ').first.trim();
      
      // Handle both comma and dot as decimal separator
      timestamp = timestamp.replaceAll(',', '.');
      
      // Parse HH:MM:SS.mmm or MM:SS.mmm
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
      } else if (parts.length == 2) {
        // MM:SS.mmm
        minutes = int.parse(parts[0]);
        seconds = double.parse(parts[1]);
      }
      
      final totalMilliseconds = (hours * 3600 + minutes * 60) * 1000 + (seconds * 1000).round();
      return Duration(milliseconds: totalMilliseconds);
    } catch (e) {
      return null;
    }
  }

  /// Clean subtitle text while preserving Unicode characters
  static String _cleanSubtitleText(String text) {
    // Remove VTT/HTML tags but preserve Unicode content
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll(RegExp(r'\{[^}]*\}'), '');
    
    // Clean up common VTT cue settings
    text = text.replaceAll(RegExp(r'\s+align:\w+'), '');
    text = text.replaceAll(RegExp(r'\s+position:\d+%'), '');
    text = text.replaceAll(RegExp(r'\s+size:\d+%'), '');
    text = text.replaceAll(RegExp(r'\s+line:\d+%'), '');
    
    // Normalize whitespace but preserve line breaks for multi-line subtitles
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.trim();
    
    // Decode HTML entities while preserving Unicode
    text = _decodeHtmlEntities(text);
    
    return text;
  }

  /// Decode HTML entities while preserving Unicode characters
  static String _decodeHtmlEntities(String text) {
    final entities = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&nbsp;': ' ',
    };
    
    String result = text;
    entities.forEach((entity, replacement) {
      result = result.replaceAll(entity, replacement);
    });
    
    // Handle numeric HTML entities (&#123; or &#x1F;)
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      try {
        final code = int.parse(match.group(1)!);
        return String.fromCharCode(code);
      } catch (e) {
        return match.group(0)!;
      }
    });
    
    result = result.replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (match) {
      try {
        final code = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(code);
      } catch (e) {
        return match.group(0)!;
      }
    });
    
    return result;
  }

  /// Get subtitle at specific time
  static ParsedSubtitle? getSubtitleAt(List<ParsedSubtitle> subtitles, Duration position) {
    for (final subtitle in subtitles) {
      if (position >= subtitle.start && position <= subtitle.end) {
        return subtitle;
      }
    }
    return null;
  }

  /// Validate subtitle content for international characters
  static bool isValidUnicodeSubtitle(String text) {
    if (text.trim().isEmpty) return false;
    
    // Check if text contains valid Unicode characters
    try {
      final encoded = utf8.encode(text);
      final decoded = utf8.decode(encoded);
      return decoded == text;
    } catch (e) {
      return false;
    }
  }

  /// Detect subtitle language from content patterns
  static String detectLanguage(String content) {
    // Simple language detection based on character patterns
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(content)) {
      return 'Chinese';
    } else if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(content)) {
      return 'Japanese';
    } else if (RegExp(r'[\u0600-\u06ff]').hasMatch(content)) {
      return 'Arabic';
    } else if (RegExp(r'[\u0400-\u04ff]').hasMatch(content)) {
      return 'Russian';
    } else if (RegExp(r'[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]').hasMatch(content)) {
      return 'Korean';
    } else {
      return 'English';
    }
  }
}