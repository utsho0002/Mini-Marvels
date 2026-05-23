import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_1/parent/parent_homepage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildRegister extends StatefulWidget {
  const ChildRegister({super.key});

  @override
  State<ChildRegister> createState() => _ChildRegisterState();
}

class _ChildRegisterState extends State<ChildRegister> {
  // ─── Form Validation Key ───────────────────────────────────────────────────
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ─── Child controllers ─────────────────────────────────────────────────────
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  // ─── Toggle to show/hide PIN digits ────────────────────────────────────────
  bool _pinVisible = false;

  // ─── Registration Functionality────────────────────────────────────────
  Future<void> registerChild(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final parentUserId = supabase.auth.currentUser!.id;

    // Check duplicate PIN under same parent
    final existing = await supabase
        .from('child_users')
        .select('id')
        .eq('parent_id', parentUserId)
        .eq('pin', _pin.text.trim())
        .maybeSingle();

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Another explorer already uses this PIN. Choose a different one.',
          ),
        ),
      );
      return;
    }

    // Insert child
    await supabase.from('child_users').insert({
      'parent_id': parentUserId,
      'name': _name.text.trim(),
      'pin': _pin.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    backgroundColor: const Color(0xFF1D4ED8),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    content: Row(
      children: const [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Text(
          'Explorer added successfully!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    ),
    duration: const Duration(seconds: 3),
  ),
);

  Navigator.push(context, MaterialPageRoute(builder: (context)=>
  ParentHomepage()
  ));
  }

  // ─── Colors ────────────────────────────────────────────────────────────────
  final Color primaryPurple = const Color(0xFF5E17EB);
  final Color primaryGold = const Color(0xFFFFC914);
  final Color backgroundLight = const Color(0xFFF4F6FC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textGray = const Color(0xFF64748B);
  final Color borderLight = const Color(0xFFCBD5E1);
  final Color errorRed = const Color(0xFFEF4444);

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  // ─── Clears fields and clears active native form validation errors ─────────
  void _clearChildFields() {
    _name.clear();
    _pin.clear();
    _formKey.currentState?.reset();
  }

  // ─── A single PIN text field (4-digit, numbers only) ──────────────────────
  Widget _buildPinField({
    required TextEditingController pinController,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    VoidCallback? onChanged,
  }) {
    return FormField<String>(
      initialValue: pinController.text,
      validator: (value) {
        // Form Key links directly to this validator
        final pin = (value ?? pinController.text).trim();
        if (pin.isEmpty) {
          return 'PIN is required';
        } else if (pin.length < 4) {
          return 'PIN must be exactly 4 digits (0–9)';
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: ValueKey(isVisible),
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: !isVisible,
              obscuringCharacter: '●',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (val) {
                state.didChange(val); // Notifies Form Key of changes
                state
                    .validate(); // Provides seamless live error updates as they type
                if (onChanged != null) onChanged();
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
                    isVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: textGray,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                ),
              ),
            ),
            if (hasError && state.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: errorRed),
                    const SizedBox(width: 4),
                    Text(
                      state.errorText!,
                      style: TextStyle(
                        fontSize: 12,
                        color: errorRed,
                        fontWeight: FontWeight.w500,
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

  // ─── The white card for the child ─────────────────────────────────────────
  Widget _buildChildCard({
    required TextEditingController nameController,
    required TextEditingController pinController,
    required bool pinVisible,
    required VoidCallback onTogglePinVisibility,
    required VoidCallback onClose,
    VoidCallback? onNameChanged,
    VoidCallback? onPinChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
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
          // Clear/Close button top-right
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
                onPressed: onClose,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Name label
              Text(
                "Explorer's Name",
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),

              // Name field integrated seamlessly with native validation
              FormField<String>(
                initialValue: nameController.text,
                validator: (value) {
                  final name = (value ?? nameController.text).trim();
                  if (name.isEmpty) {
                    return "Explorer's name is required";
                  }
                  return null;
                },
                builder: (FormFieldState<String> state) {
                  final hasError = state.hasError;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-Z\s]"),
                          ),
                        ],
                        onChanged: (val) {
                          state.didChange(val); // Notifies Form Key of changes
                          state
                              .validate(); // Provides seamless live error updates as they type
                          if (onNameChanged != null) onNameChanged();
                        },
                        style: TextStyle(color: textDark),
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
                              Text(
                                state.errorText!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: errorRed,
                                  fontWeight: FontWeight.w500,
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

              // PIN label
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
                "A simple 4-digit code (0-9) to unlock their profile.",
                style: TextStyle(
                  fontSize: 12,
                  color: textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // PIN field
              _buildPinField(
                pinController: pinController,
                isVisible: pinVisible,
                onToggleVisibility: onTogglePinVisibility,
                onChanged: onPinChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 30.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step 1: Parents',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textGray,
                          ),
                        ),
                        Text(
                          'Step 2: Kids',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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

                    // Header Icon
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

                    // Header Text
                    Text(
                      "Who's playing?",
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

                    // Child Card
                    _buildChildCard(
                      nameController: _name,
                      pinController: _pin,
                      pinVisible: _pinVisible,
                      onTogglePinVisibility: () {
                        setState(() => _pinVisible = !_pinVisible);
                      },
                      onClose: _clearChildFields,
                      onNameChanged: () {},
                      onPinChanged: () {},
                    ),

                    const SizedBox(height: 32),

                    // Finish Setup Button
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await registerChild(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Finish Setup',
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
                    const SizedBox(height: 16),

                    // Skip Footer
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "I'll do this later",
                        style: TextStyle(
                          color: textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
