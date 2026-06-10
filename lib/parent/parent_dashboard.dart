import 'package:flutter/material.dart';
import 'package:project_1/parent/addnewtaskpage.dart';
import 'package:project_1/parent/all_task_tracking.dart';
import 'package:project_1/parent/parenthub.dart';
import 'package:project_1/parent/all_task_for_verification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _childrenWithTaskCounts = [];

  @override
  void initState() {
    super.initState();

    // Loads the parent dashboard when the screen first opens.
    _fetchChildrenWithTaskCounts();
  }

  // Gets the parent's children and calculates how many submitted tasks
  // are waiting for verification for each child.
  Future<void> _fetchChildrenWithTaskCounts() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Parent is not logged in';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final List<dynamic> childrenData = await _supabase
          .from('child')
          .select('child_id, parent_id, child_name, current_level')
          .eq('parent_id', currentUser.id)
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> finalList = [];

      for (final child in childrenData) {
        final Map<String, dynamic> childMap =
            Map<String, dynamic>.from(child as Map);

        final String childId = _readText(childMap['child_id']);
        final int verifyCount = await _getVerifyTaskCount(
          childId: childId,
          parentId: currentUser.id,
        );

        finalList.add({
          'child_id': childId,
          'parent_id': _readText(childMap['parent_id']),
          'child_name': _readText(
            childMap['child_name'],
            fallback: 'Unknown',
          ),
          'current_level': _readInt(childMap['current_level'], fallback: 1),
          'verify_count': verifyCount,
        });
      }

      if (!mounted) return;

      setState(() {
        _childrenWithTaskCounts = finalList;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  // Counts submitted proof rows from child_task_submissions.
  // The join keeps the count limited to tasks owned by this parent.
  Future<int> _getVerifyTaskCount({
    required String childId,
    required String parentId,
  }) async {
    if (childId.isEmpty || parentId.isEmpty) {
      return 0;
    }

    final List<dynamic> submittedTasks = await _supabase
        .from('child_task_submissions')
        .select('''
          submission_id,
          assigned_tasks!inner (
            parent_id
          )
        ''')
        .eq('child_id', childId)
        .eq('assigned_tasks.parent_id', parentId)
        .eq('review_feedback', 'submitted');

    return submittedTasks.length;
  }

  // Refreshes the child cards after returning from another parent page.
  Future<void> _refreshDashboard() async {
    await _fetchChildrenWithTaskCounts();
  }

  // Safely reads text from Supabase values.
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

  // Safely reads integer values from Supabase data.
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
    const Color primaryPurple = Color(0xFF6200EE);
    const Color lightBlueBackground = Color(0xFFF7F8FC);

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
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: lightBlueBackground,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Parent Dashboard',
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: primaryPurple,
                    size: 26,
                  ),
                  onPressed: _refreshDashboard,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: primaryPurple,
                    size: 28,
                  ),
                  onSelected: (value) {
                    if (value == 'parentHub') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ParentHub(),
                        ),
                      ).then((_) => _refreshDashboard());
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'parentHub',
                      child: Text('Parent Hub'),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2.0),
                child: Container(
                  color: Colors.purple.withOpacity(0.1),
                  height: 2.0,
                ),
              ),
            ),
            body: _buildDashboardBody(primaryPurple),
          ),
        ),
      ),
    );
  }

  // Chooses the correct dashboard view based on loading, error, or child data.
  Widget _buildDashboardBody(Color primaryPurple) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: primaryPurple,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_childrenWithTaskCounts.isEmpty) {
      return const Center(
        child: Text(
          'No child found',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int index = 0; index < _childrenWithTaskCounts.length; index++)
              ...[
                ChildCard(
                  childId: _readText(
                    _childrenWithTaskCounts[index]['child_id'],
                  ),
                  parentId: _readText(
                    _childrenWithTaskCounts[index]['parent_id'],
                  ),
                  name: _readText(
                    _childrenWithTaskCounts[index]['child_name'],
                    fallback: 'Unknown',
                  ),
                  level:
                      'Level ${_childrenWithTaskCounts[index]['current_level']} Explorer',
                  verifyCount: _readInt(
                    _childrenWithTaskCounts[index]['verify_count'],
                    fallback: 0,
                  ),
                  onReturnRefresh: _refreshDashboard,
                ),
                if (index != _childrenWithTaskCounts.length - 1)
                  const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class ChildCard extends StatelessWidget {
  final String childId;
  final String parentId;
  final String name;
  final String level;
  final int verifyCount;
  final Future<void> Function() onReturnRefresh;

  const ChildCard({
    super.key,
    required this.childId,
    required this.parentId,
    required this.name,
    required this.level,
    required this.verifyCount,
    required this.onReturnRefresh,
  });

  // Opens the submitted-task review page for this child.
  void _openVerifyPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TasksOfLeoPage(
          childId: childId,
          childName: name,
        ),
      ),
    ).then((_) => onReturnRefresh());
  }

  // Opens the page where parent can assign a new task.
  void _openAssignPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNewTaskPage(
          childId: childId,
          childName: name,
        ),
      ),
    ).then((_) => onReturnRefresh());
  }

  // Opens the list of all tasks already provided to this child.
  void _openProvidedTasksPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllAssignedTasksPage(
          childId: childId,
          childName: name,
        ),
      ),
    ).then((_) => onReturnRefresh());
  }

  @override
  Widget build(BuildContext context) {
    const Color deepPurple = Color(0xFF6200EE);
    const Color lightPurpleButton = Color(0xFFDCE4FF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.0),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.04),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.0),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2FF).withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openVerifyPage(context);
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text('Verify ($verifyCount)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openAssignPage(context);
                          },
                          icon: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 18,
                          ),
                          label: const Text('Assign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightPurpleButton,
                            foregroundColor: deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _openProvidedTasksPage(context);
                      },
                      icon: const Icon(Icons.bar_chart_rounded, size: 18),
                      label: const Text('Provided Tasks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightPurpleButton.withOpacity(0.7),
                        foregroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
