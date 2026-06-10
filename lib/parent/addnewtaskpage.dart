import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddNewTaskPage extends StatefulWidget {
  final String childId;
  final String childName;

  const AddNewTaskPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<AddNewTaskPage> createState() => _AddNewTaskPageState();
}

class _AddNewTaskPageState extends State<AddNewTaskPage> {
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskDetailsController = TextEditingController();
  final TextEditingController _rewardXpController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _selectedMedia;
  String? _selectedMediaType;

  bool _isCreatingTask = false;

  static const String _taskMediaBucket = 'task-media';

  @override
  // Releases text controllers when this page is closed.
  void dispose() {
    _taskNameController.dispose();
    _taskDetailsController.dispose();
    _rewardXpController.dispose();
    super.dispose();
  }

  // Shows quick feedback after upload, validation, or save actions.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Lets the parent attach an image or video example for the task.
  Future<void> _pickMedia() async {
    final String? pickedType = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose Image'),
                onTap: () {
                  Navigator.pop(context, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Video'),
                subtitle: const Text('Use MP4 H.264/AAC or WebM'),
                onTap: () {
                  Navigator.pop(context, 'video');
                },
              ),
            ],
          ),
        );
      },
    );

    if (pickedType == null) return;

    try {
      XFile? pickedFile;

      if (pickedType == 'image') {
        pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
      } else {
        pickedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
        );
      }

      if (pickedFile == null) return;

      final String extension = _getFileExtensionFromNameOrPath(
        pickedFile.name,
        pickedFile.path,
        pickedType,
      );

      if (pickedType == 'video' && !_isBrowserFriendlyVideoExtension(extension)) {
        _showMessage('Please choose an MP4 or WebM video.');
        return;
      }

      setState(() {
        _selectedMedia = pickedFile;
        _selectedMediaType = pickedType;
      });

      if (pickedType == 'video') {
        _showMessage('Video added. For browser playback, use MP4 H.264/AAC.');
      } else {
        _showMessage('Image added');
      }
    } catch (error) {
      _showMessage('Could not select media. Please try again.');
    }
  }

  // Shows the media upload box before and after a file is selected.
  Widget _buildMediaBoxContent(Color primaryPurple) {
    if (_selectedMedia == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.add_a_photo_rounded,
            color: Color(0xFF6200EE),
            size: 30,
          ),
          SizedBox(height: 10),
          Text(
            'Add Photo or Video',
            style: TextStyle(
              color: Color(0xFF6200EE),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: primaryPurple,
          size: 34,
        ),
        const SizedBox(height: 10),
        const Text(
          'File added',
          style: TextStyle(
            color: Color(0xFF6200EE),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedMediaType == 'video' ? 'Video selected' : 'Image selected',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Reads the file extension and gives a safe fallback when needed.
  String _getFileExtensionFromNameOrPath(
    String fileName,
    String filePath,
    String mediaType,
  ) {
    String source = fileName.trim().isNotEmpty ? fileName.trim() : filePath.trim();
    source = source.split('?').first;

    final int dotIndex = source.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == source.length - 1) {
      return mediaType == 'video' ? 'mp4' : 'jpg';
    }

    return source.substring(dotIndex + 1).toLowerCase();
  }

  // Allows only video formats that play more reliably in WebView/browser.
  bool _isBrowserFriendlyVideoExtension(String extension) {
    return extension == 'mp4' || extension == 'webm';
  }

  // Sets the correct MIME type before uploading to Supabase Storage.
  String _getContentType(String extension, String mediaType) {
    if (mediaType == 'video') {
      if (extension == 'webm') return 'video/webm';
      return 'video/mp4';
    }

    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

  // Uploads the selected media and returns the storage path for the task.
  Future<String?> _uploadSelectedMediaToSupabase(String parentId) async {
    if (_selectedMedia == null || _selectedMediaType == null) {
      return null;
    }

    final supabase = Supabase.instance.client;

    final String extension = _getFileExtensionFromNameOrPath(
      _selectedMedia!.name,
      _selectedMedia!.path,
      _selectedMediaType!,
    );

    final String contentType = _getContentType(
      extension,
      _selectedMediaType!,
    );

    final fileBytes = await _selectedMedia!.readAsBytes();

    final String filePath =
        '$parentId/children/${widget.childId}/assigned_tasks/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage.from(_taskMediaBucket).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: contentType,
          ),
        );

      // Store the path only; the child page signs it when needed.
    return filePath;
  }

  // Validates the form, uploads media if selected, and creates the task.
  Future<void> _createTask() async {
    final taskName = _taskNameController.text.trim();
    final taskDetails = _taskDetailsController.text.trim();
    final rewardXp = int.tryParse(_rewardXpController.text.trim()) ?? 0;

    if (taskName.isEmpty) {
      _showMessage('Please enter task name');
      return;
    }

    if (rewardXp <= 0) {
      _showMessage('Please enter reward XP');
      return;
    }

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      _showMessage('Parent is not logged in');
      return;
    }

    try {
      setState(() {
        _isCreatingTask = true;
      });

      final selectedChild = await supabase
          .from('child')
          .select('child_id')
          .eq('child_id', widget.childId)
          .eq('parent_id', currentUser.id)
          .maybeSingle();

      if (selectedChild == null) {
        _showMessage('This child does not belong to this parent');
        return;
      }

      final String? mediaPath = await _uploadSelectedMediaToSupabase(
        currentUser.id,
      );

      await supabase.from('assigned_tasks').insert({
        'parent_id': currentUser.id,
        'child_id': widget.childId,
        'task_name': taskName,
        'task_details': taskDetails.isEmpty ? null : taskDetails,
        'reward_xp': rewardXp,
        'example_media_url': mediaPath,
        'status': 'assigned',
        'assigned_date': DateTime.now().toIso8601String().split('T').first,
        'due_date': null,
      });

      _taskNameController.clear();
      _taskDetailsController.clear();
      _rewardXpController.clear();

      setState(() {
        _selectedMedia = null;
        _selectedMediaType = null;
      });

      _showMessage('Task assigned to ${widget.childName} successfully');
    } on StorageException catch (error) {
      _showMessage(error.message);
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6200EE);
    const Color sectionTitleColor = Color(0xFF6200EE);
    const Color inputBackground = Color(0xFFEFF4FC);
    const Color lightBlueBackground = Color(0xFFF7F8FC);
    const Color yellowAccent = Color(0xFFFBBF24);

    InputDecoration inputStyle(String hintText) => InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          filled: true,
          fillColor: inputBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: const BorderSide(color: Color(0xFFDBEafe), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: const BorderSide(color: primaryPurple, width: 2.0),
          ),
        );

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
              title: const Text(
                'Add a New Task',
                style: TextStyle(
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
            body: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_square,
                            color: yellowAccent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Quest Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Task Name',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _taskNameController,
                        decoration: inputStyle('e.g. Clean up toys'),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Task Details',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _taskDetailsController,
                        maxLines: 3,
                        decoration: inputStyle('Any special instructions?'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF0284C7),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Media Example',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: primaryPurple.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: _isCreatingTask ? null : _pickMedia,
                          borderRadius: BorderRadius.circular(24.0),
                          child: _buildMediaBoxContent(primaryPurple),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: yellowAccent,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Reward (XP)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sectionTitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _rewardXpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: inputStyle('e.g. 10').copyWith(
                          suffixText: 'XP',
                          suffixStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingTask ? null : _createTask,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: Text(
                      _isCreatingTask ? 'Creating...' : 'Create Task',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.0),
                      ),
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
