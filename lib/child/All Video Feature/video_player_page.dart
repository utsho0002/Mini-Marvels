import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'quiz_page.dart';

class VideoPlayerPage extends StatefulWidget {
  final String childId;
  final String storyId;
  final String title;
  final String description;
  final String youtubeUrl;
  final String youtubeVideoId;
  final int storyXp;

  const VideoPlayerPage({
    super.key,
    required this.childId,
    required this.storyId,
    required this.title,
    required this.description,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    required this.storyXp,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  YoutubePlayerController? _youtubeController;

  bool _hasVideoError = false;
  bool _hasOpenedQuiz = false;
  String _resolvedVideoId = '';

  @override
  void initState() {
    super.initState();
    _setupYoutubePlayer();
  }

  void _setupYoutubePlayer() {
    try {
      final String videoId = _getYoutubeVideoId();

      _resolvedVideoId = videoId;

      if (videoId.isEmpty) {
        _hasVideoError = true;
        return;
      }

     _youtubeController = YoutubePlayerController(
  initialVideoId: videoId,
  flags: const YoutubePlayerFlags(
    autoPlay: true,
    mute: false,
    loop: false,
    isLive: false,
    forceHD: false,
    enableCaption: false,
    hideControls: false,
    hideThumbnail: true,
    controlsVisibleAtStart: true,
    disableDragSeek: false,
    useHybridComposition: true,
  ),
);

      _youtubeController?.addListener(_youtubeListener);
    } catch (error) {
      debugPrint('YouTube player setup failed: $error');
      _hasVideoError = true;
    }
  }

  void _youtubeListener() {
    if (!mounted || _hasOpenedQuiz) {
      return;
    }

    final YoutubePlayerController? controller = _youtubeController;

    if (controller == null) {
      return;
    }

    if (controller.value.playerState == PlayerState.ended) {
      _goToQuizPage();
    }
  }

  void _goToQuizPage() {
    if (_hasOpenedQuiz || !mounted) {
      return;
    }

    _hasOpenedQuiz = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPage(
            childId: widget.childId,
            storyId: widget.storyId,
          ),
        ),
      );
    });
  }

  String _getYoutubeVideoId() {
    final String directValue = widget.youtubeVideoId.trim();
    final String urlValue = widget.youtubeUrl.trim();

    if (_looksLikeYoutubeId(directValue)) {
      return directValue;
    }

    final String idFromDirectValue = _extractYoutubeVideoId(directValue);

    if (idFromDirectValue.isNotEmpty) {
      return idFromDirectValue;
    }

    final String idFromUrl = _extractYoutubeVideoId(urlValue);

    if (idFromUrl.isNotEmpty) {
      return idFromUrl;
    }

    return '';
  }

  bool _looksLikeYoutubeId(String value) {
    return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value);
  }

  String _extractYoutubeVideoId(String value) {
    final String input = value.trim();

    if (input.isEmpty) {
      return '';
    }

    if (_looksLikeYoutubeId(input)) {
      return input;
    }

    final Uri? uri = Uri.tryParse(input);

    if (uri == null) {
      return '';
    }

    final String host = uri.host.toLowerCase();

    if (host.contains('youtube.com')) {
      final String? normalVideoId = uri.queryParameters['v'];

      if (normalVideoId != null &&
          _looksLikeYoutubeId(normalVideoId.trim())) {
        return normalVideoId.trim();
      }

      if (uri.pathSegments.length >= 2) {
        final String firstSegment = uri.pathSegments[0].toLowerCase();
        final String secondSegment = uri.pathSegments[1].trim();

        if (firstSegment == 'shorts' && _looksLikeYoutubeId(secondSegment)) {
          return secondSegment;
        }

        if (firstSegment == 'embed' && _looksLikeYoutubeId(secondSegment)) {
          return secondSegment;
        }

        if (firstSegment == 'live' && _looksLikeYoutubeId(secondSegment)) {
          return secondSegment;
        }

        if (firstSegment == 'v' && _looksLikeYoutubeId(secondSegment)) {
          return secondSegment;
        }
      }
    }

    if (host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) {
        final String shortVideoId = uri.pathSegments.first.trim();

        if (_looksLikeYoutubeId(shortVideoId)) {
          return shortVideoId;
        }
      }
    }

    return '';
  }

  String getTitle() {
    final String title = widget.title.trim();

    if (title.isEmpty) {
      return 'Story Video';
    }

    return title;
  }

  String getDescription() {
    final String description = widget.description.trim();

    if (description.isEmpty) {
      return 'Watch this fun story video and enjoy your adventure!';
    }

    return description;
  }

  @override
  void dispose() {
    _youtubeController?.removeListener(_youtubeListener);
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final YoutubePlayerController? controller = _youtubeController;

    if (_hasVideoError || controller == null) {
      return _buildMainPage(
        playerWidget: _buildVideoErrorBox(),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFFFFCC33),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFFFFCC33),
          handleColor: Color.fromARGB(255, 124, 58, 237),
        ),
        onEnded: (_) {
          _goToQuizPage();
        },
      ),
      builder: (context, player) {
        return _buildMainPage(
          playerWidget: player,
        );
      },
    );
  }

  Widget _buildMainPage({
    required Widget playerWidget,
  }) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          getTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 183, 151, 239),
                  Color.fromARGB(255, 124, 58, 237),
                  Color.fromARGB(255, 124, 32, 232),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          _buildSkyDecorations(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: playerWidget,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    getTitle(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildXpBadge(),

                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      getDescription(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),

                  const SizedBox(height: 70),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC33),
                        foregroundColor:
                            const Color.fromARGB(255, 124, 58, 237),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 17,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 10,
                        shadowColor: Colors.black.withOpacity(0.28),
                      ),
                      onPressed: _goToQuizPage,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.quiz_rounded,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Start Quiz',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoErrorBox() {
    return Container(
      height: 220,
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Text(
            _resolvedVideoId.isEmpty
                ? 'Video could not load. Please check the YouTube link or video ID.'
                : 'Video could not load inside the app.\nVideo ID: $_resolvedVideoId',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildXpBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC33),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.65),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color.fromARGB(255, 124, 58, 237),
            size: 22,
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.storyXp} XP',
            style: const TextStyle(
              color: Color.fromARGB(255, 124, 58, 237),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkyDecorations() {
    return Opacity(
      opacity: 0.15,
      child: Stack(
        children: [
          _skyIcon(Icons.cloud, 80, 30, 60),
          _skyIcon(Icons.star, 150, 320, 20),
          _skyIcon(Icons.cloud, 450, 15, 80),
          _skyIcon(Icons.star, 280, 60, 25),
          _skyIcon(Icons.cloud, 650, 280, 70),
          _skyIcon(Icons.star, 520, 110, 15),
        ],
      ),
    );
  }

  Widget _skyIcon(IconData icon, double top, double left, double size) {
    return Positioned(
      top: top,
      left: left,
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    );
  }
}