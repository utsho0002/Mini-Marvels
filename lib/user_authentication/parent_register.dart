import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Blocking non-numeric inputs
import 'package:project_1/user_authentication/child_register.dart';
import 'package:project_1/user_authentication/parent_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentRegister extends StatefulWidget {
  const ParentRegister({super.key});

  @override
  State<ParentRegister> createState() => _ParentRegisterState();
}

class _ParentRegisterState extends State<ParentRegister> {
  final TextEditingController _householdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController(); // PIN Controller
  
  bool _isPasswordVisible = false;
  bool _isPinVisible = false; // PIN visibility toggle state

  final _formKey = GlobalKey<FormState>();

  // Colors
  final Color primaryPurple = const Color(0xFF5E17EB);
  final Color primaryGold = const Color(0xFFFFC914);
  final Color backgroundLight = const Color(0xFFF4F6FC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textGray = const Color.fromARGB(255, 139, 100, 100);
  final Color borderLight = const Color(0xFFCBD5E1);
  final Color progressTrack = const Color(0xFFDCE3F9);
  final Color errorRed = const Color(0xFFEF4444);

  TextStyle get labelStyle =>
      TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 12);

  // Input field decoration function
  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: borderLight.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: primaryPurple, width: 2),
      ),
    );
  }

  //-----------------Handle Register-----------------

  Future<void> handleRegister() async {
    // 1. Validate the Form
    if (!_formKey.currentState!.validate()) return;

    // 2. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: primaryPurple),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      // --- STEP A: Create Auth Account ---
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = res.user;

      if (user != null) {
        // --- STEP B: Store Parent Data in Database (Including Security PIN) ---
        await supabase.from('user_profile').insert({
          'id': user.id, // links the user profile to the auth account
          'household_name': _householdController.text.trim(),
          'email': _emailController.text.trim(),
          'pin': _pinController.text.trim(), // Saves the 5-digit PIN to Supabase
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. Close Loading
        if (!mounted) return;
        Navigator.of(context).pop(); // close loading dialog

        // 4. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Registration Successful! Please continue to add Kids."),
            backgroundColor: primaryPurple,
          ),
        );

        // Navigate to ChildRegister page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChildRegister()),
        );
      }

    } on AuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving to database."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rocket Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: primaryGold.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Text(
                    'Welcome Aboard!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Let's set up your command center.\nParents first, then the heroes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textDark.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Progress bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Step 1: Parents',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryPurple)),
                      Text('Step 2: Kids',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textGray)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryGold,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: progressTrack,
                            borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Main White Card with Form
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                            color: primaryPurple.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12))
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Household
                          Row(
                            children: const [
                              Icon(Icons.people_alt, color: Color(0xFF1E293B)),
                              SizedBox(width: 8),
                              Text('Your Household',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Give your crew a name!',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Color.fromARGB(255, 139, 100, 100),
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 16),

                          Text('Household Name', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _householdController,
                            decoration: inputDecoration('e.g., The Smith Family'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Household name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          Divider(color: progressTrack, thickness: 1.5),
                          const SizedBox(height: 24),

                          // Parent Details
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: primaryPurple),
                              const SizedBox(width: 8),
                              Text('Parent Details',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("You'll use this to manage the account.",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: textGray,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 16),

                          // Email
                          Text('Email Address', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: inputDecoration('hero.parent@email.com'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email address is required';
                              } else if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
                                  .hasMatch(value)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          Text('Password', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: inputDecoration('••••••••').copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: textGray,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              } else if (value.length < 8) {
                                return 'Must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Security PIN Field (Hard-locked to numbers only)
                          Text('Security PIN (5 digits)', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pinController,
                            obscureText: !_isPinVisible,
                            keyboardType: TextInputType.number, 
                            maxLength: 5, 
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly, // Physically drops non-digits instantly
                            ],
                            decoration: inputDecoration('e.g., 12345').copyWith(
                              counterText: "", // Hides internal length layout labels
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPinVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: textGray,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPinVisible = !_isPinVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Security PIN is required';
                              } else if (value.length != 5) {
                                return 'PIN must be exactly 5 numbers';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Continue Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                handleRegister();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28)),
                                  elevation: 0),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Continue to Kids',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20)
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account? ',
                                  style: TextStyle(
                                      color: textDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ParentLogin()));
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Log in',
                                    style: TextStyle(
                                        color: primaryPurple,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          const SizedBox(height: 16), // Added spacing
                          
                          // Stylish Back Button added here
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text(
                                'Go Back',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: textGray,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}