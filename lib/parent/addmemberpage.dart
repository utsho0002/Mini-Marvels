import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:project_1/parent/parenthub.dart';

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  // Form key used before saving the child profile.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Holds the typed child name and PIN.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Controls PIN show or hide state.
  bool _pinVisible = false;

  // Prevents duplicate saves while Supabase is working.
  bool _isSaving = false;

  // Supabase client for auth and database work.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Page colors.
  final Color primaryPurple = const Color(0xFF5E17EB);
  final Color primaryGold = const Color(0xFFFFC914);
  final Color backgroundLight = const Color(0xFFF4F6FC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textGray = const Color(0xFF64748B);
  final Color borderLight = const Color(0xFFCBD5E1);
  final Color errorRed = const Color(0xFFEF4444);

  // Cleans up the text controllers when the page closes.
  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Clears the form and resets the PIN visibility.
  void _clearFields() {
    _nameController.clear();
    _pinController.clear();
    _formKey.currentState?.reset();

    setState(() {
      _pinVisible = false;
    });
  }

  // Validates the form and saves a new child profile.
  Future<void> _addMember() async {
    // Stop if the form has invalid name or PIN.
    if (_formKey.currentState!.validate() == false) {
      return;
    }

    final User? currentUser = _supabase.auth.currentUser;

    // Parent must be logged in before adding a child.
    if (currentUser == null) {
      _showMessage(
        message: 'Parent is not logged in. Please login again.',
        color: errorRed,
        icon: Icons.error_rounded,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Save the new child profile in Supabase.
      await _supabase.from('child').insert({
        'parent_id': currentUser.id,
        'child_name': _nameController.text.trim(),
        'pin': _pinController.text.trim(),
      });

      if (!mounted) return;

      _showMessage(
        message: 'Explorer added successfully!',
        color: const Color(0xFF16A34A),
        icon: Icons.check_circle_rounded,
      );

      // Let the success message show briefly.
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Go back to the parent hub after adding the child.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ParentHub(),
        ),
        (route) => false,
      );
    } on PostgrestException catch (error) {
      // 23505 means this parent already has the same child PIN.
      if (error.code == '23505') {
        _showMessage(
          message:
              'Another explorer already uses this PIN. Choose a different one.',
          color: errorRed,
          icon: Icons.error_rounded,
        );
      } else {
        _showMessage(
          message: 'Failed to add explorer: ${error.message}',
          color: errorRed,
          icon: Icons.error_rounded,
        );
      }
    } catch (error) {
      _showMessage(
        message: 'Something went wrong. Please try again.',
        color: errorRed,
        icon: Icons.error_rounded,
      );
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Shows short feedback messages.
  void _showMessage({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the 4-digit PIN field with show/hide control.
  Widget _buildPinField() {
    return FormField<String>(
      initialValue: _pinController.text,
      validator: (value) {
        final String pin = _pinController.text.trim();

        if (pin.isEmpty) {
          return 'PIN is required';
        }

        if (pin.length != 4) {
          return 'PIN must be exactly 4 digits';
        }

        return null;
      },
      builder: (FormFieldState<String> state) {
        final bool hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: ValueKey(_pinVisible),
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: !_pinVisible,
              obscuringCharacter: '●',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                state.didChange(value);
                state.validate();
              },
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryPurple,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '● ● ● ●',
                hintStyle: TextStyle(
                  color: borderLight,
                  fontSize: 18,
                  letterSpacing: 6,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: hasError ? errorRed : borderLight.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: hasError ? errorRed : primaryPurple,
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _pinVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: textGray,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _pinVisible = !_pinVisible;
                    });
                  },
                ),
              ),
            ),
            if (hasError && state.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: errorRed,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: errorRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // Builds the main child profile form card.
  Widget _buildMemberCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Clear button.
          Align(
            alignment: Alignment.topRight,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundLight,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: textGray,
                onPressed: _isSaving ? null : _clearFields,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              Text(
                "Explorer's Name",
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),

              // Child name field.
              FormField<String>(
                initialValue: _nameController.text,
                validator: (value) {
                  final String name = _nameController.text.trim();

                  if (name.isEmpty) {
                    return "Explorer's name is required";
                  }

                  return null;
                },
                builder: (FormFieldState<String> state) {
                  final bool hasError = state.hasError;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-Z\s]"),
                          ),
                        ],
                        onChanged: (value) {
                          state.didChange(value);
                          state.validate();
                        },
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Leo',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: hasError
                                  ? errorRed
                                  : borderLight.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: hasError ? errorRed : primaryPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (hasError && state.errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 13,
                                color: errorRed,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: errorRed,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              Text(
                "Secret PIN",
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "A simple 4-digit code to unlock their profile.",
                style: TextStyle(
                  fontSize: 12,
                  color: textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              _buildPinField(),
            ],
          ),
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
            color: backgroundLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: backgroundLight,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: primaryPurple,
                  size: 26,
                ),
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        // Top labels.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Parent Hub',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textGray,
                              ),
                            ),
                            Text(
                              'Add New Hero',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Progress bar.
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: primaryGold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Header icon.
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: primaryPurple,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryPurple.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.face_retouching_natural_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Who's playing?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "Add your little explorer so they can\nstart their adventure.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 30),

                        _buildMemberCard(),

                        const SizedBox(height: 32),

                        // Save button.
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: primaryPurple.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _addMember,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  primaryPurple.withOpacity(0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Add Member',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.rocket_launch, size: 22),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
