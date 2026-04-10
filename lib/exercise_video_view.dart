import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ExerciseVideoView extends StatefulWidget {
  final String exerciseName;
  final String videoUrl;

  const ExerciseVideoView({
    super.key,
    required this.exerciseName,
    required this.videoUrl,
  });

  @override
  State<ExerciseVideoView> createState() => _ExerciseVideoViewState();
}

class _ExerciseVideoViewState extends State<ExerciseVideoView> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    
    if (_videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
        ),
      );
    }
  }

  @override
  void deactivate() {
    if (_videoId != null) {
      _controller.pause();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    if (_videoId != null) {
      _controller.dispose();
    }
    // Ensure orientation is restored if user exits full screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      player: _videoId != null ? YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).primaryColor,
        onReady: () {
          _isPlayerReady = true;
        },
      ) : YoutubePlayer(controller: YoutubePlayerController(initialVideoId: '')), // dummy
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.exerciseName),
          ),
          body: Column(
            children: [
              if (_videoId != null)
                player
              else
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.black,
                  child: const Center(
                    child: Text('Invalid YouTube URL', style: TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.exerciseName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Watch the video carefully to ensure proper form and avoid injury. Follow the instructor\'s pacing.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
