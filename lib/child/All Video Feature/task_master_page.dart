import 'package:flutter/material.dart';
import 'package:project_1/child/child_homepage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskMasterPage extends StatefulWidget {
  final int correctCount;
  final int wrongCount;
  final int xpReward;
  final String childId;

  const TaskMasterPage({
    super.key,
    required this.correctCount,
    required this.wrongCount,
    required this.xpReward,
    required this.childId,
  });

  @override
  State<TaskMasterPage> createState() => _TaskMasterPageState();
}

class _TaskMasterPageState extends State<TaskMasterPage> {
  // Tracks the XP save process after the quiz result is shown.
  bool _isSavingXp = true;
  bool _xpSaved = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _addXpToChildTable();
  }

  // Adds the earned XP to the child's profile in Supabase.
  Future<void> _addXpToChildTable() async {
    try {
      if (widget.xpReward <= 0) {
        if (!mounted) return;

        setState(() {
          _isSavingXp = false;
          _xpSaved = true;
        });
        return;
      }

      // Read the current XP first so the new reward can be added safely.
      final childData = await Supabase.instance.client
          .from('child')
          .select('total_xp')
          .eq('child_id', widget.childId)
          .maybeSingle();

      final int currentXp = int.tryParse(
            (childData?['total_xp'] ?? 0).toString(),
          ) ??
          0;

      final int updatedXp = currentXp + widget.xpReward;

      // Save the updated XP total back to the child profile.
      await Supabase.instance.client.from('child').update({
        'total_xp': updatedXp,
      }).eq('child_id', widget.childId);

      if (!mounted) return;

      setState(() {
        _isSavingXp = false;
        _xpSaved = true;
      });
    } catch (error) {
      debugPrint('XP update failed: $error');

      if (!mounted) return;

      setState(() {
        _isSavingXp = false;
        _xpSaved = false;
        _errorMessage = 'XP could not be saved. Please try again.';
      });
    }
  }

  // Returns the child to the homepage and clears the quiz flow from navigation.
  void _goToChildHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ChildHomepage(
          childId: widget.childId,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          // Fits the result screen to the current Android device or emulator width.
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Mission Success!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              automaticallyImplyLeading: false,
            ),
            body: _ResultPageBackground(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 16,
                  right: 16,
                  bottom: 20,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildResultCard(),
                        const SizedBox(height: 35),
                        _buildReturnButton(),
                        const SizedBox(height: 30),
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

  // Main summary card showing score, reward, and save status.
  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🏆',
            style: TextStyle(fontSize: 70),
          ),
          const SizedBox(height: 12),
          const Text(
            'Task Master!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color.fromARGB(255, 124, 58, 237),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You did an amazing job!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 28),
          // Result breakdown for the completed quiz.
          Row(
            children: [
              Expanded(
                child: _buildScoreBox(
                  count: widget.correctCount,
                  label: 'CORRECT',
                  backgroundColor: const Color(0xFFE8F5E9),
                  borderColor: Colors.green.shade200,
                  textColor: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildScoreBox(
                  count: widget.wrongCount,
                  label: 'WRONG',
                  backgroundColor: const Color(0xFFFFEBEE),
                  borderColor: Colors.red.shade200,
                  textColor: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Total Rewards Claimed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildXpRewardBox(),
          const SizedBox(height: 14),
          _buildXpSaveStatus(),
        ],
      ),
    );
  }

  // Small score tile used for correct and wrong answer counts.
  Widget _buildScoreBox({
    required int count,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Displays the total XP earned from the quiz attempt.
  Widget _buildXpRewardBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 124, 58, 237).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color.fromARGB(255, 124, 58, 237).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.stars_rounded,
            color: Colors.orange,
            size: 26,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '+${widget.xpReward} XP Earned!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color.fromARGB(255, 124, 58, 237),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shows whether the XP update is saving, saved, or needs retry.
  Widget _buildXpSaveStatus() {
    if (_isSavingXp) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color.fromARGB(255, 124, 58, 237),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Saving XP...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      );
    }

    if (_xpSaved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 20,
          ),
          SizedBox(width: 6),
          Text(
            'XP added to your profile!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          _errorMessage ?? 'XP could not be saved.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _isSavingXp = true;
              _errorMessage = null;
            });
            _addXpToChildTable();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry Save XP'),
        ),
      ],
    );
  }

  // Home button is enabled after the XP save process finishes.
  Widget _buildReturnButton() {
    return GestureDetector(
      onTap: _isSavingXp ? null : _goToChildHome,
      child: Opacity(
        opacity: _isSavingXp ? 0.65 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC33),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color: Color.fromARGB(255, 124, 58, 237),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Back to Home',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color.fromARGB(255, 124, 58, 237),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared result background with gradient and soft decorative elements.
class _ResultPageBackground extends StatelessWidget {
  final Widget child;

  const _ResultPageBackground({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 183, 151, 239),
            Color.fromARGB(255, 124, 58, 237),
            Color.fromARGB(255, 124, 32, 232),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ResultSkyElementsPainter(),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

// Simple data object for each background decoration.
class _SkyElement {
  final IconData icon;
  final Offset position;
  final double size;

  const _SkyElement({
    required this.icon,
    required this.position,
    required this.size,
  });
}

// Paints lightweight cloud and star decorations behind the result screen.
class _ResultSkyElementsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const List<_SkyElement> elements = [
      _SkyElement(
        icon: Icons.cloud,
        position: Offset(0.10, 0.08),
        size: 55,
      ),
      _SkyElement(
        icon: Icons.star,
        position: Offset(0.80, 0.12),
        size: 20,
      ),
      _SkyElement(
        icon: Icons.star,
        position: Offset(0.25, 0.22),
        size: 24,
      ),
      _SkyElement(
        icon: Icons.cloud,
        position: Offset(0.70, 0.32),
        size: 65,
      ),
      _SkyElement(
        icon: Icons.cloud,
        position: Offset(0.15, 0.48),
        size: 50,
      ),
      _SkyElement(
        icon: Icons.star,
        position: Offset(0.88, 0.55),
        size: 18,
      ),
      _SkyElement(
        icon: Icons.star,
        position: Offset(0.30, 0.68),
        size: 25,
      ),
      _SkyElement(
        icon: Icons.cloud,
        position: Offset(0.75, 0.78),
        size: 60,
      ),
      _SkyElement(
        icon: Icons.star,
        position: Offset(0.18, 0.88),
        size: 16,
      ),
    ];

    for (final element in elements) {
      final double targetX = size.width * element.position.dx;
      final double targetY = size.height * element.position.dy;

      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(element.icon.codePoint),
          style: TextStyle(
            fontSize: element.size,
            fontFamily: element.icon.fontFamily,
            package: element.icon.fontPackage,
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final double finalX = targetX - (textPainter.width / 2);
      final double finalY = targetY - (textPainter.height / 2);

      textPainter.paint(canvas, Offset(finalX, finalY));
    }
  }

  @override
  bool shouldRepaint(covariant _ResultSkyElementsPainter oldDelegate) {
    return false;
  }
}