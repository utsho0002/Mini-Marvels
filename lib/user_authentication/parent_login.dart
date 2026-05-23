import 'package:flutter/material.dart';
import 'package:project_1/parent/parent_homepage.dart';
import 'package:project_1/user_authentication/parent_register.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentLogin extends StatefulWidget {
  const ParentLogin({super.key});

  @override
  State<ParentLogin> createState() => _ParentLoginState();
}

class _ParentLoginState extends State<ParentLogin> {
  // ─── Form Key & Controllers ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ─── UI State Flags ────────────────────────────────────────────────────────
  bool _passwordVisible = false;

  // ─── Color Palette (Matching ChildRegister) ───────────────────────────────
  final Color primaryPurple = const Color(0xFF5E17EB);
  final Color primaryGold = const Color(0xFFFFC914);
  final Color backgroundLight = const Color(0xFFF4F6FC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textGray = const Color(0xFF64748B);
  final Color borderLight = const Color(0xFFCBD5E1);
  final Color errorRed = const Color(0xFFEF4444);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Login Function ────────────────────────────────────────
  bool _isLoading = false;

  Future<void> _handleParentLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      _formKey.currentState?.reset();

      // Show Success feedback to parent
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text("Successfully logged in!!")),
            ],
          ),
          backgroundColor: const Color(0xFF10B981), // Fixed to Green for successful validation
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      // Navigate to your Homepage
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => const ParentHomepage()),
      );
        
    } catch (error) {
      // Display any Supabase or runtime errors cleanly inside a snackbar layer
      if (!mounted) return;

      // Pull the clean error message directly from Supabase API if available
      String errorMessage = error.toString().replaceAll("Exception: ", "");
      if (error is AuthException) {
        errorMessage = error.message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444), // Matches your errorRed color
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } finally {
      // Safe close down of the progress indicator framework overlay
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
              child: Form(
                key: _formKey, // Hooks the validation state
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Header Icon (Supervisor/Parent Shield theme)
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
                        child: Icon(Icons.supervisor_account_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Text
                    Text(
                      "Welcome Back!",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryPurple),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign in to access your parent dashboard\nand monitor your explorer's progress.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textDark.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Login Card Containing Fields
                    Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── EMAIL FIELD ───────────────────────────────────
                          Text(
                            "Parent's Email Address",
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textDark),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email address is required';
                              }
                              // Basic email regex pattern validation
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hintText: 'e.g. parent@example.com',
                              prefixIcon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ─── PASSWORD FIELD ────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Password",
                                style: TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  // TODO: Handle Forgot Password navigation
                                },
                                child: Text(
                                  "Forgot?",
                                  style: TextStyle(
                                    color: primaryPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            style: TextStyle(color: textDark),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleParentLogin(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: textGray,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _passwordVisible = !_passwordVisible);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ─── SIGN IN BUTTON ──────────────────────────────────────
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
                              onPressed: _isLoading ? null : _handleParentLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPurple,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: primaryPurple.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading 
                                ? const SizedBox(
                                    height: 24, 
                                    width: 24, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 22),
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer navigation link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(color: textGray, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ParentRegister(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Create one",
                                  style: TextStyle(
                                    color: primaryPurple,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ─── STYLISH BACK BUTTON ────────────────────────────────
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back_rounded, size: 18, color: textGray),
                              label: Text(
                                "Go Back",
                                style: TextStyle(
                                  color: textGray,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                side: BorderSide(color: borderLight, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
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

  // Helper method to generate styling consistent with your child flow
  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      prefixIcon: Icon(prefixIcon, color: textGray, size: 20),
      errorStyle: TextStyle(color: errorRed, fontWeight: FontWeight.w500, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: borderLight.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: primaryPurple,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: errorRed,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: errorRed,
          width: 2,
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }
}