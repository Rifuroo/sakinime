# HTTP 403 Error & Subtitle Fix Summary

## Problem 1: HTTP 403 Forbidden Error
**Issue**: Video playback was failing with HTTP 403 error because the HiAnime API requires specific headers (especially `Referer`) to access video streams, but the video player wasn't using them.

**Solution**: 
1. Added `_apiHeaders` field to store headers from API response
2. Updated `_loadEpisodeAndPlay()` to extract and store headers from `data['headers']`
3. Modified both MediaKit and VideoPlayer initialization to use these headers:
   - MediaKit: Pass headers via `Media(url, httpHeaders: {...})`
   - VideoPlayer: Pass headers via `VideoPlayerController.networkUrl(url, httpHeaders: {...})`
4. Headers are now properly propagated to all video requests

**Files Modified**:
- `coba_anime/lib/widgets/anime_video_player.dart`
  - Added `_apiHeaders` field
  - Updated `_loadEpisodeAndPlay()` to store API headers
  - Updated `_initializePlayer()` to use headers in both MediaKit and VideoPlayer
  - Updated quality switching to maintain headers

## Problem 2: Subtitle URLs Missing
**Issue**: HiAnime API returns subtitle metadata without direct URLs:
```json
{
  "subtitles": [
    {"lang": "English", "kind": "captions"}
  ]
}
```

**Solution**:
1. Added `extractSubtitlesFromEmbed()` method to extract subtitle URLs from embed player HTML
2. Updated `getQualitiesWithSubtitles()` to:
   - Try multiple servers (vidstreaming, vidcloud, streamwish)
   - If no direct subtitle URLs found, extract from embed URL in `headers.Referer`
   - Parse HTML using string parsing (avoiding complex regex) to find `<track>` tags and JSON subtitle data
3. Added `_convertLanguageCode()` helper to convert language codes (en, es, etc.) to readable names

**Note**: Used simple string parsing instead of regex to avoid Dart regex character class issues with quotes.

**Files Modified**:
- `coba_anime/lib/services/zoro_service.dart`
  - Added `extractSubtitlesFromEmbed()` method
  - Added `_convertLanguageCode()` helper
  - Updated `getQualitiesWithSubtitles()` to extract from embed
  - Added logging for headers in `getQualities()`

## How It Works Now

### Video Playback Flow:
1. API call returns: `{sources: [...], headers: {Referer: "embed_url"}, subtitles: [...]}`
2. App stores headers in `_apiHeaders`
3. When initializing player:
   - MediaKit: `Media(url, httpHeaders: {User-Agent, Accept, ...apiHeaders})`
   - VideoPlayer: `VideoPlayerController.networkUrl(url, httpHeaders: {...})`
4. All video segment requests now include proper `Referer` header
5. Server accepts requests → No more 403 errors

### Subtitle Extraction Flow:
1. Try multiple servers to find one with direct subtitle URLs
2. If no direct URLs:
   - Extract embed URL from `headers.Referer`
   - Fetch embed HTML
   - Parse for `<track kind="captions" src="url" srclang="lang">` tags
   - Parse for JSON subtitle data
3. Return extracted subtitle URLs
4. App loads and displays subtitles normally

## Testing
To test the fixes:
1. Run the app: `flutter run --debug`
2. Play any episode
3. Check logs for:
   - `🔑 Stored API headers: {Referer: ...}`
   - `🔑 Using headers: {...}` (during player init)
   - `📝 Found subtitle: English -> url` (if subtitles extracted)
4. Video should play without 403 errors
5. Subtitles should load if available

## Notes
- Headers are cached per episode along with video URLs
- MediaKit is primary player for Windows (better performance)
- VideoPlayer is fallback with same header support
- Subtitle extraction is best-effort (depends on embed format)
- Some HiAnime streams may have embedded subtitles in HLS manifest (handled by player automatically)
