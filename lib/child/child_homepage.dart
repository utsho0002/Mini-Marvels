import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'all_tasks_page.dart';
import 'All Video Feature/all_videos_page.dart';
import 'my_feelings_page.dart';
import 'games_page.dart';

class ChildHomepage extends StatefulWidget {
  final String childId;

  const ChildHomepage({
    super.key,
    required this.childId,
  });

  @override
  State<ChildHomepage> createState() => _ChildHomepageState();
}

class _ChildHomepageState extends State<ChildHomepage>
    with SingleTickerProviderStateMixin {
  // Supabase client. We use this to get child profile, XP, level,
  // and game lock information from the database.
  final SupabaseClient supabase = Supabase.instance.client;

  // Main colors of this child homepage.
  // Keeping these colors same so the design does not change.
  static const Color mainPurple = Color.fromARGB(255, 124, 58, 237);
  static const Color lightPurple = Color.fromARGB(255, 183, 151, 239);
  static const Color darkPurple = Color.fromARGB(255, 124, 32, 232);
  static const Color xpYellow = Color(0xFFFFCC33);

  // This image will show if the child has no avatar in the database.
  final String defaultAvatar =
      'https://tse4.mm.bing.net/th/id/OIP.UTjjIeKVsAr1Ti9tp1fEeQHaHa?cb=thfvnextfalcon&rs=1&pid=ImgDetMain&o=7&rm=3';

  // These two are used for the small up-down animation of the avatar.
  late AnimationController animationController;
  late Animation<double> bounceAnimation;

  // Child information shown in the top white profile card.
  String childName = 'Hero';
  String? childAvatarUrl;
  int totalXp = 0;
  int currentLevel = 1;

  // This is true while child data is loading from Supabase.
  bool isLoading = true;

  // This stops the Games button from being clicked many times quickly.
  bool isCheckingGameAccess = false;

  @override
  void initState() {
    super.initState();

    // Start a soft bounce animation for the child avatar.
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    bounceAnimation = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(animationController);

    // Load child data as soon as this page opens.
    fetchChildData();
  }

  Future<void> fetchChildData() async {
    String childId = widget.childId.trim();

    // If childId is empty, we cannot search the child in Supabase.
    if (childId.isEmpty) {
      setState(() {
        isLoading = false;
      });

      showMessage('Child ID is missing.', Colors.redAccent);
      return;
    }

    try {
      // Get this child's full profile from the child table.
      final data = await supabase
          .from('child')
          .select()
          .eq('child_id', childId)
          .maybeSingle();

      if (!mounted) return;

      // If no child is found, keep default values and show a message.
      if (data == null) {
        setState(() {
          childName = 'Hero';
          childAvatarUrl = null;
          totalXp = 0;
          currentLevel = 1;
          isLoading = false;
        });

        showMessage('No child found for this ID.', Colors.redAccent);
        return;
      }

      // Read XP and level safely from the database.
      int fetchedXp = readInt(data['total_xp'], 0);
      int fetchedLevel = readInt(
        data['current_level'],
        calculateLevel(fetchedXp),
      );

      // Update the screen with child information.
      setState(() {
        childName = readText(data['child_name'], 'Hero');
        childAvatarUrl = readNullableText(data['avatar_url']);
        totalXp = fetchedXp;
        currentLevel = fetchedLevel;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to fetch child data.', Colors.redAccent);
    }
  }

  Future<void> openGamesPage() async {
    // If checking is already running, do not start again.
    if (isCheckingGameAccess) return;

    String childId = widget.childId.trim();

    if (childId.isEmpty) {
      showMessage('Child ID is missing.', Colors.redAccent);
      return;
    }

    setState(() {
      isCheckingGameAccess = true;
    });

    try {
      // First check the child's game settings.
      // We need parent_id because bedtime settings are stored under parent.
      final childData = await supabase
          .from('child')
          .select('parent_id, total_xp, games_locked, daily_game_limit_minutes')
          .eq('child_id', childId)
          .maybeSingle();

      if (childData == null) {
        showBlockedDialog(
          'Child Not Found',
          'Could not find your profile. Please login again.',
        );
        return;
      }

      bool gamesLocked = childData['games_locked'] == true;
      String parentId = readText(childData['parent_id'], '');
      int dailyLimit = readInt(childData['daily_game_limit_minutes'], 60);
      int currentXp = readInt(childData['total_xp'], 0);

      // If parent manually locked games, child cannot open games.
      if (gamesLocked) {
        showBlockedDialog(
          'Games Locked 🔒',
          'Games are locked by your parent. Do your other work!!',
        );
        return;
      }

      // Check bedtime lock only if parentId exists.
      if (parentId.isNotEmpty) {
        bool bedtimeActive = await isBedtimeActive(parentId);

        if (bedtimeActive) {
          showBlockedDialog(
            'Bedtime Lock 🌙',
            'It is bedtime now. Games are locked. Do your other work!!',
          );
          return;
        }
      }

      // If daily limit is greater than 0, check today's used game time.
      // If daily limit is 0, we treat it as no limit.
      if (dailyLimit > 0) {
        int usedMinutes = await getTodayUsedGameMinutes(childId);

        if (usedMinutes >= dailyLimit) {
          showBlockedDialog(
            'Daily Limit Over ⏰',
            'Your daily limit is over, do your other work!!',
          );
          return;
        }
      }

      if (currentXp <= 1) {
        showBlockedDialog(
          'Earn XP First ⭐',
          'You need more XP to play games. Complete tasks first!',
        );
        return;
      }

      // If everything is okay, open the games page.
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GamesPage(
            childId: widget.childId,
          ),
        ),
      );
    } catch (error) {
      showMessage(
        'Could not check game access. Please try again.',
        Colors.redAccent,
      );
    } finally {
      // Turn off checking state when work is done.
      if (mounted) {
        setState(() {
          isCheckingGameAccess = false;
        });
      }
    }
  }

  Future<bool> isBedtimeActive(String parentId) async {
    // Read bedtime setting from the parent table.
    final parentData = await supabase
        .from('parent')
        .select('global_bedtime_enabled, global_bedtime_time')
        .eq('user_id', parentId)
        .maybeSingle();

    if (parentData == null) return false;

    bool bedtimeEnabled = parentData['global_bedtime_enabled'] == true;

    if (!bedtimeEnabled) return false;

    String bedtimeText = readText(parentData['global_bedtime_time'], '');

    if (bedtimeText.isEmpty) return false;

    // Supabase time usually looks like this: 20:00:00
    List<String> timeParts = bedtimeText.split(':');

    if (timeParts.length < 2) return false;

    int hour = int.tryParse(timeParts[0]) ?? -1;
    int minute = int.tryParse(timeParts[1]) ?? -1;

    if (hour < 0 || minute < 0) return false;

    int bedtimeMinutes = hour * 60 + minute;

    TimeOfDay now = TimeOfDay.now();
    int nowMinutes = now.hour * 60 + now.minute;

    // If current time is after bedtime, games should be blocked.
    return nowMinutes >= bedtimeMinutes;
  }

  Future<int> getTodayUsedGameMinutes(String childId) async {
    // Read how many minutes this child already played today.
    final usageData = await supabase
        .from('child_game_usage')
        .select('used_minutes')
        .eq('child_id', childId)
        .eq('usage_date', getTodayDate())
        .maybeSingle();

    if (usageData == null) return 0;

    return readInt(usageData['used_minutes'], 0);
  }

  String getTodayDate() {
    // Make today's date in database-friendly format: yyyy-mm-dd
    DateTime now = DateTime.now();

    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String readText(dynamic value, String defaultValue) {
    // This helper avoids null or empty text problems.
    if (value == null) return defaultValue;

    String text = value.toString().trim();

    if (text.isEmpty) return defaultValue;

    return text;
  }

  String? readNullableText(dynamic value) {
    // This helper is used for optional text like avatar URL.
    if (value == null) return null;

    String text = value.toString().trim();

    if (text.isEmpty) return null;

    return text;
  }

  int readInt(dynamic value, int defaultValue) {
    // Supabase can sometimes return numbers as int or text.
    // This safely converts the value to int.
    if (value == null) return defaultValue;

    return int.tryParse(value.toString()) ?? defaultValue;
  }

  int getSafeXp() {
    // XP should never show as negative.
    if (totalXp < 0) return 0;
    return totalXp;
  }

  int calculateLevel(int xp) {
    // Every 1000 XP means one new level.
    if (xp < 0) xp = 0;
    return (xp ~/ 1000) + 1;
  }

  int getCurrentLevel() {
    // Use the higher level between database level and XP calculated level.
    int xpLevel = calculateLevel(getSafeXp());

    if (currentLevel < xpLevel) {
      return xpLevel;
    }

    if (currentLevel < 1) {
      return 1;
    }

    return currentLevel;
  }

  int getNextLevelTargetXp() {
    // Level 1 needs 1000 XP, level 2 needs 2000 XP, and so on.
    return getCurrentLevel() * 1000;
  }

  double getLevelProgress() {
    // This gives the progress bar value between 0 and 1.
    int safeXp = getSafeXp();
    int targetXp = getNextLevelTargetXp();

    if (targetXp <= 0) return 0;

    double progress = safeXp / targetXp;

    if (progress > 1) return 1;
    if (progress < 0) return 0;

    return progress;
  }

  int getXpLeft() {
    // Shows how much XP is needed for the next level.
    int left = getNextLevelTargetXp() - getSafeXp();

    if (left < 0) return 0;

    return left;
  }

  void showMessage(String message, Color color) {
    // Small floating message at the bottom of the screen.
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void showBlockedDialog(String title, String message) {
    // Child-friendly popup when games are not allowed.
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: darkPurple,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Okay',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkPurple,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Always close animation controller when leaving the page.
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          // Full device screen size.
          width: screenSize.width,
          height: screenSize.height,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Scaffold(
            body: Stack(
              children: [
                // Purple background gradient.
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lightPurple,
                        mainPurple,
                        darkPurple,
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                ),

                // Light background icons for a playful look.
                Opacity(
                  opacity: 0.12,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 25,
                    ),
                    itemCount: 40,
                    itemBuilder: (context, index) {
                      List<IconData> skyIcons = [
                        Icons.cloud,
                        Icons.star_rounded,
                        Icons.cloud_queue,
                        Icons.star,
                      ];

                      IconData currentIcon = skyIcons[index % skyIcons.length];

                      double iconSize = 20;

                      if (currentIcon == Icons.cloud ||
                          currentIcon == Icons.cloud_queue) {
                        iconSize = 42;
                      }

                      return Icon(
                        currentIcon,
                        color: Colors.white,
                        size: iconSize,
                      );
                    },
                  ),
                ),

                // Main content area.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildHeroHeader(),
                        const SizedBox(height: 32),
                        const Text(
                          "Your Adventure Map",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: buildTaskGrid(),
                        ),
                      ],
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

  Widget buildHeroHeader() {
    String imageToShow = defaultAvatar;

    // If the child has a saved avatar, show that instead of default avatar.
    if (childAvatarUrl != null && childAvatarUrl!.isNotEmpty) {
      imageToShow = childAvatarUrl!;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: darkPurple.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated avatar on the left side.
          AnimatedBuilder(
            animation: bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, bounceAnimation.value),
                child: child,
              );
            },
            child: Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: xpYellow,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: xpYellow.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  imageToShow,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      size: 45,
                      color: xpYellow,
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Child name, level, and XP details.
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: mainPurple,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, $childName!",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: xpYellow.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Level ${getCurrentLevel()} Hero ⭐️",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: darkPurple,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: getLevelProgress(),
                          minHeight: 12,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            xpYellow,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Next: Level ${getCurrentLevel() + 1}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            "${getSafeXp()} / ${getNextLevelTargetXp()} XP",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: mainPurple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "${getXpLeft()} XP left to level up",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildTaskGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        buildTaskCard(
          title: "All Tasks",
          imageUrl:
              "https://static.vecteezy.com/system/resources/thumbnails/022/597/166/small/3d-online-shop-png.png",
          accentColor: mainPurple,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllTasksPage(
                  childId: widget.childId,
                ),
              ),
            );

            // Refresh profile because XP may change after completing tasks.
            fetchChildData();
          },
        ),

        buildTaskCard(
          title: "Learning Videos",
          imageUrl:
              "https://w7.pngwing.com/pngs/116/159/png-transparent-video-blue-box-interactive-animation-video-icon-angle-text-rectangle.png",
          accentColor: lightPurple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllVideosPage(
                  childId: widget.childId,
                ),
              ),
            );
          },
        ),

        buildTaskCard(
          title: "Games",
          imageUrl:
              "https://static.vecteezy.com/system/resources/previews/051/718/916/non_2x/3d-blue-game-controller-on-transparent-background-free-png.png",
          accentColor: xpYellow,
          onTap: () {
            openGamesPage();
          },
        ),

        buildTaskCard(
          title: "My Feelings",
          imageUrl:
              "https://static.vecteezy.com/system/resources/thumbnails/070/175/415/small/six-colorful-3d-emoticons-displaying-various-emotions-on-transparent-background-png.png",
          accentColor: darkPurple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyFeelingsPage(
                  childId: widget.childId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildTaskCard({
    required String title,
    required String imageUrl,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.25),
              offset: const Offset(0, 10),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top image section of each card.
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: accentColor,
                      );
                    },
                  ),
                ),
              ),
            ),

            // Card title section.
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
