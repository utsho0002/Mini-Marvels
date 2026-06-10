import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_1/child/marvey_chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class TaskDetailsPage extends StatefulWidget {
  final String assignedTaskId;
  final String childId;
  final String? taskName;

  const TaskDetailsPage({
    Key? key,
    required this.assignedTaskId,
    required this.childId,
    this.taskName,
  }) : super(key: key);

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

enum _PickedMediaType {
  image,
  video,
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  // Shared Supabase client used for task records, submissions, and storage access.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Optional note written by the child before submitting proof.
  final TextEditingController _noteController = TextEditingController();

  // Bucket used for both parent guide media and child submission proof.
  static const String _taskMediaBucket = 'task-media';

  final ImagePicker _picker = ImagePicker();

  // Holds the proof selected by the child before it is uploaded.
  XFile? _selectedMediaFile;
  Uint8List? _selectedImageBytes;
  _PickedMediaType? _selectedMediaType;

  // Current assigned task information loaded from Supabase.
  Map<String, dynamic>? _taskData;

  bool _isTaskLoading = true;
  bool _isSubmitting = false;

  // Countdown state used to stop late submissions after the task expires.
  DateTime? _expiresAt;
  Duration _timeLeft = Duration.zero;
  Timer? _countdownTimer;
  bool _hasTaskExpired = false;
  bool _expiryMessageShown = false;



  @override
  void initState() {
    super.initState();
    _fetchAssignedTaskDetails();
  }

  // Loads the active task and prepares any parent guide media before display.
  Future<void> _fetchAssignedTaskDetails() async {
    try {
      final String nowUtc = DateTime.now().toUtc().toIso8601String();

      final data = await _supabase
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
            expires_at,
            created_at
          ''')
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId)
          .eq('status', 'assigned')
          .gt('expires_at', nowUtc)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _taskData = null;
          _isTaskLoading = false;
          _hasTaskExpired = true;
        });

        _showSnackBar(
          'This task has expired or is no longer available.',
          Colors.redAccent,
        );

        Navigator.pop(context, true);
        return;
      }

      final Map<String, dynamic> taskMap = Map<String, dynamic>.from(data);

      final DateTime? parsedExpiresAt = _parseExpiresAt(taskMap['expires_at']);
      _expiresAt = parsedExpiresAt;
      _startCountdown();

      final String? rawMediaValue = taskMap['example_media_url']?.toString();

      if (rawMediaValue != null && rawMediaValue.trim().isNotEmpty) {
        try {
          final String? preparedUrl = await _prepareStorageUrl(rawMediaValue);

          if (preparedUrl != null && preparedUrl.trim().isNotEmpty) {
            taskMap['example_media_url'] = preparedUrl;
          } else {
            taskMap['example_media_url'] = null;
          }
        } catch (mediaError) {
          debugPrint('Parent media prepare failed: $mediaError');

          // Media failure should not stop the whole task page from loading.
          taskMap['example_media_url'] = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _taskData = taskMap;
        _isTaskLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isTaskLoading = false;
      });

      _showSnackBar(
        'Failed to load task: $error',
        Colors.redAccent,
      );
    }
  }

  DateTime? _parseExpiresAt(dynamic value) {
    if (value == null) return null;

    final String text = value.toString().trim();
    if (text.isEmpty) return null;

    try {
      return DateTime.parse(text).toLocal();
    } catch (error) {
      debugPrint('Could not parse expires_at: $error');
      return null;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  void _updateCountdown() {
    final DateTime? expiresAt = _expiresAt;

    if (expiresAt == null) return;

    final Duration difference = expiresAt.difference(DateTime.now());

    if (!mounted) return;

    if (difference.isNegative || difference.inSeconds <= 0) {
      _countdownTimer?.cancel();

      setState(() {
        _timeLeft = Duration.zero;
        _hasTaskExpired = true;
      });

      if (!_expiryMessageShown) {
        _expiryMessageShown = true;
        _showSnackBar(
          'Time is up! This task has expired.',
          Colors.redAccent,
        );
      }

      return;
    }

    setState(() {
      _timeLeft = difference;
      _hasTaskExpired = false;
    });
  }

  String _formatTimeLeft() {
    if (_expiresAt == null) {
      return 'Available for 24 hours';
    }

    if (_hasTaskExpired) {
      return 'Expired';
    }

    final int hours = _timeLeft.inHours;
    final int minutes = _timeLeft.inMinutes % 60;
    final int seconds = _timeLeft.inSeconds % 60;

    final String minuteText = minutes.toString().padLeft(2, '0');
    final String secondText = seconds.toString().padLeft(2, '0');

    return '$hours:$minuteText:$secondText left';
  }

  Widget _buildExpiryCounter() {
    if (_expiresAt == null) {
      return const SizedBox.shrink();
    }

    final bool almostExpired = _timeLeft.inHours < 1;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _hasTaskExpired
            ? Colors.redAccent.withOpacity(0.12)
            : almostExpired
                ? Colors.orangeAccent.withOpacity(0.18)
                : Colors.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasTaskExpired
              ? Colors.redAccent
              : almostExpired
                  ? Colors.orangeAccent
                  : Colors.teal,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasTaskExpired
                ? Icons.timer_off_rounded
                : Icons.timer_outlined,
            color: _hasTaskExpired
                ? Colors.redAccent
                : almostExpired
                    ? Colors.orange
                    : Colors.teal,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hasTaskExpired
                  ? 'Task expired'
                  : 'Task expires in ${_formatTimeLeft()}',
              style: TextStyle(
                color: _hasTaskExpired
                    ? Colors.redAccent
                    : almostExpired
                        ? Colors.orange.shade900
                        : Colors.teal.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rechecks availability right before submission to avoid accepting expired tasks.
  Future<bool> _isTaskStillAvailableInDatabase() async {
    final String nowUtc = DateTime.now().toUtc().toIso8601String();

    final data = await _supabase
        .from('assigned_tasks')
        .select('assigned_task_id')
        .eq('assigned_task_id', widget.assignedTaskId)
        .eq('child_id', widget.childId)
        .eq('status', 'assigned')
        .gt('expires_at', nowUtc)
        .maybeSingle();

    return data != null;
  }

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

        debugPrint('Prepared parent media signed URL: $signedUrl');
        return signedUrl;
      } on StorageException catch (error) {
        debugPrint('Storage signing failed.');
        debugPrint('Bucket: $_taskMediaBucket');
        debugPrint('Path: $extractedPath');
        debugPrint('Error: ${error.message}');

        // If the old database row already has a complete URL, try to use it.
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

    // Correct database format:
    // parentId/children/childId/assigned_tasks/file.mp4
    if (pathOnly.contains('/children/') &&
        pathOnly.contains('/assigned_tasks/')) {
      return pathOnly;
    }

    return pathOnly;
  }

  String getTaskName() {
    return _taskData?['task_name']?.toString() ??
        widget.taskName ??
        'Your Task';
  }

  String getMissionBriefing() {
    final String? details = _taskData?['task_details']?.toString();

    if (details != null && details.trim().isNotEmpty) {
      return details;
    }

    return 'Complete this awesome mission assigned by your parents to earn big rewards and build your hero level!';
  }

  int getRewardXp() {
    final dynamic value = _taskData?['reward_xp'];

    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  String? getParentMediaUrl() {
    final String? mediaUrl = _taskData?['example_media_url']?.toString();

    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      return null;
    }

    return mediaUrl.trim();
  }

  String getFallbackInstructionPhoto() {
    return 'https://img.freepik.com/free-vector/kids-learning-concept-illustration_114360-10891.jpg';
  }

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

  // Lets the child choose either a photo or a video as proof of completion.
  Future<void> _pickMedia() async {
    if (_hasTaskExpired) {
      _showSnackBar(
        'This task has expired. You can no longer upload proof.',
        Colors.redAccent,
      );
      return;
    }

    final _PickedMediaType? pickedType =
        await showModalBottomSheet<_PickedMediaType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text(
                    'Choose Photo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, _PickedMediaType.image);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.videocam_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text(
                    'Choose Video',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, _PickedMediaType.video);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedType == null) return;

    try {
      XFile? pickedFile;
      Uint8List? imageBytes;

      if (pickedType == _PickedMediaType.image) {
        pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
        );

        if (pickedFile != null) {
          imageBytes = await pickedFile.readAsBytes();
        }
      } else {
        pickedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
        );
      }

      if (pickedFile != null) {
        setState(() {
          _selectedMediaFile = pickedFile;
          _selectedMediaType = pickedType;
          _selectedImageBytes = imageBytes;
        });
      }
    } catch (error) {
      _showSnackBar(
        'Error picking media: $error',
        Colors.redAccent,
      );
    }
  }

  String _getFileExtension(String nameOrPath) {
    final String cleanPath = nameOrPath.split('?').first;
    final int dotIndex = cleanPath.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == cleanPath.length - 1) {
      if (_selectedMediaType == _PickedMediaType.video) {
        return 'mp4';
      }

      return 'jpg';
    }

    return cleanPath.substring(dotIndex + 1).toLowerCase();
  }

  String _getContentType(String extension) {
    if (_selectedMediaType == _PickedMediaType.video) {
      if (extension == 'webm') return 'video/webm';
      if (extension == 'm4v') return 'video/mp4';
      return 'video/mp4';
    }

    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

  // Uploads the selected proof and returns the permanent storage path.
  Future<String> _uploadChildMediaToStorage() async {
    final XFile file = _selectedMediaFile!;

    final String extension = _getFileExtension(
      file.name.trim().isNotEmpty ? file.name : file.path,
    );

    final String contentType = _getContentType(extension);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final String parentId =
        _taskData?['parent_id']?.toString() ?? 'unknown_parent';

    final String filePath =
        '$parentId/children/${widget.childId}/assigned_tasks/${widget.assignedTaskId}/submissions/$timestamp.$extension';

    final Uint8List fileBytes = await file.readAsBytes();

    await _supabase.storage.from(_taskMediaBucket).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
            cacheControl: '3600',
          ),
        );

    // Store the Storage path only. A signed URL can expire.
    return filePath;
  }

  // Saves the child's proof, updates the task status, and returns to the task list.
  Future<void> _submitMissionToDatabase() async {
    if (_isSubmitting) return;

    if (_taskData == null) {
      _showSnackBar(
        'Task is still loading. Please try again.',
        Colors.redAccent,
      );
      return;
    }

    if (_hasTaskExpired) {
      _showSnackBar(
        'This task has expired. You can no longer submit it.',
        Colors.redAccent,
      );
      return;
    }

    if (_selectedMediaFile == null) {
      _showSnackBar(
        'Please add photo or video proof before submitting!',
        Colors.amber.shade900,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orangeAccent),
      ),
    );

    try {
      final bool taskStillAvailable = await _isTaskStillAvailableInDatabase();

      if (!taskStillAvailable) {
        if (!mounted) return;

        Navigator.pop(context);

        setState(() {
          _hasTaskExpired = true;
        });

        _showSnackBar(
          'This task has expired or was already submitted.',
          Colors.redAccent,
        );
        return;
      }

      final String childMediaUrl = await _uploadChildMediaToStorage();
      final String noteText = _noteController.text.trim();

      await _supabase.from('child_task_submissions').insert({
        'assigned_task_id': widget.assignedTaskId,
        'child_id': widget.childId,
        'child_note': noteText.isEmpty ? null : noteText,
        'child_media_url': childMediaUrl,
        'review_feedback': 'submitted',
      });

      await _supabase
          .from('assigned_tasks')
          .update({
            'status': 'submitted',
          })
          .eq('assigned_task_id', widget.assignedTaskId)
          .eq('child_id', widget.childId);

      if (!mounted) return;

      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.amberAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mission Submitted!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Awesome job! Your proof and message have been sent to your parents for approval.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text(
                'Awesome!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      Navigator.pop(context);

      _showSnackBar(
        'Database Upload Failed: $error',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Opens Marvey as a general helper without saving chat messages.
  Future<void> _openMarveyAiChat() async {
    if (_taskData == null) {
      _showSnackBar(
        'Task is still loading. Please try again.',
        Colors.redAccent,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarveyChatPage(
          childId: widget.childId,
        ),
      ),
    );
  }

  // Displays the parent's example image or video guide for the mission.
  Widget _buildParentGuideMedia() {
    final String? mediaUrl = getParentMediaUrl();

    if (_isTaskLoading) {
      return Container(
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }

    if (mediaUrl == null) {
      return Container(
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          image: DecorationImage(
            image: NetworkImage(getFallbackInstructionPhoto()),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (_isVideoUrl(mediaUrl)) {
      return Container(
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(25),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: _ParentVideoGuidePlayer(
            key: ValueKey(mediaUrl),
            videoUrl: mediaUrl,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.network(
              getFallbackInstructionPhoto(),
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  // Shows a preview or status message for the selected proof media.
  Widget _buildSelectedMediaPreview() {
    if (_selectedMediaFile == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            size: 42,
            color: Color(0xFF7C3AED),
          ),
          SizedBox(height: 6),
          Text(
            'Tap to Upload Photo or Video',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    if (_selectedMediaType == _PickedMediaType.video) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_rounded,
            size: 46,
            color: Color(0xFF7C3AED),
          ),
          SizedBox(height: 8),
          Text(
            'Video selected',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    final Uint8List? imageBytes = _selectedImageBytes;

    if (imageBytes == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_rounded,
            size: 46,
            color: Color(0xFF7C3AED),
          ),
          SizedBox(height: 8),
          Text(
            'Image selected',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          // Keeps the page fitted to the current phone or emulator screen.
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
                'Task Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
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
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Parent's Task Guide",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildParentGuideMedia(),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        color: Colors.teal,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Your Mission',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orangeAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      '+${getRewardXp()} XP',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                getTaskName(),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                getMissionBriefing(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              _buildExpiryCounter(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE9D5FF),
                                Color(0xFFA78BFA),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.smart_toy_rounded,
                                  size: 28,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stuck? Ask Marvey!',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 25, 16, 16),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Get helper superhero tips',
                                      style: TextStyle(
                                        color: Color.fromARGB(179, 24, 15, 15),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _openMarveyAiChat,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF7C3AED),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Ask AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Row(
                          children: [
                            Icon(
                              Icons.photo_camera_back_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Prove Your Success!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _hasTaskExpired ? null : _pickMedia,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F7FC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selectedMediaFile != null
                                          ? Colors.teal
                                          : const Color(
                                              0xFFA78BFA,
                                            ).withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: _buildSelectedMediaPreview(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.rate_review_rounded,
                                    color: Colors.black54,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Write a message for your parents:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _noteController,
                                enabled: !_hasTaskExpired,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText:
                                      'Tell Mom or Dad how well you did this job...',
                                  filled: true,
                                  fillColor: const Color(0xFFF4F7FC),
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: _isSubmitting || _hasTaskExpired
                              ? null
                              : _submitMissionToDatabase,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _hasTaskExpired
                                  ? Colors.grey
                                  : Colors.orangeAccent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _hasTaskExpired
                                      ? Colors.grey.shade700
                                      : const Color(0xFFD97706),
                                  offset: const Offset(0, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasTaskExpired
                                      ? Icons.timer_off_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _hasTaskExpired
                                      ? 'Task Expired'
                                      : _isSubmitting
                                          ? 'Submitting...'
                                          : 'Mark as Done',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
}

class _ParentVideoGuidePlayer extends StatefulWidget {
  final String videoUrl;

  const _ParentVideoGuidePlayer({
    Key? key,
    required this.videoUrl,
  }) : super(key: key);

  @override
  State<_ParentVideoGuidePlayer> createState() =>
      _ParentVideoGuidePlayerState();
}

class _ParentVideoGuidePlayerState extends State<_ParentVideoGuidePlayer> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _ParentVideoGuidePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _setupVideo();
    }
  }

  // Prepares the parent guide video player for network video playback.
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
      debugPrint('Parent video guide failed to load.');
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
