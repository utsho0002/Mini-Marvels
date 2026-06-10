import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_master_page.dart';

class QuizPage extends StatefulWidget {
  final String childId;
  final String storyId;

  // XP is calculated here, but added to child table in TaskMasterPage.
  final int xpPerCorrectAnswer;

  const QuizPage({
    super.key,
    required this.childId,
    required this.storyId,
    this.xpPerCorrectAnswer = 10,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  // Stores selected answers by question index.
  final Map<int, String> _selectedAnswers = {};

  // Page state used while loading questions and submitting results.
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Quiz questions loaded from Supabase for the selected story video.
  List<_VideoQuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizQuestions();
  }

  // Loads active quiz questions for the current story video.
  Future<void> _fetchQuizQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('video_quiz_questions')
          .select(
            'question_id, story_id, question_text, option_a, option_b, option_c, correct_option, question_order',
          )
          .eq('story_id', widget.storyId)
          .eq('is_active', true)
          .order('question_order', ascending: true);

      final List<_VideoQuizQuestion> loadedQuestions = (response as List)
          .map(
            (item) => _VideoQuizQuestion.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _questions = loadedQuestions;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Quiz loading failed: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Quiz could not load. Please try again.';
      });
    }
  }

  // The submit button becomes active only after every question has an answer.
  bool get _allQuestionsAnswered {
    return _questions.isNotEmpty &&
        _selectedAnswers.length == _questions.length;
  }

  // Calculates quiz score and sends the child to the reward result screen.
  Future<void> _calculateAndSubmitResults() async {
    if (_isSubmitting) {
      return;
    }

    if (!_allQuestionsAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions first.'),
          backgroundColor: Color.fromARGB(255, 124, 58, 237),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    int correct = 0;
    int wrong = 0;

    for (int i = 0; i < _questions.length; i++) {
      final _VideoQuizQuestion question = _questions[i];
      final String? selectedOption = _selectedAnswers[i];

      if (selectedOption == question.correctOption) {
        correct++;
      } else {
        wrong++;
      }
    }

    final int earnedXp = correct * widget.xpPerCorrectAnswer;

    if (!mounted) return;

    // The reward screen handles showing the result and applying earned XP.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TaskMasterPage(
          correctCount: correct,
          wrongCount: wrong,
          xpReward: earnedXp,
          childId: widget.childId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Uses the available screen width for a smooth Android emulator layout.
          final double pageWidth = constraints.maxWidth;

          return Center(
            child: Container(
              width: pageWidth,
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
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  title: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mission Quiz',
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
                ),
                body: QuizPageBackground(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 16,
                      right: 16,
                      bottom: 20,
                    ),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Builds the correct screen state: loading, error, empty, or quiz content.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageCard(
        icon: Icons.error_outline_rounded,
        title: 'Oops!',
        message: _errorMessage!,
        buttonText: 'Try Again',
        onPressed: _fetchQuizQuestions,
      );
    }

    if (_questions.isEmpty) {
      return _buildMessageCard(
        icon: Icons.quiz_rounded,
        title: 'No Quiz Found',
        message: 'No quiz questions are available for this video yet.',
        buttonText: 'Back',
        onPressed: () {
          Navigator.pop(context);
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _questions.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final _VideoQuizQuestion question = _questions[index];

              return _buildQuestionCard(
                question: question,
                index: index,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildSubmitButton(),
      ],
    );
  }

  // Builds a single question card with three answer choices.
  Widget _buildQuestionCard({
    required _VideoQuizQuestion question,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${index + 1}: ${question.questionText}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          _buildOptionTile(
            questionIndex: index,
            optionKey: 'A',
            optionText: question.optionA,
          ),
          _buildOptionTile(
            questionIndex: index,
            optionKey: 'B',
            optionText: question.optionB,
          ),
          _buildOptionTile(
            questionIndex: index,
            optionKey: 'C',
            optionText: question.optionC,
          ),
        ],
      ),
    );
  }

  // Builds one selectable option row for a quiz question.
  Widget _buildOptionTile({
    required int questionIndex,
    required String optionKey,
    required String optionText,
  }) {
    final bool isSelected = _selectedAnswers[questionIndex] == optionKey;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color.fromARGB(255, 124, 58, 237).withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color.fromARGB(255, 124, 58, 237).withOpacity(0.35)
              : Colors.black12,
          width: 1.5,
        ),
      ),
      child: RadioListTile<String>(
        title: Text(
          '$optionKey. $optionText',
          style: TextStyle(
            color: isSelected
                ? const Color.fromARGB(255, 124, 58, 237)
                : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        value: optionKey,
        activeColor: const Color.fromARGB(255, 124, 58, 237),
        groupValue: _selectedAnswers[questionIndex],
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            _selectedAnswers[questionIndex] = value;
          });
        },
        contentPadding: const EdgeInsets.only(left: 8, right: 8),
      ),
    );
  }

  // Main action button for submitting answers and claiming XP.
  Widget _buildSubmitButton() {
    final bool canSubmit = _allQuestionsAnswered && !_isSubmitting;

    return GestureDetector(
      onTap: canSubmit ? _calculateAndSubmitResults : null,
      child: Opacity(
        opacity: canSubmit ? 1 : 0.65,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color.fromARGB(255, 124, 58, 237),
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color.fromARGB(255, 124, 58, 237),
                  size: 22,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : 'Submit Answers & Claim XP!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color.fromARGB(255, 124, 58, 237),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable card for error and empty quiz states.
  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 54,
              color: const Color.fromARGB(255, 124, 58, 237),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color.fromARGB(255, 124, 58, 237),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC33),
                foregroundColor: const Color.fromARGB(255, 124, 58, 237),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Local model for one quiz question row from Supabase.
class _VideoQuizQuestion {
  final String questionId;
  final String storyId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String correctOption;
  final int questionOrder;

  const _VideoQuizQuestion({
    required this.questionId,
    required this.storyId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
    required this.questionOrder,
  });

  // Converts a Supabase row into a safer Dart object.
  factory _VideoQuizQuestion.fromMap(Map<String, dynamic> map) {
    return _VideoQuizQuestion(
      questionId: (map['question_id'] ?? '').toString(),
      storyId: (map['story_id'] ?? '').toString(),
      questionText: (map['question_text'] ?? '').toString(),
      optionA: (map['option_a'] ?? '').toString(),
      optionB: (map['option_b'] ?? '').toString(),
      optionC: (map['option_c'] ?? '').toString(),
      correctOption: (map['correct_option'] ?? '').toString().toUpperCase(),
      questionOrder: int.tryParse((map['question_order'] ?? 0).toString()) ?? 0,
    );
  }
}

// Shared quiz background with gradient and soft sky decoration.
class QuizPageBackground extends StatelessWidget {
  final Widget child;

  const QuizPageBackground({
    super.key,
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
              painter: QuizSkyElementsPainter(),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

// Simple value object used by the background painter.
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

// Paints decorative cloud and star icons behind the quiz content.
class QuizSkyElementsPainter extends CustomPainter {
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
  bool shouldRepaint(covariant QuizSkyElementsPainter oldDelegate) {
    return false;
  }
}