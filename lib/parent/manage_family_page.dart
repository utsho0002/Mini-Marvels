import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:project_1/parent/addmemberpage.dart';
import 'package:project_1/parent/editprofilepage.dart';

class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({super.key});

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Used for editing the household name.
  final TextEditingController householdNameController = TextEditingController();

  bool isLoading = true;
  bool isSavingHouseholdName = false;
  String errorMessage = '';

  // Child profiles loaded from Supabase.
  List<Map<String, dynamic>> children = [];

  // Parent and household details.
  String parentId = '';
  String householdName = '';

  // Page colors.
  final Color primaryPurple = const Color(0xFF6200EE);
  final Color sectionTitleColor = const Color(0xFF5B21B6);
  final Color lightBlueBackground = const Color(0xFFF7F8FC);
  final Color yellowAccent = const Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();

    fetchFamilyData();
  }

  // Cleans up the household name controller when the page closes.
  @override
  void dispose() {
    householdNameController.dispose();
    super.dispose();
  }

  // Loads the household information and all child profiles for this parent.
  Future<void> fetchFamilyData() async {
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

      parentId = user.id;

      // Load household name from the parent profile.
      final parentData = await supabase
          .from('parent')
          .select('user_id, household_name')
          .eq('user_id', parentId)
          .maybeSingle();

      if (parentData != null) {
        Map<String, dynamic> parentMap = Map<String, dynamic>.from(parentData);

        householdName = readText(
          parentMap['household_name'],
          fallback: 'My Household',
        );
      } else {
        householdName = 'My Household';
      }

      householdNameController.text = householdName;

      // Load all child profiles under this parent.
      final childData = await supabase
          .from('child')
          .select(
            'child_id, child_name, pin, total_xp, current_level, daily_game_limit_minutes, games_locked, created_at',
          )
          .eq('parent_id', parentId)
          .order('created_at', ascending: true);

      List<Map<String, dynamic>> loadedChildren = [];

      for (var item in childData) {
        loadedChildren.add(Map<String, dynamic>.from(item));
      }

      setState(() {
        children = loadedChildren;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Saves the edited household name to the parent table.
  Future<void> updateHouseholdName() async {
    String newName = householdNameController.text.trim();

    if (newName.isEmpty) {
      showMessage('Household name cannot be empty.', Colors.redAccent);
      return;
    }

    if (parentId.isEmpty) {
      showMessage('Parent ID not found. Please login again.', Colors.redAccent);
      return;
    }

    setState(() {
      isSavingHouseholdName = true;
    });

    try {
      // Update household_name in parent table.
      await supabase
          .from('parent')
          .update({'household_name': newName})
          .eq('user_id', parentId);

      setState(() {
        householdName = newName;
      });

      showMessage('Household name updated.', Colors.green);
    } catch (e) {
      showMessage('Failed to update household name: $e', Colors.redAccent);
    }

    setState(() {
      isSavingHouseholdName = false;
    });
  }

  // Deletes a child profile after parent confirmation.
  Future<void> deleteChild(Map<String, dynamic> child) async {
    String childId = readText(child['child_id']);
    String childName = readText(child['child_name'], fallback: 'this child');

    if (childId.isEmpty) {
      showMessage('Child ID not found.', Colors.redAccent);
      return;
    }

    bool confirmDelete = await showDeleteConfirmDialog(childName);

    if (confirmDelete == false) {
      return;
    }

    try {
      // Remove the child profile from Supabase.
      await supabase
          .from('child')
          .delete()
          .eq('child_id', childId)
          .eq('parent_id', parentId);

      showMessage('$childName deleted.', Colors.green);

      // Refresh list after delete.
      fetchFamilyData();
    } catch (e) {
      showMessage('Failed to delete child: $e', Colors.redAccent);
    }
  }

  // Asks the parent before permanently deleting a child profile.
  Future<bool> showDeleteConfirmDialog(String childName) async {
    bool result = false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete Hero?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF6200EE),
            ),
          ),
          content: Text(
            'Are you sure you want to delete $childName? This action cannot be undone.',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false;
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                result = true;
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result;
  }

  // Opens the add child page and refreshes this page after returning.
  void openAddMemberPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMemberPage()),
    );

    // Refresh after adding a child.
    fetchFamilyData();
  }

  // Opens the edit page for the selected child profile.
  void openEditProfilePage(Map<String, dynamic> child) async {
    // Send this child to the edit page.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditProfilePage(childId: child['child_id'].toString()),
      ),
    );

    // Refresh after editing a child.
    fetchFamilyData();
  }

  // Shows short feedback messages after save, delete, or load actions.
  void showMessage(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Safely reads text values from Supabase data.
  // Safely reads text values from the child profile row.
  // Safely reads text values from the child profile row.
  String readText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  // Safely reads integer values from Supabase data.
  // Safely reads number values from the child profile row.
  // Safely reads number values from the child profile row.
  int readInt(dynamic value, {int fallback = 0}) {
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

  // Loading view while family data is being fetched.
  Widget buildLoadingView() {
    return Center(child: CircularProgressIndicator(color: primaryPurple));
  }

  // Error view with retry button when family data cannot load.
  Widget buildErrorView() {
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
                color: Colors.redAccent,
                size: 46,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load family data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: fetchFamilyData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty view shown when there are no child profiles yet.
  Widget buildNoChildView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Icon(Icons.child_care, color: primaryPurple, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No Little Heroes Yet',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a child profile to start managing your family.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.3),
          ),
        ],
      ),
    );
  }

  // Builds the main page content based on loading, error, or data state.
  Widget buildMainContent() {
    if (isLoading) {
      return buildLoadingView();
    }

    if (errorMessage.isNotEmpty) {
      return buildErrorView();
    }

    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: fetchFamilyData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        children: [
          Text(
            'Your Little Heroes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: sectionTitleColor,
            ),
          ),
          const SizedBox(height: 16),

          if (children.isEmpty)
            buildNoChildView()
          else
            for (var child in children) ...[
              HeroMemberCard(
                child: child,
                onEdit: () {
                  openEditProfilePage(child);
                },
                onDelete: () {
                  deleteChild(child);
                },
              ),
              const SizedBox(height: 16),
            ],

          const SizedBox(height: 8),

          // Add New Hero Button.
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: openAddMemberPage,
              icon: const Icon(Icons.add, size: 24),
              label: const Text(
                'Add New Hero',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: yellowAccent,
                foregroundColor: Colors.black87,
                elevation: 4,
                shadowColor: yellowAccent.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            'Household Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: sectionTitleColor,
            ),
          ),
          const SizedBox(height: 16),

          HouseholdSettingsCard(
            controller: householdNameController,
            isSaving: isSavingHouseholdName,
            onSave: updateHouseholdName,
          ),

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
                icon: Icon(Icons.arrow_back, color: primaryPurple),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              centerTitle: true,
              title: Text(
                'Manage Family',
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: fetchFamilyData,
                  icon: Icon(Icons.refresh, color: primaryPurple),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.purple.withOpacity(0.1),
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

// Card for showing one child profile.
class HeroMemberCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HeroMemberCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  String readText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int readInt(dynamic value, {int fallback = 0}) {
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
    const Color chipBgColor = Color(0xFFE0E7FF);
    const Color iconCircleColor = Color(0xFFEEF2F6);
    const Color brandBlue = Color(0xFF4F46E5);

    String name = readText(child['child_name'], fallback: 'Little Hero');
    String pin = readText(child['pin'], fallback: '----');

    int level = readInt(child['current_level'], fallback: 1);
    int xp = readInt(child['total_xp'], fallback: 0);
    int dailyLimit = readInt(child['daily_game_limit_minutes'], fallback: 60);
    bool gamesLocked = child['games_locked'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Child details and quick stats.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // PIN chip.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PIN: $pin',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    smallInfoChip('Level $level', Icons.workspace_premium),
                    smallInfoChip('$xp XP', Icons.star),
                    smallInfoChip('$dailyLimit mins', Icons.timer),
                    smallInfoChip(
                      gamesLocked ? 'Games Locked' : 'Games Open',
                      gamesLocked ? Icons.lock : Icons.lock_open,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Edit and delete actions.
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: iconCircleColor,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: brandBlue,
                  ),
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: iconCircleColor,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.black54,
                  ),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Small chip used for level, XP, points, limit, and lock status.
  Widget smallInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Color(0xFF6200EE)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// Card for editing the household name.
class HouseholdSettingsCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;

  const HouseholdSettingsCard({
    super.key,
    required this.controller,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    const Color lightBlueIconBg = Color(0xFFDBEAFE);
    const Color blueIconColor = Color(0xFF2563EB);
    const Color primaryPurple = Color(0xFF6200EE);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Home icon.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: lightBlueIconBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_filled,
                  color: blueIconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              const Expanded(
                child: Text(
                  'Household Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Household name input.
          TextFormField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F4FA),
              hintText: 'Example: Smith Family',
              prefixIcon: const Icon(
                Icons.home_work_outlined,
                color: primaryPurple,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFDCE2EE),
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: primaryPurple, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                isSaving ? 'Saving...' : 'Save Household Name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryPurple.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
