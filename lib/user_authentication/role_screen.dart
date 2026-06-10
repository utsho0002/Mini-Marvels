// lib/user_authentication/role_screen.dart
import 'package:flutter/material.dart';
import 'package:project_1/user_authentication/child_login.dart';
import 'package:project_1/user_authentication/parent_register.dart';
import 'package:project_1/user_authentication/parent_authentication.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

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
            color: const Color(0xFFF1F5F9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 35,
                spreadRadius: 4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      // App title and opening question.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E17EB).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'The Mini Marvels',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5E17EB),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Who are you?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A), 
                          letterSpacing: -0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 36),

                      // Child entry card.
                      RoleCard(
                        backgroundColor: const Color(0xFF6C3DF4),
                        textColor: Colors.white,
                        title: 'Child',
                        subtitle: 'Learn & Play!',
                        imageUrl: 'https://thumbs.dreamstime.com/b/school-kids-smiling-backpacks-happy-students-running-backpack-vector-illustration-graphic-design-152902096.jpg',
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const ChildLogin())
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Parent entry card.
                      RoleCard(
                        backgroundColor: const Color(0xFFFFC914),
                        textColor: const Color(0xFF403000),
                        title: 'Parent',
                        subtitle: 'Manage & Track',
                        imageUrl: 'https://media.istockphoto.com/id/2206013438/vector/a-dark-skinned-mother-reads-a-book-to-her-daughter-time-with-family-at-home-a-girl-sitting.jpg?s=612x612&w=0&k=20&c=poVgQ-vvLIp1tLuoIs3eyv-liprnCrsDn6bxT4X3I8Q=',
                        onTap: () {
                          // Send logged-in parents to PIN check first.
                          final currentUser = Supabase.instance.client.auth.currentUser;

                          if (currentUser != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ParentAuthentication()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ParentRegister()),
                            );
                          }
                        },
                      ),
                    ],
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

// Reusable card for child and parent role choices.
class RoleCard extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.backgroundColor,
    required this.textColor,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 185,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text side of the card.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "Enter →",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Illustration side of the card.
                Container(
                  width: 120,
                  height: 135,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
                            strokeWidth: 2.5,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 36,
                            color: textColor.withOpacity(0.4),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}