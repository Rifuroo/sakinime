// utils/platform_utils.dart - Platform detection utilities
import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  /// Check if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  /// Check if running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  
  /// Check if running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  
  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  /// Check if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop => isWindows || isMacOS || isLinux;
  
  /// Check if running on mobile (Android, iOS)
  static bool get isMobile => isAndroid || isIOS;
  
  /// Check if running on web
  static bool get isWeb => kIsWeb;
  
  /// Get platform name as string
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
  
  /// Check if video player should use native implementation
  static bool get shouldUseNativeVideoPlayer {
    return isAndroid || isIOS;
  }
  
  /// Check if should use Windows-specific video player
  static bool get shouldUseWindowsVideoPlayer {
    return isWindows;
  }
  
  /// Check if should use WebView fallback
  static bool get shouldUseWebViewFallback {
    return isMobile || isWeb;
  }
}