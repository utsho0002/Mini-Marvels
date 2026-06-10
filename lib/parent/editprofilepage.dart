import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  // Child profile that will be edited.
  final String childId;

  const EditProfilePage({
    super.key,
    required this.childId,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Form key used before saving changes.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Holds the editable name and PIN values.
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool pinVisible = false;

  String errorMessage = '';

  // Page colors.
  final Color primaryPurple = const Color(0xFF6200EE);
  final Color labelTextColor = const Color(0xFF334155);
  final Color hintTextColor = const Color(0xFF64748B);
  final Color inputFieldBg = const Color(0xFFF1F5F9);
  final Color lightBlueBackground = const Color(0xFFF8FAFC);
  final Color errorRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    // Load current child data when the page opens.
    fetchChildDetails();
  }

  // Cleans up the text controllers when this page closes.
  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  // Fetches the selected child profile from Supabase.
  Future<void> fetchChildDetails() async {
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

      final String cleanChildId = widget.childId.trim();

      if (cleanChildId.isEmpty) {
        setState(() {
          errorMessage = 'Child ID is missing.';
          isLoading = false;
        });
        return;
      }

      // Check parent_id so one parent cannot edit another parent's child.
      final childData = await supabase
          .from('child')
          .select('child_id, child_name, pin')
          .eq('child_id', cleanChildId)
          .eq('parent_id', user.id)
          .maybeSingle();

      if (childData == null) {
        setState(() {
          errorMessage = 'Child profile not found.';
          isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> childMap = Map<String, dynamic>.from(childData);

      // Fill the fields with current database values.
      nameController.text = readText(childMap['child_name']);
      pinController.text = readText(childMap['pin']);

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

  // Saves the edited name and PIN for this child profile.
  Future<void> saveChildDetails() async {
    // Validate name and PIN before updating Supabase.
    if (formKey.currentState!.validate() == false) {
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage(
        'Parent is not logged in. Please login again.',
        Colors.redAccent,
      );
      return;
    }

    final String cleanChildId = widget.childId.trim();

    if (cleanChildId.isEmpty) {
      showMessage('Child ID is missing.', Colors.redAccent);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Save the updated child name and PIN.
      await supabase.from('child').update({
        'child_name': nameController.text.trim(),
        'pin': pinController.text.trim(),
      }).eq('child_id', cleanChildId).eq('parent_id', user.id);

      if (!mounted) return;

      showMessage(
        'Explorer profile updated successfully.',
        Colors.green,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Return so the family page can refresh.
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        showMessage(
          'Another explorer already uses this PIN. Choose a different one.',
          Colors.redAccent,
        );
      } else {
        showMessage(
          'Failed to update profile: ${error.message}',
          Colors.redAccent,
        );
      }
    } catch (e) {
      showMessage(
        'Something went wrong. Please try again.',
        Colors.redAccent,
      );
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  // Shows short messages after loading or saving actions.
  void showMessage(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Safely reads text values from Supabase data.
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

  // Loading view while the child profile is being fetched.
  Widget buildLoadingView() {
    return Center(
      child: CircularProgressIndicator(
        color: primaryPurple,
      ),
    );
  }

  // Error view with retry button if the profile cannot load.
  Widget buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
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
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load child profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hintTextColor,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: fetchChildDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the child's name input field.
  Widget buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 18,
              color: labelTextColor.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              "Explorer's Name",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: labelTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Name field.
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),
            ),
          ],
          validator: (value) {
            final String name = value?.trim() ?? '';

            if (name.isEmpty) {
              return "Explorer's name is required";
            }

            return null;
          },
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFieldBg,
            hintText: 'e.g. Leo',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: primaryPurple,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: errorRed,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: errorRed,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Builds the child's PIN input field with show/hide control.
  Widget buildPinField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: labelTextColor.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              "Secret PIN",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: labelTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // PIN field.
        TextFormField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: !pinVisible,
          obscuringCharacter: '●',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: (value) {
            final String pin = value?.trim() ?? '';

            if (pin.isEmpty) {
              return 'PIN is required';
            }

            if (pin.length != 4) {
              return 'PIN must be exactly 4 digits';
            }

            return null;
          },
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
            letterSpacing: 4,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: inputFieldBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                pinVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: hintTextColor,
              ),
              onPressed: () {
                setState(() {
                  pinVisible = !pinVisible;
                });
              },
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: primaryPurple,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: errorRed,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: errorRed,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "The PIN helps your explorer access their profile safely!",
            style: TextStyle(
              fontSize: 14,
              color: hintTextColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // Builds the editable profile form.
  Widget buildMainForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 36,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildNameField(),
            const SizedBox(height: 28),
            buildPinField(),
            const SizedBox(height: 36),

            // Save button.
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveChildDetails,
                icon: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                label: Text(
                  isSaving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryPurple.withOpacity(0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                ),
                onPressed: isSaving
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
              ),
              title: Text(
                'Edit Explorer Profile',
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: isSaving ? null : fetchChildDetails,
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
            body: isLoading
                ? buildLoadingView()
                : errorMessage.isNotEmpty
                    ? buildErrorView()
                    : buildMainForm(),
          ),
        ),
      ),
    );
  }
}
