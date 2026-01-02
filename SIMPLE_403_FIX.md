# Simple HTTP 403 Fix

## Problem
HiAnime video streams return HTTP 403 errors because VideoPlayer on Android doesn't properly pass headers to HLS segment requests.

## Solution
**Use WebView for HLS streams that require headers**

### Changes Made:

1. **Updated `_shouldUseWebView()` in `anime_video_player.dart`**:
   ```dart
   bool _shouldUseWebView(StreamLink link) {
     final url = link.url.toLowerCase();
     final isDesu = url.contains('desustream') || (link.source?.toLowerCase() == 'desustream');
     
     // ✅ Use WebView for HLS streams that require headers (to avoid 403 errors)
     final isHLS = url.contains('.m3u8');
     final requiresHeaders = _apiHeaders.isNotEmpty && _apiHeaders.containsKey('Referer');
     
     // Use WebView for Desustream OR HLS streams that need special headers
     return isDesu || (isHLS && requiresHeaders);
   }
   ```

2. **Added WebView fallback as Strategy 3** in `_initializePlayer()`:
   - If HLS stream requires headers → Use WebView
   - WebView can properly handle headers for all requests
   - Falls back to native players for streams that don't need headers

3. **Simplified subtitle handling**:
   - Removed complex subtitle extraction (was causing issues)
   - Focus on fixing video playback first
   - Subtitles can be added later once video works

## How It Works Now:

1. **API Response**: `{sources: [...], headers: {Referer: "..."}, subtitles: [...]}`
2. **Header Check**: If `Referer` header exists and stream is HLS (.m3u8)
3. **WebView Route**: Use `AnimeWebViewPlayer` which handles headers properly
4. **Native Route**: Use MediaKit/VideoPlayer for streams that don't need headers

## Expected Result:
- ✅ HLS streams with headers → WebView (no 403 errors)
- ✅ Regular streams → Native players (better performance)
- ✅ Automatic fallback based on stream requirements

## Test:
Run the app and play any HiAnime episode. It should automatically use WebView for streams that need headers, avoiding the 403 error.