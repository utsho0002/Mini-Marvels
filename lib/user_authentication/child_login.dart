import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Blocking non-numeric inputs
import 'package:project_1/child/child_homepage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildLogin extends StatefulWidget {
  const ChildLogin({super.key});

  @override
  State<ChildLogin> createState() => _ChildLoginState();
}

class _ChildLoginState extends State<ChildLogin> {
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isPinVisible = false; // Toggle for PIN visibility
  bool _isLoading = false;   // Track login state

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // --- Child Verification Logic ---
  Future<void> _loginChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final parentUser = supabase.auth.currentUser;

      // Ensure a parent account session is active on the device first
      if (parentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No active household session found. Parents must log in first!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Query database for a child matching this parent and the specified PIN
      final List<dynamic> response = await supabase
          .from('child_users')
          .select('name')
          .eq('parent_id', parentUser.id)
          .eq('pin', _pinController.text.trim());

      if (!mounted) return;

      if (response.isNotEmpty) {
        final String childName = response.first['name'];
        
        // Success: Show welcome pop up and clear inputs
        _pinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome back, $childName! 🚀"),
            backgroundColor: const Color(0xFF5E17EB),
          ),
        );

        // Navigate to Child Homepage
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const ChildHomepage()),
        );
      } else {
        // No match found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incorrect PIN. Try again, Hero!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Custom Top App Bar Row ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Arrow Button added to return to RoleScreen
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: const Color(0xFF5E17EB),
                          iconSize: 22,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Text(
                          'Mini Marvels',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E17EB),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline),
                          color: const Color(0xFF5E17EB).withOpacity(0.7),
                          iconSize: 28,
                          onPressed: () {
                            // Help button action
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // --- Playful Section Title ---
                    const Text(
                      'Ready to Play? 🎮',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E17EB),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // --- Attractive Central Login Card ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5E17EB).withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Cute character placeholder ring
                          Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF5E17EB), width: 3),
                            ),
                            child: const Icon(
                              Icons.face_unlock_rounded,
                              size: 45,
                              color: Color(0xFF5E17EB),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login text greeting
                          const Text(
                            'Hi Hero! Enter your PIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- Attractive PIN Field ---
                          Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextFormField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: !_isPinVisible,
                              obscuringCharacter: '●',
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly, // Physically locks field down to digits
                              ],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5E17EB),
                                letterSpacing: 12.0, 
                              ),
                              decoration: InputDecoration(
                                counterText: '', 
                                border: InputBorder.none,
                                // Symmetrical padding for perfect center alignment
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12), 
                                hintText: '••••',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 12.0,
                                ),
                                // Invisible prefix icon to balance out the width of the suffix icon
                                prefixIcon: const Opacity(
                                  opacity: 0.0,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Icon(Icons.visibility_rounded, size: 22),
                                  ),
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: IconButton(
                                    icon: Icon(
                                      _isPinVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      color: const Color(0xFF5E17EB).withOpacity(0.6),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPinVisible = !_isPinVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'PIN is required';
                                } else if (value.length != 4) {
                                  return 'Must be 4 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- "Let's Go! 🚀" Action Button ---
                          Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5E17EB).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginChild,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5E17EB),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF5E17EB).withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Let's Go!",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.rocket_launch, size: 22),
                                      ],
                                    ),
                            ),
                          ),
                        ],
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