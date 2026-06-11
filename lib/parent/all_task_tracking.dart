import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllAssignedTasksPage extends StatefulWidget {
  final String? assignedTaskId;
  final String childId;
  final String childName;

  const AllAssignedTasksPage({
    super.key,
    this.assignedTaskId,
    required this.childId,
    required this.childName,
  });

  @override
  State<AllAssignedTasksPage> createState() => _AllAssignedTasksPageState();
}

class _AllAssignedTasksPageState extends State<AllAssignedTasksPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _assignedTasks = [];

  @override
  void initState() {
    super.initState();

    // Loads all tasks assigned to this child when the page opens.
    _fetchAssignedTasks();
  }

  // Fetches assigned tasks for the selected child under the logged-in parent.
  Future<void> _fetchAssignedTasks() async {
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
          .from('assigned_tasks')
          .select('''
            assigned_task_id,
            parent_id,
            child_id,
            task_name,
            task_details,
            reward_xp,
            example_media_url,
            status,
            assigned_date,
            due_date,
            created_at,
            expires_at
          ''')
          .eq('child_id', widget.childId)
          .eq('parent_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _assignedTasks = data
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

  // Splits long task titles so each card stays readable on small screens.
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

  // Converts database status values into parent-friendly labels.
  String _statusText(String status) {
    switch (status) {
      case 'assigned':
        return 'Not Submitted';
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  // Keeps task status reading safe when a row has missing data.
  String _readTaskStatus(Map<String, dynamic> task) {
    final String status = task['status']?.toString().trim() ?? '';

    if (status.isEmpty) {
      return 'assigned';
    }

    return status;
  }

  // Creates today's date in the same format used by assigned_date.
  String _todayDateText() {
    final DateTime now = DateTime.now();

    final String year = now.year.toString().padLeft(4, '0');
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDateOnly(dynamic value) {
    final String rawValue = value?.toString().trim() ?? '';

    if (rawValue.isEmpty) {
      return 'Not set';
    }

    final DateTime? parsedDate = DateTime.tryParse(rawValue);

    if (parsedDate == null) {
      return rawValue.split('T').first;
    }

    final String year = parsedDate.year.toString().padLeft(4, '0');
    final String month = parsedDate.month.toString().padLeft(2, '0');
    final String day = parsedDate.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDateTimeText(dynamic value) {
    final String rawValue = value?.toString().trim() ?? '';

    if (rawValue.isEmpty) {
      return 'Not set';
    }

    final DateTime? parsedDateTime = DateTime.tryParse(rawValue);

    if (parsedDateTime == null) {
      return rawValue;
    }

    final DateTime localDateTime = parsedDateTime.toLocal();

    final String year = localDateTime.year.toString().padLeft(4, '0');
    final String month = localDateTime.month.toString().padLeft(2, '0');
    final String day = localDateTime.day.toString().padLeft(2, '0');

    final int hour = localDateTime.hour;
    final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final String minute = localDateTime.minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';

    return '$year-$month-$day $displayHour:$minute $period';
  }

  String _assignedDateTimeText(Map<String, dynamic> task) {
    final String createdAt = task['created_at']?.toString().trim() ?? '';

    if (createdAt.isNotEmpty) {
      return _formatDateTimeText(createdAt);
    }

    return _formatDateOnly(task['assigned_date']);
  }

  String _expireDateText(Map<String, dynamic> task) {
    final String expiresAt = task['expires_at']?.toString().trim() ?? '';

    if (expiresAt.isNotEmpty) {
      return _formatDateTimeText(expiresAt);
    }

    return _formatDateOnly(task['due_date']);
  }

  // Checks if the task was assigned today.
  bool _isTaskAssignedToday(Map<String, dynamic> task) {
    final String assignedDate = task['assigned_date']?.toString().trim() ?? '';

    if (assignedDate.isEmpty) {
      return false;
    }

    return assignedDate.split('T').first == _todayDateText();
  }

  // Calculates today's total, submitted, not submitted, approved, and rejected counts.
  _TodayTaskSummary _buildTodayTaskSummary() {
    int total = 0;
    int submitted = 0;
    int notSubmitted = 0;
    int approved = 0;
    int rejected = 0;

    for (final task in _assignedTasks) {
      total++;

      final String status = _readTaskStatus(task);

      if (status == 'submitted') {
        submitted++;
      } else if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        notSubmitted++;
      }
    }

    return _TodayTaskSummary(
      total: total,
      submitted: submitted,
      notSubmitted: notSubmitted,
      approved: approved,
      rejected: rejected,
    );
  }

  // Shows today's quick progress numbers above the task list.
  Widget _buildTodaySummarySection({
    required Color primaryPurple,
    required Color textDark,
  }) {
    final _TodayTaskSummary summary = _buildTodayTaskSummary();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "All Task Summary",
            style: TextStyle(
              color: primaryPurple,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All assigned tasks are counted here.',
            style: TextStyle(
              color: textDark.withOpacity(0.65),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(
                label: 'Total',
                count: summary.total,
                backgroundColor: const Color(0xFFEDE9FE),
                textColor: primaryPurple,
              ),
              _SummaryPill(
                label: 'Submitted',
                count: summary.submitted,
                backgroundColor: const Color(0xFFDBEAFE),
                textColor: const Color(0xFF1D4ED8),
              ),
              _SummaryPill(
                label: 'Not Submitted',
                count: summary.notSubmitted,
                backgroundColor: const Color(0xFFFEF3C7),
                textColor: const Color(0xFFB45309),
              ),
              _SummaryPill(
                label: 'Approved',
                count: summary.approved,
                backgroundColor: const Color(0xFFD1FAE5),
                textColor: const Color(0xFF047857),
              ),
              _SummaryPill(
                label: 'Rejected',
                count: summary.rejected,
                backgroundColor: const Color(0xFFFEE2E2),
                textColor: const Color(0xFFB91C1C),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds the page body for loading, error, empty, and task list states.
  Widget _buildBody({
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
      onRefresh: _fetchAssignedTasks,
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
            'Here is what ${widget.childName} needs to do today.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textDark.withOpacity(0.7),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          _buildTodaySummarySection(
            primaryPurple: primaryPurple,
            textDark: textDark,
          ),
          const SizedBox(height: 28),
          if (_assignedTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40.0),
                child: Text(
                  'No assigned tasks found',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            for (int index = 0; index < _assignedTasks.length; index++) ...[
              AssignedTaskRow(
                stepNumber: '${index + 1}',
                taskTitle: _formatTaskTitle(
                  _assignedTasks[index]['task_name']?.toString() ??
                      'Untitled Task',
                ),
                statusText: _statusText(
                  _assignedTasks[index]['status']?.toString() ?? 'assigned',
                ),
                assignedDateTimeText: _assignedDateTimeText(
                  _assignedTasks[index],
                ),
                expireDateText: _expireDateText(
                  _assignedTasks[index],
                ),
              ),
              if (index != _assignedTasks.length - 1)
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
              centerTitle: false,
              titleSpacing: 0,
              title: Text(
                'All Assigned Task for ${widget.childName}',
                style: const TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
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
            body: _buildBody(
              primaryPurple: primaryPurple,
              textDark: textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayTaskSummary {
  final int total;
  final int submitted;
  final int notSubmitted;
  final int approved;
  final int rejected;

  const _TodayTaskSummary({
    required this.total,
    required this.submitted,
    required this.notSubmitted,
    required this.approved,
    required this.rejected,
  });
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color backgroundColor;
  final Color textColor;

  const _SummaryPill({
    required this.label,
    required this.count,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AssignedTaskRow extends StatelessWidget {
  final String stepNumber;
  final String taskTitle;
  final String statusText;
  final String assignedDateTimeText;
  final String expireDateText;

  const AssignedTaskRow({
    super.key,
    required this.stepNumber,
    required this.taskTitle,
    required this.statusText,
    required this.assignedDateTimeText,
    required this.expireDateText,
  });

  // Chooses a soft badge color based on task status.
  Color _statusColor() {
    switch (statusText) {
      case 'Submitted':
        return const Color(0xFF2563EB);
      case 'Approved':
        return const Color(0xFF059669);
      case 'Rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6200EE);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color badgeYellow = Color(0xFFFBBF24);
    const Color textDark = Color(0xFF0F172A);

    final Color statusColor = _statusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.0),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  taskTitle,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _TaskMetaChip(
                icon: Icons.schedule_rounded,
                label: 'Assigned',
                value: assignedDateTimeText,
              ),
              _TaskMetaChip(
                icon: Icons.event_busy_rounded,
                label: 'Expires',
                value: expireDateText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TaskMetaChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF334155);

    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
