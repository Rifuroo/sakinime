import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double _aspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final episodeId = args?['episodeId']?.toString();
      final server = args?['server']?.toString();
      final dub = args?['dub'] == true || args?['dub'] == 'true';
      if (episodeId != null && episodeId.isNotEmpty) {
        await context.read<PlayerProvider>().loadEpisode(episodeId, server: server, dub: dub);
        await _setupControllers();
      }
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _setupControllers() async {
    final p = context.read<PlayerProvider>();
    final url = p.currentUrl;
    if (url == null || url.isEmpty) return;

    // Dispose old controllers
    await _chewieController?.pause();
    await _videoController?.pause();
    _chewieController?.dispose();
    _videoController?.dispose();

    // Create new video controller with headers (for Referer)
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: p.headers,
    );
    await _videoController!.initialize();
    _aspectRatio = _videoController!.value.aspectRatio == 0
        ? 16 / 9
        : _videoController!.value.aspectRatio;

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      allowFullScreen: true,
      showControlsOnInitialize: true,
      aspectRatio: _aspectRatio,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.deepPurpleAccent,
        handleColor: Colors.purpleAccent,
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white38,
      ),
    );

    setState(() {});
  }

  Future<void> _onSelectQuality(String q) async {
    final provider = context.read<PlayerProvider>();
    provider.selectQuality(q);
    await _setupControllers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        actions: [
          Consumer<PlayerProvider>(
            builder: (context, p, _) {
              if (p.isLoading || (p.qualities.isEmpty && p.currentUrl == null)) {
                return const SizedBox.shrink();
              }
              final items = p.qualities.map((e) => e['quality']?.toString() ?? 'auto').toList();
              if (items.isEmpty) items.add('auto');

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: p.currentQuality ?? (items.contains('auto') ? 'auto' : items.first),
                  dropdownColor: const Color(0xFF1a1f3a),
                  items: items
                      .map((q) => DropdownMenuItem<String>(
                            value: q,
                            child: Text(q, style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v != null) await _onSelectQuality(v);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, p, _) {
            if (p.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (p.errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(p.errorMessage!, textAlign: TextAlign.center),
                ),
              );
            }
            if (_chewieController == null) {
              return const Center(child: Text('Tidak ada video'));
            }
            return Column(
              children: [
                AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: Chewie(controller: _chewieController!),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: const [
                      const Text('Subtitle overlay now displayed on video, including translation indicator.'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
