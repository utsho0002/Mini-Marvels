import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'child_homepage.dart';

class GamePlayerPage extends StatefulWidget {
  // We need childId here because every child has a different daily game limit
  // and different usage record in child_game_usage table.
  final String childId;

  final String gameUrl;
  final String gameTitle;

  const GamePlayerPage({
    super.key,
    required this.childId,
    required this.gameUrl,
    required this.gameTitle,
  });

  @override
  State<GamePlayerPage> createState() => _GamePlayerPageState();
}

class _GamePlayerPageState extends State<GamePlayerPage>
    with WidgetsBindingObserver {
  // Supabase client used for reading limits and saving game usage time.
  final SupabaseClient _supabase = Supabase.instance.client;

  // WebView controller used to load games inside the Android app.
  WebViewController? _controller;

  // Loading and error state for the game player.
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;

  // Prevents the player from staying on an endless loading overlay.
  Timer? _gameLoadTimeoutTimer;

  // This saves the time when the child starts playing.
  // Later we calculate how many minutes were played from this value.
  DateTime? _gameStartedAt;

  // This stores how many minutes of the current game session
  // are already saved to Supabase.
  //
  // Example:
  // Child played 5 minutes.
  // We already saved 5 minutes.
  // Then we should not save those same 5 minutes again.
  int _alreadySavedMinutesThisSession = 0;

  // This child's daily limit from child.daily_game_limit_minutes.
  int _dailyLimitMinutes = 60;

  // This child's already used minutes for today from child_game_usage.
  int _usedMinutesBeforeThisSession = 0;

  // This value is shown in the app bar.
  int _remainingMinutes = 0;

  // This timer checks the usage while the child is still inside the game.
  Timer? _liveLimitTimer;

  // This prevents the limit-over action from running multiple times.
  bool _hasBlockedBecauseLimitOver = false;

  // This prevents final save from running multiple times at the same moment.
  bool _isFinalSaveRunning = false;

  @override
  void initState() {
    super.initState();

    // Keep the normal Android bars visible before the game starts loading.
    WidgetsBinding.instance.addObserver(this);
    _keepAppBarsVisible();

    _prepareGamePlayer();
  }

  @override
  void dispose() {
    _liveLimitTimer?.cancel();
    _gameLoadTimeoutTimer?.cancel();

    // Backup save.
    // Normally we save when the child presses back or when the limit is over.
    // This is only a safety net if the page closes in another way.
    _saveUnsavedPlayedMinutes();

    WidgetsBinding.instance.removeObserver(this);

    // Leave the app with normal Android bars visible.
    _keepAppBarsVisible();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Some games try to enter fullscreen again when the app resumes.
    if (state == AppLifecycleState.resumed) {
      _keepAppBarsVisible();
    }
  }

  // Keeps Android status and navigation bars visible while the game is open.
  // This helps stop HTML5 games from making the screen feel like fullscreen mode.
  void _keepAppBarsVisible() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color.fromARGB(255, 124, 58, 237),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // Blocks common browser fullscreen requests from the game page.
  // The game still loads normally, but it should not hide our top controls.
  Future<void> _blockFullscreenRequests(WebViewController controller) async {
    try {
      await controller.runJavaScript(r'''
        (function () {
          if (window.__miniMarvelsFullscreenGuard === true) {
            return;
          }

          window.__miniMarvelsFullscreenGuard = true;

          var blockFullscreen = function () {
            return Promise.resolve();
          };

          if (Element.prototype.requestFullscreen) {
            Element.prototype.requestFullscreen = blockFullscreen;
          }

          if (Element.prototype.webkitRequestFullscreen) {
            Element.prototype.webkitRequestFullscreen = blockFullscreen;
          }

          if (Element.prototype.mozRequestFullScreen) {
            Element.prototype.mozRequestFullScreen = blockFullscreen;
          }

          if (Element.prototype.msRequestFullscreen) {
            Element.prototype.msRequestFullscreen = blockFullscreen;
          }

          document.addEventListener('fullscreenchange', function () {
            try {
              if (document.fullscreenElement && document.exitFullscreen) {
                document.exitFullscreen();
              }
            } catch (error) {}
          }, true);

          document.addEventListener('webkitfullscreenchange', function () {
            try {
              if (document.webkitFullscreenElement &&
                  document.webkitExitFullscreen) {
                document.webkitExitFullscreen();
              }
            } catch (error) {}
          }, true);
        })();
      ''');
    } catch (error) {
      debugPrint('Fullscreen guard script skipped: $error');
    }
  }

  // Prepares daily limit data, starts usage tracking, and opens the game view.
  Future<void> _prepareGamePlayer() async {
    final Uri? uri = Uri.tryParse(widget.gameUrl.trim());

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;

      setState(() {
        _controller = null;
        _errorMessage = 'Invalid game link.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Step 1:
      // Load this child's daily limit and today's already used minutes.
      await _loadCurrentGameLimitStatus();

      // Step 2:
      // If the daily limit is already over before opening the game,
      // send the child back to homepage and show the message there.
      if (_dailyLimitMinutes > 0 &&
          _usedMinutesBeforeThisSession >= _dailyLimitMinutes) {
        _redirectToHomepageWithMessage(
          'Your daily limit is over, do your other work!!',
        );
        return;
      }

      // Step 3:
      // Start counting this game session.
      _gameStartedAt = DateTime.now();

      // Step 4:
      // Start checking the limit while the child is still playing.
      _startLiveLimitTimer();

      // Step 5:
      // Open the game inside the app using Android WebView.
      await _initMobileWebView(uri);
    } catch (error) {
      debugPrint('Game player preparation failed: $error');

      if (!mounted) return;

      setState(() {
        _controller = null;
        _errorMessage = 'Error preparing game player.';
        _isLoading = false;
      });
    }
  }

  // Loads the child's daily game limit and today's already used minutes.
  Future<void> _loadCurrentGameLimitStatus() async {
    final String cleanChildId = widget.childId.trim();

    if (cleanChildId.isEmpty) {
      throw Exception('Child ID is empty.');
    }

    // Get this child's daily limit from the child table.
    final childData = await _supabase
        .from('child')
        .select('daily_game_limit_minutes')
        .eq('child_id', cleanChildId)
        .maybeSingle();

    if (childData != null) {
      final Map<String, dynamic> childMap = Map<String, dynamic>.from(childData);

      _dailyLimitMinutes = _readInt(
        childMap['daily_game_limit_minutes'],
        fallback: 60,
      );
    }

    // Get today's already used game minutes from child_game_usage table.
    _usedMinutesBeforeThisSession = await _getTodayUsedGameMinutes(cleanChildId);

    if (_dailyLimitMinutes <= 0) {
      // 0 means no daily limit.
      _remainingMinutes = 9999;
    } else {
      _remainingMinutes = _dailyLimitMinutes - _usedMinutesBeforeThisSession;

      if (_remainingMinutes < 0) {
        _remainingMinutes = 0;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // Creates the Android WebView and applies browser-like settings for HTML5 games.
  Future<void> _initMobileWebView(Uri uri) async {
    final WebViewController controller = WebViewController();

    _keepAppBarsVisible();

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);

    // Some game portals behave better when the WebView identifies like mobile Chrome.
    await controller.setUserAgent(
      'Mozilla/5.0 (Linux; Android 10; Mobile) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36',
    );

    if (controller.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;

      AndroidWebViewController.enableDebugging(true);

      await androidController.setMediaPlaybackRequiresUserGesture(false);

      try {
        await androidController.setMixedContentMode(
          MixedContentMode.alwaysAllow,
        );
      } catch (error) {
        debugPrint('Mixed content mode could not be set: $error');
      }
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          debugPrint('Game loading progress: $progress');

          if (!mounted) return;

          setState(() {
            _loadingProgress = progress;
          });
        },
        onPageStarted: (String url) {
          debugPrint('Game page started: $url');

          _keepAppBarsVisible();

          _gameLoadTimeoutTimer?.cancel();
          _gameLoadTimeoutTimer = Timer(const Duration(seconds: 35), () {
            if (!mounted) return;

            if (_isLoading && _errorMessage == null) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 100;
              });
            }
          });

          if (!mounted) return;

          setState(() {
            _isLoading = true;
            _loadingProgress = 0;
            _errorMessage = null;
          });
        },
        onPageFinished: (String url) async {
          debugPrint('Game page finished: $url');

          _gameLoadTimeoutTimer?.cancel();
          _keepAppBarsVisible();
          await _blockFullscreenRequests(controller);

          // Give the game canvas enough space and try to trigger common game events.
          try {
            await controller.runJavaScript('''
              window.focus();
              window.dispatchEvent(new Event('resize'));
              document.body.style.margin = '0';
              document.body.style.padding = '0';
              document.documentElement.style.margin = '0';
              document.documentElement.style.padding = '0';
              document.documentElement.style.height = '100%';
              document.body.style.height = '100%';
            ''');
          } catch (error) {
            debugPrint('Post-load game script skipped: $error');
          }

          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _loadingProgress = 100;
          });
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('Game WebView resource error.');
          debugPrint('Description: ${error.description}');
          debugPrint('Error code: ${error.errorCode}');
          debugPrint('URL: ${error.url}');
          debugPrint('Main frame: ${error.isForMainFrame}');

          // Ignore failed secondary files. Games often load optional icons,
          // ads, sounds, or scripts that can fail without stopping gameplay.
          if (error.isForMainFrame == false) {
            return;
          }

          _gameLoadTimeoutTimer?.cancel();

          if (!mounted) return;

          setState(() {
            _errorMessage =
                'Game could not load. Please check the game link or try another game.';
            _isLoading = false;
          });
        },
        onNavigationRequest: (NavigationRequest request) {
          final Uri? requestedUri = Uri.tryParse(request.url);

          if (requestedUri == null) {
            return NavigationDecision.prevent;
          }

          if (requestedUri.scheme == 'http' ||
              requestedUri.scheme == 'https') {
            return NavigationDecision.navigate;
          }

          return NavigationDecision.prevent;
        },
      ),
    );

    if (!mounted) return;

    setState(() {
      _controller = controller;
      _isLoading = true;
      _loadingProgress = 0;
      _errorMessage = null;
    });

    _keepAppBarsVisible();

    debugPrint('Loading game URL: ${uri.toString()}');
    await controller.loadRequest(uri);
  }

  // Starts periodic usage saving while the child stays inside the game.
  void _startLiveLimitTimer() {
    _liveLimitTimer?.cancel();

    _liveLimitTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) async {
        await _checkAndUpdateLiveGameUsage();
      },
    );
  }

  // Saves newly played minutes and blocks the game if the daily limit is reached.
  Future<void> _checkAndUpdateLiveGameUsage() async {
    if (_hasBlockedBecauseLimitOver == true) {
      return;
    }

    final DateTime? startedAt = _gameStartedAt;

    if (startedAt == null) {
      return;
    }

    final int playedSeconds = DateTime.now().difference(startedAt).inSeconds;

    if (playedSeconds <= 0) {
      return;
    }

    // Count partial minutes as 1 minute.
    //
    // Example:
    // 10 seconds = 1 minute
    // 70 seconds = 2 minutes
    final int totalPlayedMinutesThisSession = (playedSeconds + 59) ~/ 60;

    // Save only the minutes that are not saved yet.
    final int newMinutesToSave =
        totalPlayedMinutesThisSession - _alreadySavedMinutesThisSession;

    if (newMinutesToSave > 0) {
      await _addMinutesToTodayUsage(newMinutesToSave);

      _alreadySavedMinutesThisSession = totalPlayedMinutesThisSession;
    }

    final int totalUsedNow =
        _usedMinutesBeforeThisSession + _alreadySavedMinutesThisSession;

    if (_dailyLimitMinutes > 0) {
      int remaining = _dailyLimitMinutes - totalUsedNow;

      if (remaining < 0) {
        remaining = 0;
      }

      if (mounted) {
        setState(() {
          _remainingMinutes = remaining;
        });
      }

      if (totalUsedNow >= _dailyLimitMinutes) {
        await _handleLimitOverWhilePlaying();
      }
    }
  }

  // Handles the moment the child reaches the allowed daily game time.
  Future<void> _handleLimitOverWhilePlaying() async {
    if (_hasBlockedBecauseLimitOver == true) {
      return;
    }

    _hasBlockedBecauseLimitOver = true;
    _liveLimitTimer?.cancel();

    // Save the last unsaved seconds/minutes before leaving the game.
    await _saveUnsavedPlayedMinutes();

    // Now go to homepage first.
    // The warning message will be shown on the homepage, not inside the game.
    _redirectToHomepageWithMessage(
      'Your daily limit is over, do your other work!!',
    );
  }

  // Sends the child back to the homepage and displays a clear message there.
  void _redirectToHomepageWithMessage(String message) {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) {
          return _ChildHomeWithMessage(
            childId: widget.childId,
            message: message,
          );
        },
      ),
      (route) => false,
    );
  }

  // Reads today's saved usage for this child.
  Future<int> _getTodayUsedGameMinutes(String childId) async {
    final String today = _getTodayDateText();

    final usageData = await _supabase
        .from('child_game_usage')
        .select('used_minutes')
        .eq('child_id', childId)
        .eq('usage_date', today)
        .maybeSingle();

    if (usageData == null) {
      return 0;
    }

    final Map<String, dynamic> usageMap = Map<String, dynamic>.from(usageData);

    return _readInt(usageMap['used_minutes'], fallback: 0);
  }

  // Adds only newly played minutes to today's usage row.
  Future<void> _addMinutesToTodayUsage(int minutesToAdd) async {
    final String cleanChildId = widget.childId.trim();

    if (cleanChildId.isEmpty) {
      debugPrint('Game usage not saved because childId is empty.');
      return;
    }

    if (minutesToAdd <= 0) {
      return;
    }

    try {
      final String today = _getTodayDateText();

      // First check if today's row exists for this child.
      final usageData = await _supabase
          .from('child_game_usage')
          .select('used_minutes')
          .eq('child_id', cleanChildId)
          .eq('usage_date', today)
          .maybeSingle();

      if (usageData == null) {
        await _supabase.from('child_game_usage').insert({
          'child_id': cleanChildId,
          'usage_date': today,
          'used_minutes': minutesToAdd,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });

        debugPrint('Created game usage row: $minutesToAdd minutes');
        return;
      }

      final Map<String, dynamic> usageMap =
          Map<String, dynamic>.from(usageData);

      final int oldUsedMinutes = _readInt(
        usageMap['used_minutes'],
        fallback: 0,
      );

      int newUsedMinutes = oldUsedMinutes + minutesToAdd;

      if (newUsedMinutes > 1440) {
        newUsedMinutes = 1440;
      }

      await _supabase
          .from('child_game_usage')
          .update({
            'used_minutes': newUsedMinutes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('child_id', cleanChildId)
          .eq('usage_date', today);

      debugPrint(
        'Updated game usage: $oldUsedMinutes + $minutesToAdd = $newUsedMinutes',
      );
    } catch (error) {
      debugPrint('Failed to update live game usage: $error');
    }
  }

  // Final safety save used when leaving or closing the game screen.
  Future<void> _saveUnsavedPlayedMinutes() async {
    if (_isFinalSaveRunning == true) {
      return;
    }

    _isFinalSaveRunning = true;

    try {
      final DateTime? startedAt = _gameStartedAt;

      if (startedAt == null) {
        return;
      }

      final int playedSeconds = DateTime.now().difference(startedAt).inSeconds;

      if (playedSeconds <= 0) {
        return;
      }

      final int totalPlayedMinutesThisSession = (playedSeconds + 59) ~/ 60;

      final int unsavedMinutes =
          totalPlayedMinutesThisSession - _alreadySavedMinutesThisSession;

      if (unsavedMinutes > 0) {
        await _addMinutesToTodayUsage(unsavedMinutes);

        _alreadySavedMinutesThisSession = totalPlayedMinutesThisSession;
      }
    } finally {
      _isFinalSaveRunning = false;
    }
  }

  // Supabase date column uses this format: YYYY-MM-DD
  String _getTodayDateText() {
    final DateTime now = DateTime.now();

    final String year = now.year.toString().padLeft(4, '0');
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  // Reloads the current game without changing the active usage session.
  Future<void> _reloadGame() async {
    final Uri? uri = Uri.tryParse(widget.gameUrl.trim());

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Invalid game link.';
        _isLoading = false;
      });
      return;
    }

    final WebViewController? controller = _controller;

    if (controller == null) {
      await _prepareGamePlayer();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _loadingProgress = 0;
        _errorMessage = null;
      });

      await controller.reload();
    } catch (error) {
      debugPrint('Game reload failed: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not reload the game.';
        _isLoading = false;
      });
    }
  }

  // Handles back navigation and saves usage before leaving the player.
  Future<void> _handleBackButton() async {
    final WebViewController? controller = _controller;

    if (controller != null) {
      final bool canGoBack = await controller.canGoBack();

      if (canGoBack) {
        await controller.goBack();
        return;
      }
    }

    await _saveUnsavedPlayedMinutes();

    if (!mounted) return;
    Navigator.pop(context);
  }

  // Provides a safe title for the app bar.
  String _getTitle() {
    final String title = widget.gameTitle.trim();

    if (title.isEmpty) {
      return 'Game';
    }

    return title;
  }

  // Validates the game URL before it is loaded in WebView.
  bool _isValidGameUrl() {
    final Uri? uri = Uri.tryParse(widget.gameUrl.trim());

    if (uri == null) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  // Text shown under the game title in the app bar.
  String _getRemainingText() {
    if (_dailyLimitMinutes <= 0) {
      return 'No daily limit';
    }

    return '$_remainingMinutes min left';
  }

  // Fixed top bar for the game screen.
  // It stays outside the WebView area so games cannot cover the back button,
  // game title, remaining minutes text, or refresh button.
  Widget _buildGameHeader() {
    return Container(
      height: 58,
      color: const Color.fromARGB(255, 124, 58, 237),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
            onPressed: _handleBackButton,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getTitle(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getRemainingText(),
                  style: const TextStyle(
                    color: Color(0xFFFFCC33),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
            onPressed: _reloadGame,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WebViewController? controller = _controller;

    return WillPopScope(
      onWillPop: () async {
        final WebViewController? controller = _controller;

        if (controller != null) {
          final bool canGoBack = await controller.canGoBack();

          if (canGoBack) {
            await controller.goBack();
            return false;
          }
        }

        await _saveUnsavedPlayedMinutes();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black12,
        body: Center(
          child: Container(
            // Fits the game player to the current Android device or emulator width.
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
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildGameHeader(),
                    if (_loadingProgress < 100 && _errorMessage == null)
                      LinearProgressIndicator(
                        value: _loadingProgress / 100,
                        backgroundColor:
                            const Color.fromARGB(255, 124, 58, 237)
                                .withOpacity(0.12),
                        color: const Color(0xFFFFCC33),
                        minHeight: 4,
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          if (_errorMessage != null)
                            _buildErrorView()
                          else if (!_isValidGameUrl())
                            _buildInvalidUrlView()
                          else if (controller == null)
                            _buildInitializingView()
                          else
                            WebViewWidget(
                              controller: controller,
                            ),
                          if (_isLoading && _errorMessage == null)
                            _buildLoadingOverlay(),
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

  // Initial view shown while the game player is being prepared.
  Widget _buildInitializingView() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text(
          'Preparing game player...',
          style: TextStyle(
            color: Color.fromARGB(255, 124, 58, 237),
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Overlay shown while the WebView is loading the game.
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.92),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 26,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: const Color.fromARGB(255, 124, 58, 237).withOpacity(0.16),
              width: 1.4,
            ),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color.fromARGB(255, 124, 58, 237),
              ),
              SizedBox(height: 16),
              Text(
                'Loading game...',
                style: TextStyle(
                  color: Color.fromARGB(255, 124, 58, 237),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Stay inside the app and have fun!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Message shown when the game link is not usable.
  Widget _buildInvalidUrlView() {
    return _buildMessageView(
      icon: Icons.link_off_rounded,
      title: 'Invalid Game Link',
      message: 'This game link is not valid. Please use an http or https link.',
      buttonText: 'Try Again',
      onPressed: _prepareGamePlayer,
    );
  }

  // Message shown when the game fails after loading starts.
  Widget _buildErrorView() {
    return _buildMessageView(
      icon: Icons.error_outline_rounded,
      title: 'Game Stopped',
      message: _errorMessage ?? 'Something went wrong.',
      buttonText: 'Go Back',
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }

  // Reusable full-screen message view for player errors.
  Widget _buildMessageView({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 183, 151, 239),
            Color.fromARGB(255, 124, 58, 237),
            Color.fromARGB(255, 124, 32, 232),
          ],
        ),
      ),
      child: Stack(
        children: [
          _buildGamePatternBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: const Color.fromARGB(255, 124, 58, 237),
                      size: 58,
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
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC33),
                        foregroundColor:
                            const Color.fromARGB(255, 124, 58, 237),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: onPressed,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(
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
            ),
          ),
        ],
      ),
    );
  }

  // Decorative gamepad pattern used behind error states.
  Widget _buildGamePatternBackground() {
    return Opacity(
      opacity: 0.15,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
        ),
        itemCount: 60,
        itemBuilder: (context, index) {
          return const Icon(
            Icons.videogame_asset_rounded,
            color: Colors.white,
            size: 40,
          );
        },
      ),
    );
  }
}

// This small wrapper opens ChildHomepage first.
// After the homepage appears, it shows the message there.
//
// This keeps the user experience clean:
// Game ends -> go to homepage -> show message.
class _ChildHomeWithMessage extends StatefulWidget {
  final String childId;
  final String message;

  const _ChildHomeWithMessage({
    required this.childId,
    required this.message,
  });

  @override
  State<_ChildHomeWithMessage> createState() => _ChildHomeWithMessageState();
}

class _ChildHomeWithMessageState extends State<_ChildHomeWithMessage> {
  bool _messageShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_messageShown == true) {
      return;
    }

    _messageShown = true;

    // Wait until the homepage is visible.
    // Then show the message on the homepage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          content: Text(
            widget.message,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChildHomepage(
      childId: widget.childId,
    );
  }
}