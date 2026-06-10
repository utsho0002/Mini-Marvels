import 'package:flutter/material.dart';
import 'package:project_1/parent/taskverificationpage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TasksOfLeoPage extends StatefulWidget {
  final String childId;
  final String childName;

  const TasksOfLeoPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<TasksOfLeoPage> createState() => _TasksOfLeoPageState();
}

class _TasksOfLeoPageState extends State<TasksOfLeoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _submittedTasks = [];

  static const String _submissionTable = 'child_task_submissions';

  @override
  void initState() {
    super.initState();

    // Loads submitted proof rows when the verify page opens.
    _fetchSubmittedTasks();
  }

  // Fetches only submissions that are still waiting for parent review.
  Future<void> _fetchSubmittedTasks() async {
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

      final List<dynamic> data = await _supabase
          .from(_submissionTable)
          .select('''
            submission_id,
            assigned_task_id,
            child_id,
            child_note,
            child_media_url,
            submitted_at,
            reviewed_by_parent_id,
            reviewed_at,
            review_feedback,
            assigned_tasks!inner (
              assigned_task_id,
              parent_id,
              child_id,
              task_name,
              task_details,
              reward_xp,
              example_media_url,
              assigned_date,
              due_date,
              created_at
            )
          ''')
          .eq('child_id', widget.childId)
          .eq('assigned_tasks.parent_id', currentUser.id)
          .eq('review_feedback', 'submitted')
          .order('submitted_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _submittedTasks = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
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

  // Splits long task titles so the card stays neat on small screens.
  String _formatTaskTitle(String title) {
    final words = title.trim().split(RegExp(r'\s+'));

    if (words.length <= 1) {
      return title;
    }

    if (words.length == 2) {
      return '${words[0]}\n${words[1]}';
    }

    final firstLine = words.take(2).join(' ');
    final secondLine = words.skip(2).join(' ');

    return '$firstLine\n$secondLine';
  }

  // Builds the main body based on loading, error, and submission states.
  Widget _buildSubmittedTasksBody({
    required Color primaryPurple,
    required Color textDark,
  }) {
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

    return RefreshIndicator(
      onRefresh: _fetchSubmittedTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 28.0,
        ),
        children: [
          Text(
            'Ready for\nadventure, Super\nParent?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: primaryPurple,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Here is what ${widget.childName} submitted for verification.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textDark.withOpacity(0.7),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 32),
          if (_submittedTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40.0),
                child: Text(
                  'No submitted tasks found',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            for (int index = 0; index < _submittedTasks.length; index++) ...[
              TaskCard(
                stepNumber: '${index + 1}',
                taskTitle: _formatTaskTitle(
                  _submittedTasks[index]['assigned_tasks']?['task_name']
                          ?.toString() ??
                      'Untitled Task',
                ),
                submittedTask: _submittedTasks[index],
                childId: widget.childId,
                childName: widget.childName,
                onTaskUpdated: _fetchSubmittedTasks,
              ),
              if (index != _submittedTasks.length - 1)
                const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6200EE);
    const Color textDark = Color(0xFF1E293B);
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
                icon: const Icon(
                  Icons.arrow_back,
                  color: primaryPurple,
                  size: 26,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              centerTitle: true,
              title: Text(
                'Tasks of ${widget.childName}',
                style: const TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.purple.withOpacity(0.08),
                  height: 1.0,
                ),
              ),
            ),
            body: _buildSubmittedTasksBody(
              primaryPurple: primaryPurple,
              textDark: textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String stepNumber;
  final String taskTitle;
  final Map<String, dynamic> submittedTask;
  final String childId;
  final String childName;
  final Future<void> Function() onTaskUpdated;

  const TaskCard({
    super.key,
    required this.stepNumber,
    required this.taskTitle,
    required this.submittedTask,
    required this.childId,
    required this.childName,
    required this.onTaskUpdated,
  });

  // Opens the selected submission for detailed parent verification.
  Future<void> _openVerificationPage(BuildContext context) async {
    final String submissionId = submittedTask['submission_id'].toString();
    final String assignedTaskId = submittedTask['assigned_task_id'].toString();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskVerificationPage(
          submissionId: submissionId,
          assignedTaskId: assignedTaskId,
          childId: childId,
          childName: childName,
        ),
      ),
    );

    if (result == true) {
      await onTaskUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6200EE);
    const Color badgeYellow = Color(0xFFFBBF24);
    const Color textDark = Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36.0),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: badgeYellow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              taskTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textDark,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                _openVerificationPage(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
