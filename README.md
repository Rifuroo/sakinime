# Sakinime - Anime Streaming App 🎌

A modern, cross-platform anime streaming application built with Flutter. Stream your favorite anime with high-quality video playback, subtitle support, and seamless user experience across all devices.

## 📱 Screenshots & Demo

### 🎬 App Preview
<div align="center">
  
![App Demo](https://via.placeholder.com/800x450/0a0e27/ffffff?text=🎌+Sakinime+Demo+GIF)

*Replace this placeholder with your actual app demo GIF*

</div>

### 📸 Screenshots

<div align="center">

| Home Screen | Video Player | Search & Discovery |
|-------------|--------------|-------------------|
| ![Home](https://via.placeholder.com/250x450/0a0e27/ffffff?text=🏠+Home) | ![Player](https://via.placeholder.com/250x450/0a0e27/ffffff?text=▶️+Player) | ![Search](https://via.placeholder.com/250x450/0a0e27/ffffff?text=🔍+Search) |

| Anime Details | Watch History | Settings |
|---------------|---------------|----------|
| ![Details](https://via.placeholder.com/250x450/0a0e27/ffffff?text=📋+Details) | ![History](https://via.placeholder.com/250x450/0a0e27/ffffff?text=📚+History) | ![Settings](https://via.placeholder.com/250x450/0a0e27/ffffff?text=⚙️+Settings) |

</div>

> **📝 Note:** Replace placeholder images with actual screenshots of your app. You can use tools like:
> - **Android**: `adb shell screencap` or Android Studio
> - **iOS**: Simulator screenshots or Xcode
> - **Desktop**: Built-in screenshot tools
> - **GIF Recording**: [LICEcap](https://www.cockos.com/licecap/) or [ScreenToGif](https://www.screentogif.com/)

## ✨ Features

### 🎥 Video Streaming
- **Multi-platform video playback** with Media Kit integration
- **Adaptive streaming** with multiple quality options
- **Subtitle support** with real-time translation
- **Picture-in-picture mode** for multitasking
- **Offline watch history** tracking

### 🎨 User Interface
- **Modern Material Design** with custom animations
- **Dark/Light theme** support
- **Responsive layout** for mobile, tablet, and desktop
- **Smooth animations** with Lottie integration
- **Custom loading states** with shimmer effects

### 📱 Cross-Platform Support
- **Android** - Native performance with adaptive icons
- **iOS** - Optimized for iPhone and iPad
- **Windows** - Desktop experience with window management
- **Web** - Progressive web app capabilities

### 🔍 Content Discovery
- **Advanced search** with real-time suggestions
- **Genre filtering** and categorization
- **Anime scheduling** and release calendar
- **Continue watching** recommendations
- **Watch history** with progress tracking

### 🌐 Localization
- **Multi-language support** with Google Translate integration
- **Subtitle translation** in real-time
- **Adaptive content** based on user preferences

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Rifuroo/sakinime.git
   cd sakinime
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Platform-specific Setup

#### Android
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ios --release
```

#### Windows
```bash
flutter build windows --release
```

#### Web
```bash
flutter build web --release
```

## 🏗️ Architecture

### Project Structure
```
lib/
├── config/          # App configuration
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── services/        # Business logic
├── utils/           # Helper utilities
└── widgets/         # Reusable components
```

### Key Technologies
- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **Media Kit** - Video playback engine
- **Firebase** - Authentication & database
- **Dio/HTTP** - Network requests
- **Shared Preferences** - Local storage

## 📦 Dependencies

### Core
- `flutter` - UI framework
- `provider` - State management
- `shared_preferences` - Local storage

### Networking
- `dio` - HTTP client
- `http` - HTTP requests
- `html` - HTML parsing

### Media & UI
- `media_kit` - Video playback
- `video_player` - Video controls
- `chewie` - Video player UI
- `cached_network_image` - Image caching
- `lottie` - Animations
- `google_fonts` - Typography

### Platform Integration
- `firebase_core` - Firebase integration
- `window_manager` - Desktop window management
- `webview_flutter` - Web content display

## 🎯 Roadmap

- [ ] **Offline Downloads** - Download episodes for offline viewing
- [ ] **Social Features** - User profiles and anime lists
- [ ] **Chromecast Support** - Cast to TV devices
- [ ] **Advanced Filters** - More search and filter options
- [ ] **Recommendation Engine** - AI-powered suggestions
- [ ] **Community Features** - Reviews and ratings

## 📷 Adding Screenshots

To update the README with actual screenshots:

1. **Take screenshots** of your app on different platforms
2. **Save them** in the `screenshots/` folder with descriptive names:
   ```
   screenshots/
   ├── home_screen.png
   ├── video_player.png
   ├── search_screen.png
   ├── anime_details.png
   ├── watch_history.png
   ├── settings_screen.png
   └── demo.gif
   ```
3. **Update README.md** by replacing placeholder URLs with:
   ```markdown
   ![Home](screenshots/home_screen.png)
   ![Demo](screenshots/demo.gif)
   ```

### 🎥 Creating Demo GIF
- **Record your screen** while using the app
- **Keep it under 10MB** for GitHub compatibility
- **Show key features**: navigation, video playback, search
- **Duration**: 15-30 seconds optimal

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter/Dart style guidelines
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team** - For the amazing framework
- **Media Kit** - For cross-platform video playback
- **Firebase** - For backend services
- **Community** - For feedback and contributions

## 📞 Support

- **Issues** - [GitHub Issues](https://github.com/Rifuroo/sakinimesakinime/issues)
- **Discussions** - [GitHub Discussions](https://github.com/Rifuroo/sakinimesakinime/discussions)

---

**Made with ❤️ using Flutter**