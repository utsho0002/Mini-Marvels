import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarveyChatPage extends StatefulWidget {
  final String childId;

  const MarveyChatPage({
    Key? key,
    required this.childId,
  }) : super(key: key);

  @override
  State<MarveyChatPage> createState() => _MarveyChatPageState();
}

class _MarveyChatPageState extends State<MarveyChatPage> {
  // Supabase client used to call the Marvey Edge Function.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Controllers for message input and automatic chat scrolling.
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Messages are kept only while this page is open.
  final List<_ChatMessage> _messages = [];
  // UI state for message sending.
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _messages.add(
      _ChatMessage(
        sender: 'marvey',
        text:
            'Hi explorer! I’m Marvey. You can ask me about learning, stories, quizzes, tasks, feelings, or good habits.',
      ),
    );
  }

  // Sends a small recent context window so Marvey can answer follow-up questions.
  List<Map<String, String>> _buildHistoryForRequest() {
    final List<_ChatMessage> usefulMessages = _messages.where((message) {
      final String text = message.text.trim();

      if (text.isEmpty) return false;

      final bool isDefaultWelcome = message.sender == 'marvey' &&
          text.startsWith('Hi explorer! I’m Marvey.');

      return !isDefaultWelcome;
    }).toList();

    final List<_ChatMessage> limitedMessages = usefulMessages.length > 8
        ? usefulMessages.sublist(usefulMessages.length - 8)
        : usefulMessages;

    return limitedMessages.map((message) {
      return {
        'role': message.sender == 'child' ? 'child' : 'marvey',
        'text': message.text,
      };
    }).toList();
  }

  // Adds a Marvey reply to the chat and scrolls to the latest message.
  void _addMarveyReply(String reply) {
    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'marvey',
          text: reply,
        ),
      );
    });

    _scrollToBottom();
  }

  // Converts technical connection errors into child-friendly messages.
  String _getFriendlyConnectionMessage(dynamic error) {
    final String errorText = error.toString().toLowerCase();

    debugPrint('Marvey connection error: $error');

    if (error is TimeoutException || errorText.contains('timeout')) {
      return 'Marvey is taking too long to answer. Please try again in a moment.';
    }

    if (errorText.contains('socket') ||
        errorText.contains('network') ||
        errorText.contains('connection') ||
        errorText.contains('failed host lookup')) {
      return 'Marvey cannot connect right now. Please check the internet and try again.';
    }

    if (errorText.contains('function') ||
        errorText.contains('edge') ||
        errorText.contains('500') ||
        errorText.contains('503') ||
        errorText.contains('504')) {
      return 'Marvey had trouble connecting to the AI brain. Please try again in a moment.';
    }

    if (errorText.contains('429') || errorText.contains('quota')) {
      return 'Marvey is getting too many questions right now. Please try again after a little while.';
    }

    return 'Oops! Marvey had a little problem. Please try again in a moment.';
  }

  // Sends the child's question to the Supabase Edge Function and displays Marvey's reply.
  Future<void> _sendMessage() async {
    final String userMessage = _messageController.text.trim();

    if (userMessage.isEmpty || _isSending) return;

    final List<Map<String, String>> historyForRequest =
        _buildHistoryForRequest();

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'child',
          text: userMessage,
        ),
      );

      _messageController.clear();
      _isSending = true;
    });

    _scrollToBottom();

    try {
      // The timeout stops the chat from waiting forever if Gemini or the
      // Supabase Edge Function is slow.
      final response = await _supabase.functions.invoke(
        'marvey-chat',
        body: {
          'childId': widget.childId,
          'message': userMessage,
          'history': historyForRequest,
        },
      ).timeout(
        const Duration(seconds: 40),
      );

      final dynamic data = response.data;

      String reply =
          'Marvey could not answer right now. Please try again later.';

      if (data is Map && data['reply'] != null) {
        reply = data['reply'].toString().trim();
      } else if (data is Map && data['error'] != null) {
        // Keep the real function error in debug console,
        // but show a safe message to the child.
        debugPrint('Marvey function returned error: ${data['error']}');

        reply =
            'Marvey had trouble connecting to the AI brain. Please try again in a moment.';
      }

      if (reply.isEmpty) {
        reply = 'Marvey could not answer right now. Please try again later.';
      }

      _addMarveyReply(reply);
    } catch (error) {
      final String reply = _getFriendlyConnectionMessage(error);

      _addMarveyReply(reply);

      _showSnackBar(
        'Marvey connection problem. Please try again.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Keeps the newest message visible after sending or receiving a reply.
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Shows short feedback for chat or network-related issues.
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Intro card that explains how the child can use Marvey.
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE9D5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF7C3AED),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marvey is here!',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Type a question and Marvey will help.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds each chat bubble with separate styling for child and Marvey messages.
  Widget _buildMessageBubble(_ChatMessage message) {
    final bool isChild = message.sender == 'child';

    return Align(
      alignment: isChild ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isChild ? Colors.orangeAccent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isChild ? 18 : 4),
            bottomRight: Radius.circular(isChild ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isChild ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  // Temporary bubble shown while the AI response is being prepared.
  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7C3AED),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Marvey is thinking...',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          // Fits the chat screen to the current Android device or emulator width.
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Ask Marvey',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: const Color(0xFF7C3AED),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Container(
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      children: [
                        _buildWelcomeCard(),
                        ..._messages.map(_buildMessageBubble),
                        if (_isSending) _buildThinkingBubble(),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  maxLength: 300,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: 'Ask Marvey anything safe...',
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _isSending ? null : _sendMessage,
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: _isSending
                                        ? Colors.grey
                                        : Colors.orangeAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
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

// Lightweight local message model for the current chat session.
class _ChatMessage {
  final String sender;
  final String text;

  _ChatMessage({
    required this.sender,
    required this.text,
  });
}