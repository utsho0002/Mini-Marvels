import 'package:flutter/material.dart';
import 'package:project_1/user_authentication/child_login.dart';
import 'package:project_1/user_authentication/parent_register.dart'; // Fixed the .dart.dart typo here
import 'package:project_1/user_authentication/parent_authentication.dart'; // Imported your authentication gate
import 'package:supabase_flutter/supabase_flutter.dart'; // Required to check session status

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  // --- Header Section ---
                  const Text(
                    'The Mini Marvels',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E17EB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Who are you?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E17EB),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // --- Selection Cards Section ---
                  // Child Card
                  RoleCard(
                    backgroundColor: const Color(0xFF6C3DF4),
                    textColor: Colors.white,
                    title: 'Child',
                    imagePath: 'assets/child_avatar.png',
                    fallbackIcon: Icons.face,
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const ChildLogin())
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Parent Card with Auth State Verification Logic
                  RoleCard(
                    backgroundColor: const Color(0xFFFFC914),
                    textColor: const Color(0xFF403000),
                    title: 'Parent',
                    imagePath: 'assets/parent_avatar.png',
                    fallbackIcon: Icons.person,
                    onTap: () {
                      // ─── CHECKING LOGGED-IN SESSION STATUS ───────────────────
                      final currentUser = Supabase.instance.client.auth.currentUser;

                      if (currentUser != null) {
                        // User session exists -> redirect to PIN Authentication check
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ParentAuthentication()),
                        );
                      } else {
                        // No active user session -> send to Parent Register page
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ParentRegister()),
                        );
                      }
                      // ─────────────────────────────────────────────────────────
                    },
                  ),
                  
                  const SizedBox(height: 40),

                  // --- Language Selector Button ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE3F9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          color: Color(0xFF5E17EB),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'বাং / EN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
    );
  }
}

// --- Role Card Widget ---
class RoleCard extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final String title;
  final String imagePath;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.backgroundColor,
    required this.textColor,
    required this.title,
    required this.imagePath,
    required this.fallbackIcon,
    required this.onTap, 
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar Frame
            Container(
              width: 90,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(45),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(45),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.all(8),
                      child: Icon(fallbackIcon, size: 40, color: textColor),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}