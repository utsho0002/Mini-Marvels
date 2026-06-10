import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameLimitsPage extends StatefulWidget {
  const GameLimitsPage({super.key});

  @override
  State<GameLimitsPage> createState() => _GameLimitsPageState();
}

class _GameLimitsPageState extends State<GameLimitsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String errorMessage = '';

  List<Map<String, dynamic>> children = [];

  Map<String, TextEditingController> limitControllers = {};
  Map<String, bool> savingStatus = {};

  bool globalBedtimeEnabled = false;
  TimeOfDay globalBedtimeTime = const TimeOfDay(hour: 20, minute: 0);
  bool isSavingBedtime = false;

  final Color primaryPurple = const Color(0xFF6200EE);
  final Color textDark = const Color(0xFF1E293B);
  final Color lightBlueBackground = const Color(0xFFF7F8FC);
  final Color badgeYellow = const Color(0xFFF59E0B);

  // Loads saved game rules when the page opens.
  @override
  void initState() {
    super.initState();
    fetchPageData();
  }

  // Clears text controllers created for each child.
  @override
  void dispose() {
    for (var controller in limitControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // Loads parent bedtime settings and child game limits together.
  Future<void> fetchPageData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          errorMessage = 'Parent is not logged in.';
          isLoading = false;
        });
        return;
      }

      await fetchParentBedtime(user.id);
      await fetchChildren(user.id);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Gets the parent's global bedtime lock setting.
  Future<void> fetchParentBedtime(String parentId) async {
    final response = await supabase
        .from('parent')
        .select('global_bedtime_enabled, global_bedtime_time')
        .eq('user_id', parentId)
        .maybeSingle();

    if (response == null) {
      globalBedtimeEnabled = false;
      globalBedtimeTime = const TimeOfDay(hour: 20, minute: 0);
      return;
    }

    globalBedtimeEnabled = response['global_bedtime_enabled'] == true;

    String? timeText = response['global_bedtime_time']?.toString();

    if (timeText != null && timeText.isNotEmpty) {
      TimeOfDay? convertedTime = convertDatabaseTimeToTimeOfDay(timeText);

      if (convertedTime != null) {
        globalBedtimeTime = convertedTime;
      }
    }
  }

  // Gets all children and prepares their limit input fields.
  Future<void> fetchChildren(String parentId) async {
    final response = await supabase
        .from('child')
        .select(
          'child_id, child_name, total_xp, current_level, daily_game_limit_minutes, games_locked',
        )
        .eq('parent_id', parentId)
        .order('created_at', ascending: true);

    for (var controller in limitControllers.values) {
      controller.dispose();
    }

    limitControllers.clear();
    savingStatus.clear();

    List<Map<String, dynamic>> loadedChildren = [];

    for (var item in response) {
      Map<String, dynamic> child = Map<String, dynamic>.from(item);

      String childId = child['child_id'].toString();

      int limit = 60;

      if (child['daily_game_limit_minutes'] != null) {
        limit = int.tryParse(
              child['daily_game_limit_minutes'].toString(),
            ) ??
            60;
      }

      child['daily_game_limit_minutes'] = limit;
      child['games_locked'] = child['games_locked'] == true;

      limitControllers[childId] = TextEditingController(
        text: limit.toString(),
      );

      savingStatus[childId] = false;

      loadedChildren.add(child);
    }

    children = loadedChildren;
  }

  // Saves daily game limit and lock status for one child.
  Future<void> saveChildLimit(Map<String, dynamic> child) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('Parent is not logged in.');
      return;
    }

    String childId = child['child_id'].toString();

    String limitText = limitControllers[childId]!.text.trim();

    int? limitValue = int.tryParse(limitText);

    if (limitValue == null) {
      showMessage('Please enter a valid number.');
      return;
    }

    if (limitValue < 0 || limitValue > 1440) {
      showMessage('Limit must be between 0 and 1440 minutes.');
      return;
    }

    bool isLocked = child['games_locked'] == true;

    setState(() {
      savingStatus[childId] = true;
    });

    try {
      await supabase.from('child').update({
        'daily_game_limit_minutes': limitValue,
        'games_locked': isLocked,
      }).eq('child_id', childId).eq('parent_id', user.id);

      setState(() {
        child['daily_game_limit_minutes'] = limitValue;
      });

      showMessage('${child['child_name']} game limit updated.');
    } catch (e) {
      showMessage('Failed to update: $e');
    }

    setState(() {
      savingStatus[childId] = false;
    });
  }

  // Saves the global bedtime lock for all children under this parent.
  Future<void> saveBedtimeOnly(bool enabled, TimeOfDay time) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('Parent is not logged in.');
      return;
    }

    setState(() {
      isSavingBedtime = true;
    });

    try {
      await supabase.from('parent').update({
        'global_bedtime_enabled': enabled,
        'global_bedtime_time': convertTimeOfDayToDatabaseTime(time),
      }).eq('user_id', user.id);

      setState(() {
        globalBedtimeEnabled = enabled;
        globalBedtimeTime = time;
      });

      if (enabled == true) {
        showMessage('Bedtime lock enabled.');
      } else {
        showMessage('Bedtime lock disabled.');
      }
    } catch (e) {
      showMessage('Failed to update bedtime: $e');
    }

    setState(() {
      isSavingBedtime = false;
    });
  }

  // Lets the parent enable bedtime lock and choose the first time.
  Future<void> enableBedtimeAndPickTime() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: globalBedtimeTime,
    );

    if (pickedTime == null) {
      return;
    }

    await saveBedtimeOnly(true, pickedTime);
  }

  // Lets the parent update the bedtime lock time.
  Future<void> changeBedtimeTime() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: globalBedtimeTime,
    );

    if (pickedTime == null) {
      return;
    }

    await saveBedtimeOnly(globalBedtimeEnabled, pickedTime);
  }

  // Converts Flutter time into database time text.
  String convertTimeOfDayToDatabaseTime(TimeOfDay time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  // Converts database time text back into Flutter TimeOfDay.
  TimeOfDay? convertDatabaseTimeToTimeOfDay(String timeText) {
    List<String> parts = timeText.split(':');

    if (parts.length < 2) {
      return null;
    }

    int? hour = int.tryParse(parts[0]);
    int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  // Formats bedtime in a parent-friendly 12-hour style.
  String showTimeText(TimeOfDay time) {
    int hour = time.hourOfPeriod;

    if (hour == 0) {
      hour = 12;
    }

    String minute = time.minute.toString().padLeft(2, '0');
    String period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // Shows short messages after saving or loading actions.
  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Loading view while game limit data is being fetched.
  Widget buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        color: primaryPurple,
      ),
    );
  }

  // Error view with retry button when loading fails.
  Widget buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textDark.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: fetchPageData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty view shown when this parent has no child profile yet.
  Widget buildNoChildFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Icon(
            Icons.child_care,
            color: primaryPurple,
            size: 50,
          ),
          const SizedBox(height: 14),
          const Text(
            'No child found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please add a child first. Then you can manage game limits here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textDark.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  // Builds one child card with game limit and lock controls.
  Widget buildChildCard(Map<String, dynamic> child) {
    String childId = child['child_id'].toString();

    bool isSaving = savingStatus[childId] == true;
    bool isLocked = child['games_locked'] == true;

    int limit = int.tryParse(
          child['daily_game_limit_minutes'].toString(),
        ) ??
        60;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: primaryPurple.withOpacity(0.12),
                child: Text(
                  child['child_name'].toString().isEmpty
                      ? '?'
                      : child['child_name'].toString()[0].toUpperCase(),
                  style: TextStyle(
                    color: primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child['child_name'].toString(),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        smallBadge(
                          'Level ${child['current_level'] ?? 1}',
                          Icons.workspace_premium,
                        ),
                        const SizedBox(width: 8),
                        smallBadge(
                          '${child['total_xp'] ?? 0} XP',
                          Icons.star,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isLocked ? Colors.redAccent : badgeYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLocked ? 'Games Locked' : 'Active Limit',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    color: primaryPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Daily Game Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Text(
                '$limit mins',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: limitControllers[childId],
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F4FA),
              suffixText: 'mins',
              suffixStyle: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              hintText: 'Example: 60',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFDCE2EE),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: primaryPurple,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use 0 if you want no daily limit.',
            style: TextStyle(
              color: textDark.withOpacity(0.55),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock : Icons.lock_open,
                  color: primaryPurple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isLocked ? 'Games are locked' : 'Games are unlocked',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch(
                  value: isLocked,
                  activeColor: Colors.white,
                  activeTrackColor: primaryPurple,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.black26,
                  onChanged: (value) {
                    setState(() {
                      child['games_locked'] = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () {
                      saveChildLimit(child);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryPurple.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Limits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Small label used for child level and XP.
  Widget smallBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: primaryPurple,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Builds the global bedtime lock card.
  Widget buildBedtimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FA),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: primaryPurple.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: Color(0xFF78350F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bedtime Lock',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      globalBedtimeEnabled
                          ? 'Games will lock after ${showTimeText(globalBedtimeTime)}'
                          : 'Turn on to lock games after bedtime',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: textDark.withOpacity(0.65),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: globalBedtimeEnabled,
                activeColor: Colors.white,
                activeTrackColor: primaryPurple,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black12,
                onChanged: isSavingBedtime
                    ? null
                    : (value) async {
                        if (value == true) {
                          await enableBedtimeAndPickTime();
                        } else {
                          await saveBedtimeOnly(false, globalBedtimeTime);
                        }
                      },
              ),
            ],
          ),
          if (globalBedtimeEnabled == true) const SizedBox(height: 18),
          if (globalBedtimeEnabled == true)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: isSavingBedtime ? null : changeBedtimeTime,
                icon: isSavingBedtime
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryPurple,
                        ),
                      )
                    : Icon(
                        Icons.schedule,
                        color: primaryPurple,
                      ),
                label: Text(
                  'Change Bedtime: ${showTimeText(globalBedtimeTime)}',
                  style: TextStyle(
                    color: primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: primaryPurple.withOpacity(0.35),
                    width: 1.4,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Chooses the correct content for loading, error, empty, or loaded state.
  Widget buildMainContent() {
    if (isLoading) {
      return buildLoading();
    }

    if (errorMessage.isNotEmpty) {
      return buildError();
    }

    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: fetchPageData,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 28,
        ),
        children: [
          const Text(
            'Game Limits',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage screen time, game access, and bedtime lock for your children.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textDark.withOpacity(0.7),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 28),
          if (children.isEmpty)
            buildNoChildFound()
          else
            for (var child in children) buildChildCard(child),
          const SizedBox(height: 26),
          buildBedtimeCard(),
          const SizedBox(height: 30),
        ],
      ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: lightBlueBackground,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: primaryPurple,
                  size: 26,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: Text(
                'Parent Hub',
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: fetchPageData,
                  icon: Icon(
                    Icons.refresh,
                    color: primaryPurple,
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.purple.withOpacity(0.08),
                  height: 1,
                ),
              ),
            ),
            body: buildMainContent(),
          ),
        ),
      ),
    );
  }
}
