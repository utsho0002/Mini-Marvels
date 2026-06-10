import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_details_page.dart';

class AllTasksPage extends StatefulWidget {
  final String childId;

  const AllTasksPage({
    Key? key,
    required this.childId,
  }) : super(key: key);

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage>
    with SingleTickerProviderStateMixin {
  // Supabase client used to read assigned tasks for the selected child.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mascot image shown at the top of the task page.
  final String tasksMascotUrl =
      'https://png.pngtree.com/png-clipart/20250108/original/pngtree-cute-cartoon-boy-working-on-computer-little-kid-studying-office-work-png-image_19222125.png';

  // Animation controller for the floating mascot effect.
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;

  // Page state for loading, error handling, and task list display.
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();

    // Creates a gentle up-and-down movement for the mascot.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Loads only currently assigned and non-expired tasks for this child.
    _fetchAssignedTasks();
  }

  Future<void> _fetchAssignedTasks() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Expired tasks are not shown to the child.
      final String nowUtc = DateTime.now().toUtc().toIso8601String();

      final List<dynamic> data = await _supabase
          .from('assigned_tasks')
          .select('''
            assigned_task_id,
            child_id,
            task_name,
            task_details,
            reward_xp,
            example_media_url,
            status,
            assigned_date,
            due_date,
            expires_at,
            created_at
          ''')
          .eq('child_id', widget.childId)
          .eq('status', 'assigned')
          .gt('expires_at', nowUtc)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _tasks = data
            .map((task) => Map<String, dynamic>.from(task as Map))
            .toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tasks. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Provides a safe task name if the database value is missing.
  String _getTaskName(Map<String, dynamic> task) {
    return task['task_name']?.toString() ?? 'Untitled Task';
  }

  // Formats the XP reward in a child-friendly way.
  String _getXpAmount(Map<String, dynamic> task) {
    final xp = task['reward_xp'] ?? 0;
    return '+$xp XP';
  }

  // Reads the assigned task ID used for opening the task details page.
  String _getAssignedTaskId(Map<String, dynamic> task) {
    return task['assigned_task_id'].toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          // Uses the actual Android device/emulator width.
          width: MediaQuery.of(context).size.width,
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
              title: const Text(
                "All tasks",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(
                color: Colors.white,
              ),
            ),
            body: Stack(
              children: [
                // Main purple gradient background for the missions screen.
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

                // Decorative clouds and stars placed behind the content.
                _buildSkyDecorations(),

                // Main scrollable task content.
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: AnimatedBuilder(
                            animation: _bounceAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _bounceAnimation.value),
                                child: child,
                              );
                            },
                            child: Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.6),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(tasksMascotUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Text(
                          "Daily Missions (${_tasks.length}) 🎯",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Shows a loading indicator while tasks are being fetched.
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )

                        // Shows a readable error message if Supabase fails.
                        else if (_errorMessage != null)
                          Center(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )

                        // Empty state when no assigned task is available.
                        else if (_tasks.isEmpty)
                          const Center(
                            child: Text(
                              "No tasks assigned yet.",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )

                        // Task list shown after data loads successfully.
                        else
                          Column(
                            children: _tasks.map((task) {
                              final taskName = _getTaskName(task);
                              final xpAmount = _getXpAmount(task);
                              final assignedTaskId = _getAssignedTaskId(task);

                              return _buildTaskCard(
                                taskName: taskName,
                                xpAmount: xpAmount,
                                onSubmit: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TaskDetailsPage(
                                        assignedTaskId: assignedTaskId,
                                        childId: widget.childId,
                                        taskName: taskName,
                                      ),
                                    ),
                                  );

                                  // Refresh the list after a task is submitted.
                                  if (result == true) {
                                    _fetchAssignedTasks();
                                  }
                                },
                              );
                            }).toList(),
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

  // Builds the soft background decorations.
  Widget _buildSkyDecorations() {
    return Stack(
      children: [
        _skyItem(icon: Icons.cloud, top: 80, left: 30, size: 60, opacity: 0.4),
        _skyItem(icon: Icons.cloud, top: 150, left: 280, size: 80, opacity: 0.3),
        _skyItem(icon: Icons.cloud, top: 400, left: -20, size: 100, opacity: 0.3),
        _skyItem(icon: Icons.cloud, top: 600, left: 250, size: 70, opacity: 0.4),
        _skyItem(
          icon: Icons.star_rounded,
          top: 120,
          left: 150,
          size: 24,
          opacity: 0.5,
        ),
        _skyItem(
          icon: Icons.star_rounded,
          top: 250,
          left: 60,
          size: 18,
          opacity: 0.6,
        ),
        _skyItem(
          icon: Icons.star_rounded,
          top: 350,
          left: 320,
          size: 22,
          opacity: 0.4,
        ),
        _skyItem(
          icon: Icons.star_rounded,
          top: 500,
          left: 100,
          size: 16,
          opacity: 0.7,
        ),
        _skyItem(
          icon: Icons.star_rounded,
          top: 750,
          left: 180,
          size: 28,
          opacity: 0.5,
        ),
        _skyItem(
          icon: Icons.star_rounded,
          top: 200,
          left: 400,
          size: 14,
          opacity: 0.6,
        ),
      ],
    );
  }

  // Places one decorative icon at a fixed position on the background.
  Widget _skyItem({
    required IconData icon,
    required double top,
    required double left,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Icon(
        icon,
        color: Colors.white.withOpacity(opacity),
        size: size,
      ),
    );
  }

  // Individual task card with title, XP reward, and details button.
  Widget _buildTaskCard({
    required String taskName,
    required String xpAmount,
    required VoidCallback onSubmit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task title and XP reward badge.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  xpAmount,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Opens the selected task details screen.
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF4C1D95),
                    offset: Offset(0, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  "Task Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}