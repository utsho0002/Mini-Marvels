import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_1/parent/parent_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'package:project_1/parent/parent_homepage.dart';

class ParentAuthentication extends StatefulWidget {
  const ParentAuthentication({super.key});

  @override
  State<ParentAuthentication> createState() => _ParentAuthenticationState();
}

class _ParentAuthenticationState extends State<ParentAuthentication> {
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPinVisible = false;
  bool _isLoading = false;

  // Page colors.
  final Color primaryPurple = const Color(0xFF5E17EB);
  final Color backgroundLight = const Color(0xFFF4F6FC);
  final Color textDark = const Color(0xFF1E293B);
  final Color textGray = const Color(0xFF64748B);
  final Color errorRed = const Color(0xFFEF4444);

  // Cleans up the PIN controller when this page closes.
  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // Verifies the parent's security PIN from Supabase.
  Future<void> _verifyPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          "No authenticated parent session found. Please log in again.",
        );
      }

      // Read the saved 5-digit PIN for this parent.
      final data = await supabase
          .from('parent')
          .select('parent_pin')
          .eq('user_id', user.id)
          .single();

      final String? storedPin = data['parent_pin']?.toString();
      final String enteredPin = _pinController.text.trim();

      if (storedPin == enteredPin) {
        if (!mounted) return;

        // Clear the field before opening the dashboard.
        _pinController.clear();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ParentDashboard()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Incorrect Security PIN. Access Denied."),
            backgroundColor: errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Verification failed: ${e.toString()}"),
          backgroundColor: errorRed,
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
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: backgroundLight,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Security icon.
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: primaryPurple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            color: primaryPurple,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Header title.
                        Text(
                          'Parent Gate',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Confirm your 5-digit Security PIN\nto manage your household settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: textGray,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // PIN entry card.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: primaryPurple.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Text(
                                  'ENTER SECURITY PIN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textDark.withOpacity(0.6),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Five digit security PIN field.
                                TextFormField(
                                  controller: _pinController,
                                  obscureText: !_isPinVisible,
                                  keyboardType: TextInputType.number,
                                  maxLength: 5,
                                  textAlign: TextAlign.center,
                                  // Only numbers are allowed.
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: primaryPurple,
                                    letterSpacing: 8.0,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    hintText: '•••••',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 8.0,
                                    ),
                                    filled: true,
                                    fillColor: backgroundLight,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 12,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                        color: primaryPurple,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                        color: errorRed,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                        color: errorRed,
                                        width: 2,
                                      ),
                                    ),
                                    suffixIcon: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: IconButton(
                                        icon: Icon(
                                          _isPinVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: textGray.withOpacity(0.7),
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
                                    } else if (value.length != 5) {
                                      return 'Must be exactly 5 numbers';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                // Verify button.
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _verifyPin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryPurple,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          primaryPurple.withOpacity(0.6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Verify & Enter',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.vpn_key_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Back option.
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Go Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: textGray,
                          ),
                        ),
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

// Simple placeholder page kept for older navigation tests.
class PlaceholderWidget extends StatelessWidget {
  final String title;

  const PlaceholderWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF5E17EB),
      ),
      body: Center(
        child: Text(
          'Welcome to $title! 🎉',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}