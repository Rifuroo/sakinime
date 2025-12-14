# 🚀 Railway Backend Integration Setup

This Flutter app is configured to fetch anime data from your Railway backend deployment. Follow these steps to set up the integration.

## 📋 Prerequisites

1. **Railway Backend Deployed**: Make sure your Node.js backend is deployed on Railway
2. **Backend URL**: Get your Railway deployment URL from the Railway dashboard
3. **API Endpoints**: Ensure all required endpoints are working

## ⚙️ Configuration Steps

### 1. Update Backend URL

Open `lib/config/app_config.dart` and update the Railway URL:

```dart
class AppConfig {
  // 🚀 Replace with your actual Railway URL
  static const String RAILWAY_BASE_URL = 'https://your-app-name.up.railway.app';
  
  // The rest will be automatically configured
  static const String API_BASE_URL = '$RAILWAY_BASE_URL/api/anime';
  static const String ANIME_BASE_URL = '$RAILWAY_BASE_URL/anime';
}
```

### 2. Required API Endpoints

Your Railway backend should provide these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/anime/home` | GET | Homepage data with ongoing and complete anime |
| `/api/anime/ongoing` | GET | Ongoing anime list (supports `?page=N`) |
| `/api/anime/search/{query}` | GET | Search anime by keyword |
| `/api/anime/{slug}` | GET | Anime details and episode list |
| `/api/anime/episode/{slug}` | GET | Episode details with video sources |
| `/api/anime/schedule` | GET | Weekly anime schedule |
| `/api/anime/genre/{genre}` | GET | Anime filtered by genre |
| `/api/anime/release-year/{year}` | GET | Anime filtered by release year |

### 3. Expected Response Format

All endpoints should return JSON in this format:

```json
{
  "status": "success",
  "data": {
    // Your data here
  },
  "message": "Optional success message"
}
```

For errors:
```json
{
  "status": "error",
  "message": "Error description",
  "details": "Optional error details"
}
```

### 4. Video Sources Format (Important!)

The `/api/anime/episode/{slug}` endpoint should return video sources in this enhanced format:

```json
{
  "status": "success",
  "data": {
    "episode_slug": "episode-slug",
    "episode_title": "Episode Title",
    "video_sources": [
      {
        "url": "https://example.com/video720.mp4",
        "quality": "720p",
        "type": "mp4",
        "provider": "direct"
      },
      {
        "url": "https://example.com/video480.mp4", 
        "quality": "480p",
        "type": "mp4",
        "provider": "direct"
      }
    ],
    "stream_urls": [
      {
        "url": "https://example.com/playlist.m3u8",
        "quality": "auto",
        "type": "hls",
        "provider": "stream"
      }
    ],
    "metadata": {
      "total_sources": 3,
      "available_qualities": ["720p", "480p", "auto"],
      "has_hls": true,
      "has_mp4": true
    }
  }
}
```

## 🧪 Testing Your Setup

### 1. Test Backend Endpoints

Use a tool like Postman or curl to test your endpoints:

```bash
# Test homepage
curl https://your-app.up.railway.app/api/anime/home

# Test ongoing anime
curl https://your-app.up.railway.app/api/anime/ongoing

# Test search
curl https://your-app.up.railway.app/api/anime/search/naruto

# Test episode (replace with actual episode slug)
curl https://your-app.up.railway.app/api/anime/episode/your-episode-slug
```

### 2. Check Response Format

Verify that:
- ✅ All responses have `"status": "success"`
- ✅ Data is in the `"data"` field
- ✅ Episode endpoints return `video_sources` array
- ✅ Video URLs are accessible and working

### 3. Test in Flutter App

1. Update the Railway URL in `app_config.dart`
2. Run the Flutter app: `flutter run`
3. Check the debug console for API logs
4. Test each feature: home, search, anime details, video playback

## 🔧 Troubleshooting

### Common Issues

1. **CORS Errors**: Make sure your Railway backend has CORS enabled for mobile apps
2. **404 Errors**: Check that your Railway deployment is running and endpoints exist
3. **Video Not Playing**: Verify video URLs are accessible and not blocked by CORS
4. **Slow Loading**: Check your Railway backend logs for performance issues

### Debug Mode

The app runs in debug mode by default and will show:
- API request/response logs
- Setup instructions on startup
- Detailed error messages

To disable debug mode for production:
```dart
// In lib/config/app_config.dart
static const bool DEBUG_MODE = false;
```

### Railway Backend Logs

Check your Railway deployment logs:
1. Go to Railway dashboard
2. Select your project
3. Click on "Deployments"
4. View logs for errors

## 🎯 Backend Code Reference

Your backend should use the scraper code you provided, with these key points:

1. **Enhanced Episode Response**: The `detailEpisode` function returns the enhanced format with `video_sources`
2. **Error Handling**: All endpoints should catch errors and return proper JSON responses
3. **CORS Setup**: Enable CORS for mobile app requests
4. **Headers**: Handle User-Agent and Referer headers for video scraping

## 📱 Flutter App Features

Once properly configured, the app provides:

- 🏠 **Homepage**: Featured ongoing and complete anime
- 🔍 **Search**: Find anime by title
- 📺 **Anime Details**: Synopsis, episodes, ratings
- ▶️ **Video Player**: Multiple qualities, BetterPlayer support
- 🎬 **Episode List**: Navigate between episodes
- 📱 **Mobile UI**: Optimized for mobile viewing

## 🚀 Deployment

For production deployment:

1. Set `DEBUG_MODE = false` in `app_config.dart`
2. Update Railway URL to your production deployment
3. Test all features thoroughly
4. Build and deploy your Flutter app

## 💡 Tips

- Keep your Railway backend URL handy
- Test video URLs manually to ensure they work
- Monitor Railway logs for any backend issues
- Use the debug console to troubleshoot API issues
- Consider implementing caching for better performance

---

**Need Help?** Check the debug console output when running the Flutter app - it will show detailed API logs and any errors encountered.