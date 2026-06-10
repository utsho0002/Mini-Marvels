import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_player_page.dart';

class GamesPage extends StatefulWidget {
  final String childId;

  const GamesPage({
    super.key,
    required this.childId,
  });

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<_GamesPageData> _gamesFuture;
  Timer? _xpCheckTimer;
  bool _isRedirectingHome = false;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _fetchGamesPageData();
    _startXpCheckTimer();
  }

  @override
  void dispose() {
    _xpCheckTimer?.cancel();
    super.dispose();
  }

  void _startXpCheckTimer() {
    _xpCheckTimer?.cancel();

    _xpCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkCurrentXpAndRedirect();
    });
  }

  Future<void> _checkCurrentXpAndRedirect() async {
    if (_isRedirectingHome == true) {
      return;
    }

    final String cleanChildId = widget.childId.trim();

    if (cleanChildId.isEmpty) {
      return;
    }

    try {
      final childData = await _supabase
          .from('child')
          .select('total_xp')
          .eq('child_id', cleanChildId)
          .maybeSingle();

      if (childData == null) {
        return;
      }

      final Map<String, dynamic> childMap =
          Map<String, dynamic>.from(childData);

      final int currentXp = _readInt(childMap['total_xp'], fallback: 0);

      if (currentXp <= 0 && mounted) {
        _isRedirectingHome = true;
        _xpCheckTimer?.cancel();

        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      return;
    }
  }

  Future<_GamesPageData> _fetchGamesPageData() async {
    final String cleanChildId = widget.childId.trim();

    if (cleanChildId.isEmpty) {
      return const _GamesPageData(
        childLevel: 1,
        childXp: 0,
        games: [],
        isBlocked: true,
        blockedTitle: 'Child Not Found',
        blockedMessage: 'Child ID is missing. Please login again.',
      );
    }

    final childData = await _supabase
        .from('child')
        .select(
          'parent_id, current_level, total_xp, games_locked, daily_game_limit_minutes',
        )
        .eq('child_id', cleanChildId)
        .maybeSingle();

    if (childData == null) {
      return const _GamesPageData(
        childLevel: 1,
        childXp: 0,
        games: [],
        isBlocked: true,
        blockedTitle: 'Child Not Found',
        blockedMessage: 'Could not find your profile. Please login again.',
      );
    }

    final Map<String, dynamic> childMap = Map<String, dynamic>.from(childData);

    final String parentId = _readText(childMap['parent_id']);
    final int childLevel = _readInt(childMap['current_level'], fallback: 1);
    final int childXp = _readInt(childMap['total_xp'], fallback: 0);
    final bool gamesLocked = childMap['games_locked'] == true;
    final int dailyLimitMinutes = _readInt(
      childMap['daily_game_limit_minutes'],
      fallback: 60,
    );

    // Parent can lock games for a child directly.
    if (gamesLocked == true) {
      return _GamesPageData(
        childLevel: childLevel,
        childXp: childXp,
        games: const [],
        isBlocked: true,
        blockedTitle: 'Games Locked 🔒',
        blockedMessage: 'Games are locked by your parent. Do your other work!!',
      );
    }

    if (parentId.isNotEmpty) {
      final bool bedtimeIsActive = await _isBedtimeActiveNow(parentId);

      if (bedtimeIsActive == true) {
        return _GamesPageData(
          childLevel: childLevel,
          childXp: childXp,
          games: const [],
          isBlocked: true,
          blockedTitle: 'Bedtime Lock 🌙',
          blockedMessage:
              'It is bedtime now. Games are locked. Do your other work!!',
        );
      }
    }

    if (dailyLimitMinutes > 0) {
      final int usedMinutesToday = await _getTodayUsedGameMinutes(cleanChildId);

      if (usedMinutesToday >= dailyLimitMinutes) {
        return _GamesPageData(
          childLevel: childLevel,
          childXp: childXp,
          games: const [],
          isBlocked: true,
          blockedTitle: 'Daily Limit Over ⏰',
          blockedMessage: 'Your daily limit is over, do your other work!!',
        );
      }
    }

    if (childXp <= 1) {
      return _GamesPageData(
        childLevel: childLevel,
        childXp: childXp,
        games: const [],
        isBlocked: true,
        blockedTitle: 'Earn XP First ⭐',
        blockedMessage: 'You need more XP to play games. Complete tasks first!',
      );
    }

    final List<dynamic> gamesData = await _supabase
        .from('games')
        .select('''
          game_id,
          title,
          game_url,
          thumbnail_url,
          required_level,
          is_active,
          created_at
        ''')
        .eq('is_active', true)
        .order('required_level', ascending: true)
        .order('created_at', ascending: false);

    final List<_GameItem> games = gamesData.map((row) {
      return _GameItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
    }).toList();

    return _GamesPageData(
      childLevel: childLevel,
      childXp: childXp,
      games: games,
      isBlocked: false,
      blockedTitle: '',
      blockedMessage: '',
    );
  }

  Future<void> _refreshGames() async {
    setState(() {
      _gamesFuture = _fetchGamesPageData();
    });
  }

  Future<int> _getTodayUsedGameMinutes(String childId) async {
    final String today = _getTodayDateText();

    final usageData = await _supabase
        .from('child_game_usage')
        .select('used_minutes')
        .eq('child_id', childId)
        .eq('usage_date', today)
        .maybeSingle();

    if (usageData == null) {
      return 0;
    }

    final Map<String, dynamic> usageMap =
        Map<String, dynamic>.from(usageData);

    return _readInt(usageMap['used_minutes'], fallback: 0);
  }

  Future<bool> _isBedtimeActiveNow(String parentId) async {
    final parentData = await _supabase
        .from('parent')
        .select('global_bedtime_enabled, global_bedtime_time')
        .eq('user_id', parentId)
        .maybeSingle();

    if (parentData == null) {
      return false;
    }

    final Map<String, dynamic> parentMap =
        Map<String, dynamic>.from(parentData);

    final bool bedtimeEnabled = parentMap['global_bedtime_enabled'] == true;

    if (bedtimeEnabled == false) {
      return false;
    }

    final String bedtimeText = _readText(parentMap['global_bedtime_time']);
    final int? bedtimeMinutes = _convertDatabaseTimeToMinutes(bedtimeText);

    if (bedtimeMinutes == null) {
      return false;
    }

    final TimeOfDay now = TimeOfDay.now();
    final int nowMinutes = (now.hour * 60) + now.minute;

    return nowMinutes >= bedtimeMinutes;
  }

  String _getTodayDateText() {
    final DateTime now = DateTime.now();

    final String year = now.year.toString().padLeft(4, '0');
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  int? _convertDatabaseTimeToMinutes(String timeText) {
    if (timeText.trim().isEmpty) {
      return null;
    }

    final List<String> parts = timeText.split(':');

    if (parts.length < 2) {
      return null;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return (hour * 60) + minute;
  }

  bool _isValidUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  void _openGame(_GameItem game) {
    if (!_isValidUrl(game.gameUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid game link.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Open the selected game and keep child usage tracking connected.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePlayerPage(
          childId: widget.childId,
          gameUrl: game.gameUrl,
          gameTitle: game.title,
        ),
      ),
    );
  }

  void _showLockedMessage(int requiredLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('This game unlocks at Level $requiredLevel.'),
        backgroundColor: const Color.fromARGB(255, 124, 58, 237),
      ),
    );
  }

  static String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
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
                    Icons.sports_esports_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Kids Games',
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
                  onPressed: _refreshGames,
                  icon: const Icon(Icons.refresh_rounded),
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

                // Soft pattern behind the game cards.
                Opacity(
                  opacity: 0.18,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                    ),
                    itemCount: 60,
                    itemBuilder: (context, index) {
                      return const Icon(
                        Icons.videogame_asset_rounded,
                        color: Colors.white,
                        size: 40,
                      );
                    },
                  ),
                ),

                SafeArea(
                  child: FutureBuilder<_GamesPageData>(
                    future: _gamesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildMessageCard(
                          icon: Icons.error_outline_rounded,
                          title: 'Oops!',
                          message: 'Could not load games. Please try again.',
                          buttonText: 'Try Again',
                          onPressed: _refreshGames,
                        );
                      }

                      final _GamesPageData pageData = snapshot.data ??
                          const _GamesPageData(
                            childLevel: 1,
                            childXp: 0,
                            games: [],
                            isBlocked: false,
                            blockedTitle: '',
                            blockedMessage: '',
                          );

                      if (pageData.isBlocked == true) {
                        return _buildMessageCard(
                          icon: Icons.lock_rounded,
                          title: pageData.blockedTitle,
                          message: pageData.blockedMessage,
                          buttonText: 'Okay',
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        );
                      }

                      if (pageData.games.isEmpty) {
                        return _buildMessageCard(
                          icon: Icons.sports_esports_rounded,
                          title: 'No Games Found',
                          message: 'No games are available right now.',
                          buttonText: 'Refresh',
                          onPressed: _refreshGames,
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildLevelHeader(pageData.childLevel),
                            const SizedBox(height: 16),
                            Expanded(
                              child: GridView.builder(
                                itemCount: pageData.games.length,
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.9,
                                ),
                                itemBuilder: (context, index) {
                                  final _GameItem game = pageData.games[index];

                                  // Level lock stays visible so the child knows what comes next.
                                  final bool isUnlocked =
                                      pageData.childLevel >= game.requiredLevel;

                                  return GestureDetector(
                                    onTap: () {
                                      if (!isUnlocked) {
                                        _showLockedMessage(game.requiredLevel);
                                        return;
                                      }

                                      _openGame(game);
                                    },
                                    child: _buildGameCard(
                                      game: game,
                                      isUnlocked: isUnlocked,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelHeader(int childLevel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
              color: Color(0xFFFFCC33),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color.fromARGB(255, 124, 58, 237),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your Level: $childLevel',
              style: const TextStyle(
                color: Color.fromARGB(255, 124, 58, 237),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.lock_open_rounded,
            color: Color.fromARGB(255, 124, 58, 237),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required _GameItem game,
    required bool isUnlocked,
  }) {
    return Opacity(
      opacity: isUnlocked ? 1 : 0.72,
      child: Stack(
        children: [
          Card(
            elevation: 6,
            shadowColor: Colors.black.withOpacity(0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            color: Colors.white.withOpacity(0.98),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: game.thumbnailUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                game.thumbnailUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultGameIcon();
                                },
                              ),
                            )
                          : _buildDefaultGameIcon(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    game.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color.fromARGB(255, 124, 58, 237),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  isUnlocked
                      ? _buildPlayBadge()
                      : _buildLockedBadge(game.requiredLevel),
                ],
              ),
            ),
          ),
          if (!isUnlocked)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          if (!isUnlocked)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultGameIcon() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 124, 58, 237).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_esports_rounded,
          size: 54,
          color: Color.fromARGB(255, 124, 58, 237),
        ),
      ),
    );
  }

  Widget _buildPlayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            color: Color.fromARGB(255, 124, 58, 237),
            size: 18,
          ),
          SizedBox(width: 4),
          Text(
            'Play Now',
            style: TextStyle(
              color: Color.fromARGB(255, 124, 58, 237),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBadge(int requiredLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            color: Colors.grey.shade700,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            'Level $requiredLevel',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 54,
                color: const Color.fromARGB(255, 124, 58, 237),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color.fromARGB(255, 124, 58, 237),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC33),
                  foregroundColor: const Color.fromARGB(255, 124, 58, 237),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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

class _GameItem {
  final String gameId;
  final String title;
  final String description;
  final String gameUrl;
  final String thumbnailUrl;
  final int requiredLevel;

  const _GameItem({
    required this.gameId,
    required this.title,
    required this.description,
    required this.gameUrl,
    required this.thumbnailUrl,
    required this.requiredLevel,
  });

  factory _GameItem.fromMap(Map<String, dynamic> map) {
    return _GameItem(
      gameId: (map['game_id'] ?? '').toString(),
      title: _readText(map['title'], fallback: 'Fun Game'),
      description: _readText(map['description']),
      gameUrl: _readText(map['game_url']),
      thumbnailUrl: _readText(map['thumbnail_url']),
      requiredLevel: int.tryParse((map['required_level'] ?? 1).toString()) ?? 1,
    );
  }

  static String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }
}

class _GamesPageData {
  final int childLevel;
  final int childXp;
  final List<_GameItem> games;
  final bool isBlocked;
  final String blockedTitle;
  final String blockedMessage;

  const _GamesPageData({
    required this.childLevel,
    required this.childXp,
    required this.games,
    required this.isBlocked,
    required this.blockedTitle,
    required this.blockedMessage,
  });
}