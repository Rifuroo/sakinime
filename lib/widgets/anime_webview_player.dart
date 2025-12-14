// widgets/anime_webview_player.dart - IFRAME PLAYER WITH PIP
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/anime_model.dart';

class AnimeWebViewPlayer extends StatefulWidget {
  final StreamLink initialStreamLink;
  final String episodeTitle;
  final List<StreamLink> allStreamLinks;

  const AnimeWebViewPlayer({
    super.key,
    required this.initialStreamLink,
    required this.episodeTitle,
    required this.allStreamLinks,
  });

  @override
  State<AnimeWebViewPlayer> createState() => _AnimeWebViewPlayerState();
}

class _AnimeWebViewPlayerState extends State<AnimeWebViewPlayer> {
  InAppWebViewController? _webViewController;
  StreamLink? _currentStreamLink;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showQualityMenu = false;
  double _loadingProgress = 0.0;
  bool _isPipSupported = true; // Assume supported by default
  bool _isPipActive = false;

  @override
  void initState() {
    super.initState();
    _currentStreamLink = widget.initialStreamLink;
    
    // Lock to landscape for better viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _enablePictureInPicture() async {
    if (_webViewController == null || !_isPipSupported) return;
    
    try {
      // Inject JavaScript to enable PiP on video element
      await _webViewController!.evaluateJavascript(source: '''
        (function() {
          // Find video element
          var video = document.querySelector('video');
          
          if (video && document.pictureInPictureEnabled) {
            // Request PiP
            if (!document.pictureInPictureElement) {
              video.requestPictureInPicture()
                .then(() => {
                  console.log('PiP enabled');
                })
                .catch(err => {
                  console.error('PiP error:', err);
                });
            }
          } else {
            console.warn('PiP not available');
          }
        })();
      ''');
      
      setState(() {
        _isPipActive = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📺 Picture-in-Picture aktif',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ PiP activation error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Picture-in-Picture tidak didukung',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _changeServer(StreamLink newLink) async {
    if (_currentStreamLink?.url == newLink.url) return;

    setState(() {
      _currentStreamLink = newLink;
      _showQualityMenu = false;
      _isLoading = true;
      _hasError = false;
    });

    // Reload with new URL
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_currentStreamLink!.url)),
    );
  }

  @override
  void dispose() {
    // Restore orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // WebView Player
            if (!_hasError)
              InAppWebView(
                initialUrlRequest: _initialUrlRequestFor(_currentStreamLink!),
                initialData: _initialDataFor(_currentStreamLink!),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  allowsPictureInPictureMediaPlayback: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useHybridComposition: true,
                  supportZoom: false,
                  disableContextMenu: true,
                  allowsLinkPreview: false,
                  isFraudulentWebsiteWarningEnabled: false,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  
                  // Add JavaScript handler for PiP events
                  controller.addJavaScriptHandler(
                    handlerName: 'pipHandler',
                    callback: (args) {
                      setState(() {
                        _isPipActive = args[0] == 'entered';
                      });
                    },
                  );
                  
                  // Inject PiP monitoring script
                  Future.delayed(const Duration(seconds: 2), () {
                    controller.evaluateJavascript(source: '''
                      (function() {
                        var video = document.querySelector('video');
                        if (video) {
                          video.addEventListener('enterpictureinpicture', function() {
                            window.flutter_inappwebview.callHandler('pipHandler', 'entered');
                          });
                          video.addEventListener('leavepictureinpicture', function() {
                            window.flutter_inappwebview.callHandler('pipHandler', 'left');
                          });
                        }
                      })();
                    ''');
                  });
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    _isLoading = false;
                  });
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _loadingProgress = progress / 100;
                  });
                },
                onReceivedError: (controller, request, error) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                    _errorMessage = error.description;
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('🌐 Console: ${consoleMessage.message}');
                },
              ),

            // Loading Indicator
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _loadingProgress > 0 ? _loadingProgress : null,
                        color: const Color(0xFF6366F1),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading video...',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_loadingProgress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentStreamLink?.provider ?? '',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF818CF8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error Widget
            if (_hasError)
              _buildErrorWidget(),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.episodeTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.allStreamLinks.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showQualityMenu = !_showQualityMenu;
                          });
                        },
                        icon: const Icon(Icons.high_quality_rounded, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                      ),
                    if (_isPipSupported && !_isLoading)
                      IconButton(
                        onPressed: _enablePictureInPicture,
                        icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                      ),
                  ],
                ),
              ),
            ),

            // Server Selection Menu
            if (_showQualityMenu)
              Positioned(
                top: 64,
                right: 12,
                child: _buildServerMenu(),
              ),
          ],
        ),
      ),
    );
  }

  // Build proper initial content based on link type
  URLRequest? _initialUrlRequestFor(StreamLink link) {
    final url = link.url;
    final lower = url.toLowerCase();
    final isHls = lower.contains('.m3u8') || link.type.toLowerCase() == 'hls';
    final isMp4 = lower.contains('.mp4') || link.type.toLowerCase() == 'mp4';
    // For direct media links, we'll render custom HTML via initialData instead
    if (isHls || isMp4) return null;
    // Otherwise load the page directly
    return URLRequest(url: WebUri(url));
  }

  InAppWebViewInitialData? _initialDataFor(StreamLink link) {
    final url = link.url;
    final lower = url.toLowerCase();
    final isHls = lower.contains('.m3u8') || link.type.toLowerCase() == 'hls';
    final isMp4 = lower.contains('.mp4') || link.type.toLowerCase() == 'mp4';
    if (!isHls && !isMp4) return null;

    final html = _buildPlayerHtml(url, isHls: isHls);
    // Use desustream as base to provide a friendly Referer-like origin
    final base = WebUri('https://desustream.info');
    return InAppWebViewInitialData(data: html, baseUrl: base, encoding: 'utf-8', mimeType: 'text/html');
  }

  String _buildPlayerHtml(String mediaUrl, {required bool isHls}) {
    final escapedUrl = mediaUrl.replaceAll("'", r"\'");
    if (isHls) {
      return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
    #container { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; background: #000; }
    video { width: 100%; height: 100%; object-fit: contain; background: #000; }
  </style>
</head>
<body>
  <div id="container">
    <video id="video" controls playsinline webkit-playsinline autoplay></video>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <script>
    (function() {
      var url = '${escapedUrl}';
      var video = document.getElementById('video');
      if (Hls.isSupported()) {
        var hls = new Hls({ 
          maxBufferLength: 60,
          enableWorker: true,
          lowLatencyMode: true,
        });
        hls.loadSource(url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function() {
          video.play().catch(function(){});
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
        video.addEventListener('loadedmetadata', function() {
          video.play().catch(function(){});
        });
      } else {
        document.body.innerHTML = '<div style="color:#fff;text-align:center;padding:20px;">HLS not supported</div>';
      }
    })();
  </script>
</body>
</html>
''';
    } else {
      // MP4 direct
      return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
    #container { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; background: #000; }
    video { width: 100%; height: 100%; object-fit: contain; background: #000; }
  </style>
</head>
<body>
  <div id="container">
    <video id="video" controls playsinline webkit-playsinline autoplay src='${escapedUrl}'></video>
  </div>
</body>
</html>
''';
    }
  }

  Widget _buildServerMenu() {
    // Filter streaming servers only
    final streamServers = widget.allStreamLinks
        .where((link) => link.isIframe || link.isDirect)
        .toList();

    return Container(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 440),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Quality',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showQualityMenu = false;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Server List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: streamServers.length,
              itemBuilder: (context, index) {
                final server = streamServers[index];
                final isSelected = _currentStreamLink?.url == server.url;

                return InkWell(
                  onTap: () => _changeServer(server),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6366F1).withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: isSelected
                              ? const Color(0xFF818CF8)
                              : Colors.white60,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                server.provider,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (server.note != null)
                                Text(
                                  server.note!,
                                  style: GoogleFonts.inter(
                                    color: Colors.orange[300],
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            server.displayType,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF818CF8),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to Load Video',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unknown error',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Try Other Servers
              if (widget.allStreamLinks.length > 1)
                Column(
                  children: [
                    Text(
                      'Try another server:',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: widget.allStreamLinks
                          .where((l) => 
                              l.url != _currentStreamLink?.url && 
                              (l.isIframe || l.isDirect))
                          .take(4)
                          .map((link) => ElevatedButton(
                                onPressed: () => _changeServer(link),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  link.provider,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}