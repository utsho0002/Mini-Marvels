import 'package:flutter/material.dart';
import 'package:project_1/parent/all_task_tracking.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class TaskVerificationPage extends StatefulWidget {
  final String childId;
  final String childName;
  final String assignedTaskId;
  final String submissionId;

  const TaskVerificationPage({
    super.key,
    required this.childId,
    required this.childName,
    required this.assignedTaskId,
    required this.submissionId,
  });

  @override
  State<TaskVerificationPage> createState() => _TaskVerificationPageState();
}

class _TaskVerificationPageState extends State<TaskVerificationPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _taskMediaBucket = 'task-media';

  Map<String, dynamic>? _submissionData;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVerificationDetails();
  }

  // Loads the submitted task, task details, and proof media for review.
  Future<void> _fetchVerificationDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await _supabase
          .from('child_task_submissions')
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
          .eq('submission_id', widget.submissionId)
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _submissionData = null;
          _isLoading = false;
          _errorMessage = 'Submitted task not found.';
        });
        return;
      }

      final Map<String, dynamic> submissionMap =
          Map<String, dynamic>.from(data);

      final String? rawChildMedia =
          submissionMap['child_media_url']?.toString();

      if (rawChildMedia != null && rawChildMedia.trim().isNotEmpty) {
        try {
          final String? preparedUrl = await _prepareStorageUrl(rawChildMedia);
          submissionMap['prepared_child_media_url'] = preparedUrl;
        } catch (error) {
          debugPrint('Child submission media prepare failed: $error');
          submissionMap['prepared_child_media_url'] = null;
        }
      } else {
        submissionMap['prepared_child_media_url'] = null;
      }

      if (!mounted) return;

      setState(() {
        _submissionData = submissionMap;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load submitted task. Please try again.';
      });

      _showSnackBar(
        'Failed to load submitted task: $error',
        Colors.redAccent,
      );
    }
  }

  // Reads the assigned task data joined with this submission.
  Map<String, dynamic> getAssignedTask() {
    final dynamic taskValue = _submissionData?['assigned_tasks'];

    if (taskValue is Map) {
      return Map<String, dynamic>.from(taskValue);
    }

    if (taskValue is List && taskValue.isNotEmpty && taskValue.first is Map) {
      return Map<String, dynamic>.from(taskValue.first as Map);
    }

    return <String, dynamic>{};
  }

  // Keeps a safe child name for labels on this page.
  String getChildName() {
    if (widget.childName.trim().isNotEmpty) {
      return widget.childName.trim();
    }

    return 'Child';
  }

  // Gets the task title shown in the review card.
  String getTaskName() {
    final Map<String, dynamic> task = getAssignedTask();
    final String? taskName = task['task_name']?.toString();

    if (taskName != null && taskName.trim().isNotEmpty) {
      return taskName.trim();
    }

    return 'Submitted Task';
  }

  // Shows the child's note, or a default message if it is empty.
  String getChildNote() {
    final String? note = _submissionData?['child_note']?.toString();

    if (note != null && note.trim().isNotEmpty) {
      return '"${note.trim()}"';
    }

    return 'No message was added by the child.';
  }

  // Reads the XP reward from the assigned task.
  int getRewardXp() {
    final Map<String, dynamic> task = getAssignedTask();
    final dynamic value = task['reward_xp'];

    return _parseIntValue(value);
  }

  // Reads the current parent review result.
  String getReviewFeedback() {
    final String? feedback = _submissionData?['review_feedback']?.toString();

    if (feedback == null || feedback.trim().isEmpty) {
      return 'pending';
    }

    return feedback.trim();
  }

  // Stops approve or reject from running twice on the same submission.
  bool isAlreadyReviewed() {
    final String? reviewedAt = _submissionData?['reviewed_at']?.toString();
    final String feedback = getReviewFeedback();

    return (reviewedAt != null && reviewedAt.trim().isNotEmpty) ||
        feedback == 'approved' ||
        feedback == 'not-approved';
  }

  // Converts the stored review value into a simple status label.
  String getReviewStatusText() {
    final String feedback = getReviewFeedback();

    if (feedback == 'approved') {
      return 'Status: approved';
    }

    if (feedback == 'not-approved') {
      return 'Status: not-approved';
    }

    return 'Status: pending';
  }

  // Formats the child's submission time for the review card.
  String getSubmittedTimeText() {
    final String? submittedAtText = _submissionData?['submitted_at']?.toString();

    if (submittedAtText == null || submittedAtText.trim().isEmpty) {
      return '';
    }

    try {
      final DateTime submittedAt = DateTime.parse(submittedAtText).toLocal();
      final DateTime now = DateTime.now();

      final bool isToday = submittedAt.year == now.year &&
          submittedAt.month == now.month &&
          submittedAt.day == now.day;

      final String hourMinute = _formatTime(submittedAt);

      if (isToday) {
        return 'Today, $hourMinute';
      }

      return '${_monthName(submittedAt.month)} ${submittedAt.day}, $hourMinute';
    } catch (_) {
      return '';
    }
  }

  // Converts a DateTime into a readable 12-hour time.
  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final int minute = dateTime.minute;

    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }

    final String minuteText = minute.toString().padLeft(2, '0');

    return '$hour:$minuteText $period';
  }

  // Returns a short month name for older submissions.
  String _monthName(int month) {
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

    if (month < 1 || month > 12) return '';

    return months[month - 1];
  }

  // Fallback image used when proof media is missing or cannot load.
  String getFallbackEvidencePhoto() {
    return 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?q=80&w=600&auto=format&fit=crop';
  }

  // Checks whether the proof file should be shown as a video.
  bool _isVideoUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    final String pathOnly = uri?.path.toLowerCase() ?? url.toLowerCase();
    final String lowerUrl = url.toLowerCase();

    return pathOnly.endsWith('.mp4') ||
        pathOnly.endsWith('.mov') ||
        pathOnly.endsWith('.m4v') ||
        pathOnly.endsWith('.webm') ||
        lowerUrl.contains('.mp4?') ||
        lowerUrl.contains('.mov?') ||
        lowerUrl.contains('.m4v?') ||
        lowerUrl.contains('.webm?');
  }

  // Turns a stored media path or URL into a usable display URL.
  Future<String?> _prepareStorageUrl(String value) async {
    final String cleanedValue = value.trim();

    if (cleanedValue.isEmpty) {
      return null;
    }

    final String? extractedPath = _extractTaskMediaStoragePath(cleanedValue);

    if (extractedPath != null && extractedPath.isNotEmpty) {
      try {
        final signedUrl = await _supabase.storage
            .from(_taskMediaBucket)
            .createSignedUrl(extractedPath, 60 * 60 * 24 * 7);

        debugPrint('Prepared child submission media signed URL: $signedUrl');
        return signedUrl;
      } on StorageException catch (error) {
        debugPrint('Storage signing failed.');
        debugPrint('Bucket: $_taskMediaBucket');
        debugPrint('Path: $extractedPath');
        debugPrint('Error: ${error.message}');

        if (cleanedValue.startsWith('http://') ||
            cleanedValue.startsWith('https://')) {
          return cleanedValue;
        }

        return null;
      } catch (error) {
        debugPrint('Unexpected storage signing error.');
        debugPrint('Bucket: $_taskMediaBucket');
        debugPrint('Path: $extractedPath');
        debugPrint('Error: $error');

        if (cleanedValue.startsWith('http://') ||
            cleanedValue.startsWith('https://')) {
          return cleanedValue;
        }

        return null;
      }
    }

    if (cleanedValue.startsWith('http://') ||
        cleanedValue.startsWith('https://')) {
      return cleanedValue;
    }

    return null;
  }

  // Extracts the real Supabase Storage path from public or signed URLs.
  String? _extractTaskMediaStoragePath(String value) {
    String cleanedValue = value.trim();

    if (cleanedValue.isEmpty) {
      return null;
    }

    cleanedValue = cleanedValue.split('?').first;

    final Uri? uri = Uri.tryParse(cleanedValue);
    String pathOnly = cleanedValue;

    if (uri != null && uri.hasScheme) {
      pathOnly = uri.path;
    }

    pathOnly = Uri.decodeComponent(pathOnly);
    pathOnly = pathOnly.replaceFirst(RegExp(r'^/+'), '');

    final List<String> markers = [
      'storage/v1/object/sign/$_taskMediaBucket/',
      'storage/v1/object/public/$_taskMediaBucket/',
      'storage/v1/object/authenticated/$_taskMediaBucket/',
      'object/sign/$_taskMediaBucket/',
      'object/public/$_taskMediaBucket/',
      'object/authenticated/$_taskMediaBucket/',
    ];

    for (final marker in markers) {
      final int markerIndex = pathOnly.indexOf(marker);

      if (markerIndex != -1) {
        final String extractedPath = pathOnly.substring(
          markerIndex + marker.length,
        );

        return extractedPath.replaceFirst(RegExp(r'^/+'), '');
      }
    }

    if (pathOnly.startsWith('$_taskMediaBucket/')) {
      return pathOnly.substring('$_taskMediaBucket/'.length);
    }

    if (pathOnly.contains('/children/') &&
        pathOnly.contains('/assigned_tasks/')) {
      return pathOnly;
    }

    return pathOnly;
  }

  // Shows a short result message after loading or review actions.
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Safely converts Supabase number values to int.
  int _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  // Rechecks Supabase before saving so duplicate reviews are avoided.
  Future<bool> _latestSubmissionAlreadyReviewed() async {
    final latestSubmission = await _supabase
        .from('child_task_submissions')
        .select('submission_id, reviewed_at, review_feedback')
        .eq('submission_id', widget.submissionId)
        .eq('assigned_task_id', widget.assignedTaskId)
        .eq('child_id', widget.childId)
        .maybeSingle();

    if (latestSubmission == null) {
      throw Exception('Submission was not found.');
    }

    final Map<String, dynamic> latestSubmissionMap =
        Map<String, dynamic>.from(latestSubmission);

    final String? reviewedAt = latestSubmissionMap['reviewed_at']?.toString();
    final String? feedback = latestSubmissionMap['review_feedback']?.toString();

    return (reviewedAt != null && reviewedAt.trim().isNotEmpty) ||
        feedback == 'approved' ||
        feedback == 'not-approved';
  }

  // Approves the submission, adds XP, and closes it from the verify list.
  Future<void> _approveSubmission() async {
    if (_isActionLoading) return;

    if (isAlreadyReviewed()) {
      _showSnackBar(
        'This task has already been reviewed.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final User? currentUser = _supabase.auth.currentUser;

      final bool alreadyReviewed = await _latestSubmissionAlreadyReviewed();

      if (alreadyReviewed) {
        _showSnackBar(
          'This task has already been reviewed.',
          Colors.orange,
        );
        await _fetchVerificationDetails();
        return;
      }

      final latestTask = await _supabase
          .from('assigned_tasks')
          .select('assigned_task_id, child_id, reward_xp')
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (latestTask == null) {
        throw Exception('Assigned task was not found.');
      }

      final Map<String, dynamic> latestTaskMap =
          Map<String, dynamic>.from(latestTask);
      final int rewardXp = _parseIntValue(latestTaskMap['reward_xp']);

      final childData = await _supabase
          .from('child')
          .select('total_xp')
          .eq('child_id', widget.childId)
          .maybeSingle();

      if (childData == null) {
        throw Exception('Child profile was not found.');
      }

      final Map<String, dynamic> childMap = Map<String, dynamic>.from(childData);
      final int currentXp = _parseIntValue(childMap['total_xp']);
      final int updatedXp = currentXp + rewardXp;

      await _supabase
          .from('child')
          .update({
            'total_xp': updatedXp,
          })
          .eq('child_id', widget.childId);

      await _supabase
          .from('child_task_submissions')
          .update({
            'reviewed_by_parent_id': currentUser?.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'review_feedback': 'approved',
          })
          .eq('submission_id', widget.submissionId)
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId);

      await _supabase
          .from('assigned_tasks')
          .update({
            'status': 'approved',
          })
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId);

      if (!mounted) return;

      _showSnackBar(
        'Task approved! $rewardXp XP added to ${getChildName()}.',
        Colors.green,
      );

      await _fetchVerificationDetails();
    } catch (error) {
      if (!mounted) return;

      _showSnackBar(
        'Approval failed: $error',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  // Sends the parent back to the full task list after a review action.
  void _goToAllAssignedTasksPage() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AllAssignedTasksPage(
          childId: widget.childId,
          childName: getChildName(),
        ),
      ),
    );
  }

  // Rejects the submission and moves it to not-approved tasks.
  Future<void> _rejectSubmission() async {
    if (_isActionLoading) return;

    if (isAlreadyReviewed()) {
      _showSnackBar(
        'This task has already been reviewed.',
        Colors.orange,
      );
      _goToAllAssignedTasksPage();
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final User? currentUser = _supabase.auth.currentUser;

      final bool alreadyReviewed = await _latestSubmissionAlreadyReviewed();

      if (alreadyReviewed) {
        _showSnackBar(
          'This task has already been reviewed.',
          Colors.orange,
        );
        _goToAllAssignedTasksPage();
        return;
      }

      await _supabase
          .from('child_task_submissions')
          .update({
            'reviewed_by_parent_id': currentUser?.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'review_feedback': 'not-approved',
          })
          .eq('submission_id', widget.submissionId)
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId);

      await _supabase
          .from('assigned_tasks')
          .update({
            'status': 'rejected',
          })
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId);

      if (!mounted) return;

      _showSnackBar(
        'Task marked as not-approved.',
        Colors.redAccent,
      );

      _goToAllAssignedTasksPage();
    } catch (error) {
      if (!mounted) return;

      _showSnackBar(
        'Reject failed: $error',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  // Builds the proof area as either image, video, or fallback image.
  Widget _buildEvidenceMedia() {
    final String? mediaUrl =
        _submissionData?['prepared_child_media_url']?.toString();

    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF22D3EE),
          borderRadius: BorderRadius.circular(32.0),
          image: DecorationImage(
            image: NetworkImage(getFallbackEvidencePhoto()),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (_isVideoUrl(mediaUrl)) {
      return Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(32.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32.0),
          child: _VerificationVideoPlayer(
            key: ValueKey(mediaUrl),
            videoUrl: mediaUrl,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF22D3EE),
        borderRadius: BorderRadius.circular(32.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.0),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.network(
              getFallbackEvidencePhoto(),
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  // Loading view while verification details are being fetched.
  Widget _buildLoadingContent() {
    return const SizedBox(
      height: 500,
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6200EE),
        ),
      ),
    );
  }

  // Error view when the submitted task cannot be loaded.
  Widget _buildErrorContent() {
    return SizedBox(
      height: 500,
      child: Center(
        child: Text(
          _errorMessage ?? 'Submitted task could not be loaded.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Main review layout with evidence, task details, and action buttons.
  Widget _buildMainContent() {
    const Color primaryPurple = Color(0xFF6200EE);
    const Color textDark = Color(0xFF0F172A);
    const Color xpYellow = Color(0xFFFBBF24);
    const Color rejectLightBlue = Color(0xFFDCE6FF);
    const Color rejectRed = Color(0xFFEF4444);

    final bool alreadyReviewed = isAlreadyReviewed();

    return Column(
      children: [
        // Child's submitted proof.
        _buildEvidenceMedia(),
        const SizedBox(height: 24),

        // Task and submission details.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32.0),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child name, submission time, and reward.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              getChildName(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            getSubmittedTimeText(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // XP reward badge.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: xpYellow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFF78350F),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${getRewardXp()} XP',
                          style: const TextStyle(
                            color: Color(0xFF78350F),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Task title and current review status.
              Text(
                getTaskName(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                getReviewStatusText(),
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Child's message about the completed task.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F9),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  getChildNote(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Parent review actions.
        Row(
          children: [
            // Reject the submission.
            Expanded(
              child: SizedBox(
                height: 110,
                child: ElevatedButton(
                  onPressed: _isActionLoading || alreadyReviewed
                      ? null
                      : _rejectSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rejectLightBlue,
                    foregroundColor: rejectRed,
                    disabledBackgroundColor: rejectLightBlue,
                    disabledForegroundColor: rejectRed.withOpacity(0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(55.0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: const Icon(
                          Icons.close,
                          color: rejectRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Reject',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Approve the submission and award XP.
            Expanded(
              child: SizedBox(
                height: 110,
                child: ElevatedButton(
                  onPressed: _isActionLoading || alreadyReviewed
                      ? null
                      : _approveSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryPurple,
                    disabledForegroundColor: Colors.white.withOpacity(0.55),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(55.0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isActionLoading ? 'Saving...' : 'Approve',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
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
                  Navigator.pop(context, true);
                },
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.purple.withOpacity(0.08),
                  height: 1.0,
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    if (_isLoading)
                      _buildLoadingContent()
                    else if (_errorMessage != null || _submissionData == null)
                      _buildErrorContent()
                    else
                      _buildMainContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _VerificationVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<_VerificationVideoPlayer> createState() =>
      _VerificationVideoPlayerState();
}

class _VerificationVideoPlayerState extends State<_VerificationVideoPlayer> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _VerificationVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _setupVideo();
    }
  }

  // Prepares the proof video player when a video file is submitted.
  Future<void> _setupVideo() async {
    try {
      setState(() {
        _hasError = false;
      });

      await _controller?.dispose();
      _controller = null;

      final VideoPlayerController controller =
          VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      _controller = controller;

      await controller.initialize().timeout(
            const Duration(seconds: 25),
          );

      await controller.setVolume(1.0);

      if (!mounted) return;

      setState(() {});
    } catch (error) {
      debugPrint('Verification video failed to load.');
      debugPrint('Video URL: ${widget.videoUrl}');
      debugPrint('Video error: $error');

      await _controller?.dispose();
      _controller = null;

      if (!mounted) return;

      setState(() {
        _hasError = true;
      });
    }
  }

  // Toggles the proof video when the parent taps it.
  void _togglePlayPause() {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Video could not play. Please upload MP4 H.264/AAC or WebM.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    final double aspectRatio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (!controller.value.isPlaying)
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Tap video to play or pause',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
