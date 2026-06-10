import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyFeelingsPage extends StatefulWidget {
  final String childId;

  const MyFeelingsPage({
    super.key,
    required this.childId,
  });

  @override
  State<MyFeelingsPage> createState() => _MyFeelingsPageState();
}

class _MyFeelingsPageState extends State<MyFeelingsPage> {
  // Supabase client used for loading and saving the child's mood records.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Optional note field where the child can describe their mood.
  final TextEditingController _noteController = TextEditingController();

  // Page theme colors used for cards, highlights, and the background gradient.
  static const Color mainPurple = Color.fromARGB(255, 124, 58, 237);
  static const Color lightPurple = Color.fromARGB(255, 183, 151, 239);
  static const Color darkPurple = Color.fromARGB(255, 124, 32, 232);
  static const Color xpYellow = Color(0xFFFFCC33);

  // Current mood selection for today's entry.
  String? _selectedEmoji;
  String? _selectedLabel;

  // Loading and saving states for database operations.
  bool _isLoading = true;
  bool _isSaving = false;

  // Stores the visible last 7 days of mood history by date.
  final Map<String, _MoodRecord> _weeklyMoods = {};

  // Mood options shown to the child.
  final List<Map<String, String>> _feelings = const [
    {'emoji': '😄', 'label': 'Happy'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😢', 'label': 'Sad'},
    {'emoji': '😠', 'label': 'Grumpy'},
    {'emoji': '🤩', 'label': 'Excited'},
  ];

  @override
  void initState() {
    super.initState();

    // Load only the latest 7 days when the page opens.
    _loadMoods();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Converts the current date into the app's weekday key for saving.
  String _getTodayDayKey() {
    final int weekday = DateTime.now().weekday;

    switch (weekday) {
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      default:
        return 'sat';
    }
  }

  // Creates the last 7 dates in order from oldest to today.
  List<DateTime> _getLastSevenDays() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startDay = today.subtract(const Duration(days: 6));

    return List.generate(
      7,
      (index) => startDay.add(Duration(days: index)),
    );
  }

  // Creates a stable date key used for the local mood map.
  String _dateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // Reads the local date from a saved created_at value.
  String _dateKeyFromCreatedAt(String? createdAtText) {
    if (createdAtText == null || createdAtText.trim().isEmpty) {
      return '';
    }

    try {
      final DateTime createdAt = DateTime.parse(createdAtText).toLocal();
      return _dateKey(createdAt);
    } catch (_) {
      return '';
    }
  }

  // Short weekday label used in the 7-day mood row.
  String _shortDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      default:
        return '';
    }
  }

  // Short date label used in the saved mood note dialog.
  String _shortDateLabel(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (date.month < 1 || date.month > 12) {
      return _shortDayName(date);
    }

    return '${_shortDayName(date)}, ${months[date.month - 1]} ${date.day}';
  }

  // Returns the short label displayed under the header card.
  String _getTodayLabel() {
    return _shortDayName(DateTime.now());
  }

  // Loads only the last 7 days of mood records in date order.
  Future<void> _loadMoods() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime nowLocal = DateTime.now();
      final DateTime todayStartLocal = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
      );
      final DateTime lastSevenStartLocal =
          todayStartLocal.subtract(const Duration(days: 6));

      final String startUtc = lastSevenStartLocal.toUtc().toIso8601String();
      final String nowUtc = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from('child_moods')
          .select(
            'mood_id, child_id, day_key, emoji, note, created_at, expires_at',
          )
          .eq('child_id', widget.childId)
          .gte('created_at', startUtc)
          .gt('expires_at', nowUtc)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final Map<String, _MoodRecord> loadedMoods = {};

      for (final item in data) {
        final Map<String, dynamic> mood = Map<String, dynamic>.from(item);

        final String emoji = (mood['emoji'] ?? '').toString();
        final String createdAt = mood['created_at']?.toString() ?? '';
        final String dateKey = _dateKeyFromCreatedAt(createdAt);

        if (dateKey.isEmpty || emoji.isEmpty) {
          continue;
        }

        // Later records replace earlier ones for the same date.
        loadedMoods[dateKey] = _MoodRecord(
          dateKey: dateKey,
          dayKey: mood['day_key']?.toString() ?? '',
          emoji: emoji,
          note: mood['note']?.toString(),
          createdAt: createdAt,
          expiresAt: mood['expires_at']?.toString(),
        );
      }

      final String todayKey = _dateKey(DateTime.now());
      final _MoodRecord? todayMood = loadedMoods[todayKey];

      if (!mounted) return;

      setState(() {
        _weeklyMoods
          ..clear()
          ..addAll(loadedMoods);

        if (todayMood != null) {
          _selectedEmoji = todayMood.emoji;
          _selectedLabel = _findLabelByEmoji(todayMood.emoji);
          _noteController.text = todayMood.note ?? '';
        } else {
          _selectedEmoji = null;
          _selectedLabel = null;
          _noteController.clear();
        }

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Mood loading failed: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar(
        message: 'Could not load feelings. Please try again.',
        isError: true,
      );
    }
  }

  // Finds the readable mood label for a saved emoji.
  String? _findLabelByEmoji(String emoji) {
    for (final feeling in _feelings) {
      if (feeling['emoji'] == emoji) {
        return feeling['label'];
      }
    }

    return null;
  }

  // Saves today's mood and keeps it available for seven days.
  Future<void> _saveFeeling() async {
    if (_selectedEmoji == null) {
      _showSnackBar(
        message: 'Please select how you are feeling first!',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime expiresAt = now.add(const Duration(days: 7));
      final String todayDayKey = _getTodayDayKey();
      final String todayDateKey = _dateKey(DateTime.now());

      final String note = _noteController.text.trim();

      // Upsert keeps one mood entry per child per weekday.
      await _supabase.from('child_moods').upsert(
        {
          'child_id': widget.childId,
          'day_key': todayDayKey,
          'emoji': _selectedEmoji,
          'note': note.isEmpty ? null : note,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        },
        onConflict: 'child_id,day_key',
      );

      if (!mounted) return;

      setState(() {
        _weeklyMoods[todayDateKey] = _MoodRecord(
          dateKey: todayDateKey,
          dayKey: todayDayKey,
          emoji: _selectedEmoji!,
          note: note.isEmpty ? null : note,
          createdAt: now.toIso8601String(),
          expiresAt: expiresAt.toIso8601String(),
        );

        _isSaving = false;
      });

      _showSnackBar(
        message: 'Awesome! Your feeling has been saved! 🌟',
        isError: false,
      );
    } catch (error) {
      debugPrint('Mood saving failed: $error');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showSnackBar(
        message: 'Could not save feeling. Please try again.',
        isError: true,
      );
    }
  }

  // Shows quick feedback after loading or saving mood data.
  void _showSnackBar({
    required String message,
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  // Opens a small dialog to show the saved note for a selected day.
  void _showMoodNote(_MoodRecord mood) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '${mood.emoji} ${mood.dateKey} Feeling',
            style: const TextStyle(
              color: mainPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            mood.note == null || mood.note!.trim().isEmpty
                ? 'No note added.'
                : mood.note!,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: mainPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
              ),
            ],
          ),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text(
                'My Feelings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 23,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadMoods,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lightPurple,
                    mainPurple,
                    darkPurple,
                  ],
                  stops: [0.0, 0.58, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  const _BackgroundIcons(),
                  SafeArea(
                    child: _isLoading
                        ? _buildLoadingView()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeaderCard(),
                                const SizedBox(height: 22),
                                _buildFeelingOptions(),
                                const SizedBox(height: 22),
                                _buildNoteBox(),
                                const SizedBox(height: 20),
                                _buildSaveButton(),
                                const SizedBox(height: 30),
                                _buildWeeklySection(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Simple loading view while mood records are being fetched.
  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: xpYellow,
      ),
    );
  }

  // Top card that asks the child to reflect on today's mood.
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'How are you feeling today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: mainPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Today is ${_getTodayLabel()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Builds the selectable mood emoji cards.
  Widget _buildFeelingOptions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 14,
      children: _feelings.map((feeling) {
        final String emoji = feeling['emoji']!;
        final String label = feeling['label']!;
        final bool isSelected = _selectedEmoji == emoji;

        return GestureDetector(
          onTap: _isSaving
              ? null
              : () {
                  setState(() {
                    _selectedEmoji = emoji;
                    _selectedLabel = label;
                  });
                },
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 112,
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? xpYellow : Colors.white.withOpacity(0.5),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: xpYellow.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 38),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                      color: mainPurple,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Optional note input for adding context to the selected mood.
  Widget _buildNoteBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 4,
        enabled: !_isSaving,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Write a small note about your mood...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 8,
              bottom: 68,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              color: mainPurple,
              size: 28,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 20, 18, 20),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // Main action button for saving the selected mood.
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveFeeling,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _isSaving ? 0.7 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: xpYellow,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: xpYellow.withOpacity(0.35),
                offset: const Offset(0, 7),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: mainPurple,
                    ),
                  )
                : Text(
                    _selectedLabel == null
                        ? 'Save My Feeling'
                        : 'Save $_selectedLabel Feeling',
                    style: const TextStyle(
                      color: mainPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Last 7 days summary shown from oldest day to today.
  Widget _buildWeeklySection() {
    final List<DateTime> lastSevenDays = _getLastSevenDays();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Last 7 Days',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: mainPurple,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Moods are shown sequentially from oldest to today.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),

          // This layout keeps the 7-day mood cards safe on small screens.
          // Normal screens show all 7 cards in one row.
          // Small screens wrap the cards into two or three neat rows.
          LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = constraints.maxWidth;

              int cardsPerRow = 7;

              if (availableWidth < 300) {
                cardsPerRow = 3;
              } else if (availableWidth < 380) {
                cardsPerRow = 4;
              }

              const double spacing = 8;
              final double totalSpacing = spacing * (cardsPerRow - 1);
              final double cardWidth =
                  (availableWidth - totalSpacing) / cardsPerRow;

              return Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: 10,
                children: lastSevenDays.map((date) {
                  final String dateKey = _dateKey(date);
                  final _MoodRecord? mood = _weeklyMoods[dateKey];

                  final bool hasData = mood != null;
                  final bool isToday = dateKey == _dateKey(DateTime.now());

                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: hasData ? () => _showMoodNote(mood) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasData
                              ? lightPurple.withOpacity(0.23)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isToday ? xpYellow : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _shortDayName(date),
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: hasData ? mainPurple : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                date.day.toString(),
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: hasData ? mainPurple : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                hasData ? mood.emoji : '—',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: hasData ? 24 : 20,
                                  color: hasData ? Colors.black : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  }

// Local model for one saved mood entry.
class _MoodRecord {
  final String dateKey;
  final String dayKey;
  final String emoji;
  final String? note;
  final String? createdAt;
  final String? expiresAt;

  const _MoodRecord({
    required this.dateKey,
    required this.dayKey,
    required this.emoji,
    this.note,
    this.createdAt,
    this.expiresAt,
  });
}

// Soft decorative icons painted behind the feelings content.
class _BackgroundIcons extends StatelessWidget {
  const _BackgroundIcons();

  @override
  Widget build(BuildContext context) {
    final List<IconData> icons = [
      Icons.sentiment_satisfied_alt_rounded,
      Icons.sentiment_very_satisfied_rounded,
      Icons.favorite_border_rounded,
      Icons.star_border_rounded,
      Icons.auto_awesome_rounded,
      Icons.cloud_rounded,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final Random random = Random(42);

        return Stack(
          children: List.generate(28, (index) {
            final double top = random.nextDouble() * constraints.maxHeight;
            final double left = random.nextDouble() * constraints.maxWidth;
            final double size = random.nextDouble() * 34 + 18;
            final IconData icon = icons[random.nextInt(icons.length)];

            return Positioned(
              top: top,
              left: left,
              child: Opacity(
                opacity: 0.13,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: size,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
