import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _isPinVisible = false;
  bool _isLoading = false;

  // Cleans up the PIN controller when this page closes.
  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // Checks the child PIN under the logged-in parent account.
  // Shows short feedback messages after login checks.
  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loginChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final parentUser = supabase.auth.currentUser;

      if (parentUser == null) {
        if (!mounted) return;

        _showMessage(
          "No active household session found. Parents must log in first!",
          Colors.red,
        );
        return;
      }

      final List<dynamic> response = await supabase
          .from('child')
          .select('child_id, child_name')
          .eq('parent_id', parentUser.id)
          .eq('pin', _pinController.text.trim())
          .limit(1);

      if (!mounted) return;

      if (response.isNotEmpty) {
        final childData = response.first as Map<String, dynamic>;

        final String childId = childData['child_id'].toString();
        final String childName = childData['child_name']?.toString() ?? 'Hero';

        _pinController.clear();

        _showMessage(
          "Welcome back, $childName! 🚀",
          const Color(0xFF5E17EB),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChildHomepage(
              childId: childId.toString(),
            ),
          ),
        );
      } else {
        _showMessage(
          "Incorrect PIN. Try again, Hero!",
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "An error occurred: ${e.toString()}",
        Colors.red,
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
            color: const Color(0xFFF4F6FC),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6FC),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Top bar with back button, title, and help icon.
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                ),
                                color: const Color(0xFF5E17EB),
                                iconSize: 22,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                                                       
                            ],
                          ),

                          const SizedBox(height: 30),

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

                          // Login card for the child PIN.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(38),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF5E17EB).withOpacity(0.06),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 85,
                                  height: 85,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EEFF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF5E17EB),
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.face_unlock_rounded,
                                    size: 45,
                                    color: Color(0xFF5E17EB),
                                  ),
                                ),

                                const SizedBox(height: 24),

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

                                // Four digit PIN input.
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 260),
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
                                      FilteringTextInputFormatter.digitsOnly,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 18,
                                        horizontal: 12,
                                      ),
                                      hintText: '••••',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 12.0,
                                      ),
                                      prefixIcon: const Opacity(
                                        opacity: 0.0,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.visibility_rounded,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      suffixIcon: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: IconButton(
                                          icon: Icon(
                                            _isPinVisible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                            color: const Color(
                                              0xFF5E17EB,
                                            ).withOpacity(0.6),
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

                                // Main child login button.
                                Container(
                                  width: double.infinity,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF5E17EB,
                                        ).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _loginChild,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF5E17EB),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(
                                        0xFF5E17EB,
                                      ).withOpacity(0.6),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Let's Go!",
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.rocket_launch,
                                                size: 22,
                                              ),
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
          ),
        ),
      ),
    );
  }
}