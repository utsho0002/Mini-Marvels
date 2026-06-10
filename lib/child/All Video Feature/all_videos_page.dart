import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'video_player_page.dart';

class AllVideosPage extends StatefulWidget {
  final String childId;

  const AllVideosPage({
    super.key,
    required this.childId,
  });

  @override
  State<AllVideosPage> createState() => _AllVideosPageState();
}

class _AllVideosPageState extends State<AllVideosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const List<String> _categories = [
    'All',
    'Stories',
    'Learning',
    'Science & Nature',
    'General Knowledge',
    'Safety',
    'Fun & Songs',
  ];

  late Future<List<Map<String, dynamic>>> _videosFuture;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();

    // Loads active story videos when the page opens.
    _videosFuture = _fetchVideosFromDatabase();
  }

  // Fetches all active videos with their category from Supabase.
  Future<List<Map<String, dynamic>>> _fetchVideosFromDatabase() async {
    try {
      final List<dynamic> data = await _supabase
          .from('story_videos')
          .select('''
            story_id,
            title,
            description,
            youtube_url,
            youtube_video_id,
            xp_reward,
            category,
            is_active,
            created_at
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return data.map((row) {
        final Map<String, dynamic> videoMap =
            Map<String, dynamic>.from(row as Map);

        final String youtubeVideoId =
            videoMap['youtube_video_id']?.toString().trim() ?? '';

        videoMap['thumbnail_url'] = _getYoutubeThumbnailUrl(youtubeVideoId);

        return videoMap;
      }).toList();
    } on PostgrestException catch (error) {
      debugPrint('Story videos fetch failed: ${error.message}');
      debugPrint('Story videos details: ${error.details}');
      debugPrint('Story videos hint: ${error.hint}');
      debugPrint('Story videos code: ${error.code}');
      rethrow;
    } catch (error) {
      debugPrint('Story videos unknown fetch error: $error');
      rethrow;
    }
  }

  // Refreshes the video list without changing the selected category.
  Future<void> _refreshVideos() async {
    setState(() {
      _videosFuture = _fetchVideosFromDatabase();
    });

    await _videosFuture;
  }

  // Builds a YouTube thumbnail URL from the stored video id.
  String _getYoutubeThumbnailUrl(String youtubeVideoId) {
    if (youtubeVideoId.trim().isEmpty) {
      return '';
    }

    return 'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';
  }

  // Safely reads text values from each video row.
  String _getStringValue(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final dynamic value = map[key];

    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  // Safely reads number values from each video row.
  int _getIntValue(
    Map<String, dynamic> map,
    String key, {
    int fallback = 0,
  }) {
    final dynamic value = map[key];

    if (value == null) {
      return fallback;
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  // Filters videos by the selected category chip.
  List<Map<String, dynamic>> _filterVideosByCategory(
    List<Map<String, dynamic>> videos,
  ) {
    if (_selectedCategory == 'All') {
      return videos;
    }

    return videos.where((video) {
      final String category = _getStringValue(
        video,
        'category',
        fallback: 'Stories',
      );

      return category == _selectedCategory;
    }).toList();
  }

  // Updates the selected category and rebuilds the grid.
  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // Opens the selected video details/player page.
  void _openVideo(Map<String, dynamic> video) {
    final String storyId = _getStringValue(
      video,
      'story_id',
    );

    final String title = _getStringValue(
      video,
      'title',
      fallback: 'Story Video',
    );

    final String description = _getStringValue(
      video,
      'description',
    );

    final String youtubeUrl = _getStringValue(
      video,
      'youtube_url',
    );

    final String youtubeVideoId = _getStringValue(
      video,
      'youtube_video_id',
    );

    final int storyXp = _getIntValue(
      video,
      'xp_reward',
    );

    if (storyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story ID missing for this video.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          childId: widget.childId,
          storyId: storyId,
          title: title,
          description: description,
          youtubeUrl: youtubeUrl,
          youtubeVideoId: youtubeVideoId,
          storyXp: storyXp,
        ),
      ),
    );
  }

  // Horizontal category chips shown above the video grid.
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 10);
        },
        itemBuilder: (context, index) {
          final String category = _categories[index];
          final bool isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () {
              _changeCategory(category);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(isSelected ? 1 : 0.35),
                  width: 1.3,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected
                      ? const Color.fromARGB(255, 124, 58, 237)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Builds the video grid after category filtering.
  Widget _buildVideoGrid(List<Map<String, dynamic>> videos) {
    final List<Map<String, dynamic>> filteredVideos =
        _filterVideosByCategory(videos);

    if (filteredVideos.isEmpty) {
      return Center(
        child: Text(
          'No videos found in $_selectedCategory.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: filteredVideos.length,
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        final Map<String, dynamic> video = filteredVideos[index];

        final String title = _getStringValue(
          video,
          'title',
          fallback: 'Story Video',
        );

        final String thumbnailUrl = _getStringValue(
          video,
          'thumbnail_url',
        );

        final int storyXp = _getIntValue(
          video,
          'xp_reward',
        );

        return GestureDetector(
          onTap: () {
            _openVideo(video);
          },
          child: _buildVideoCard(
            title: title,
            thumbnailUrl: thumbnailUrl,
            storyXp: storyXp,
          ),
        );
      },
    );
  }

  // Handles loading, error, empty, and loaded video states.
  Widget _buildVideoContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _videosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Expanded(
            child: Center(
              child: Text(
                'Oops! Could not load videos.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> videos = snapshot.data ?? [];

        if (videos.isEmpty) {
          return Expanded(
            child: Center(
              child: Text(
                'No story videos found.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return Expanded(
          child: _buildVideoGrid(videos),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.movie_filter_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Learning Videos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  onPressed: _refreshVideos,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: RefreshIndicator(
                      color: const Color.fromARGB(255, 124, 58, 237),
                      onRefresh: _refreshVideos,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildCategoryFilter(),
                          _buildVideoContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds one video card in the grid.
  Widget _buildVideoCard({
    required String title,
    required String thumbnailUrl,
    required int storyXp,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                    child: _buildThumbnailImage(thumbnailUrl),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        const Color.fromARGB(255, 124, 58, 237)
                            .withOpacity(0.95),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                _buildStoryXpBadge(storyXp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // XP badge shown under each video title.
  Widget _buildStoryXpBadge(int storyXp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFC107),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color.fromARGB(255, 124, 58, 237),
            size: 17,
          ),
          const SizedBox(width: 4),
          Text(
            '$storyXp XP',
            style: const TextStyle(
              color: Color.fromARGB(255, 124, 58, 237),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Loads thumbnail image or falls back when the thumbnail is missing.
  Widget _buildThumbnailImage(String thumbnailUrl) {
    if (thumbnailUrl.trim().isEmpty) {
      return _buildThumbnailFallback();
    }

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildThumbnailFallback();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          color: Colors.deepPurple.withOpacity(0.1),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.deepPurple,
            ),
          ),
        );
      },
    );
  }

  // Fallback thumbnail when YouTube image cannot load.
  Widget _buildThumbnailFallback() {
    return Container(
      color: Colors.deepPurple.withOpacity(0.1),
      child: const Icon(
        Icons.movie,
        color: Colors.deepPurple,
      ),
    );
  }

  // Adds light cloud and star decorations behind the grid.
  Widget _buildSkyDecorations() {
    return Opacity(
      opacity: 0.2,
      child: Stack(
        children: [
          _skyIcon(Icons.cloud, 80, 30, 60),
          _skyIcon(Icons.star, 150, 300, 20),
          _skyIcon(Icons.cloud, 400, 20, 80),
          _skyIcon(Icons.star, 250, 50, 25),
          _skyIcon(Icons.cloud, 600, 250, 70),
          _skyIcon(Icons.star, 500, 100, 15),
        ],
      ),
    );
  }

  // Places one decoration icon in the background.
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
