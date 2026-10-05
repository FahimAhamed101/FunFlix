import 'dart:async';

import 'package:flutter/material.dart';

import 'data/credentials_store.dart';
import 'data/movie_repository.dart';
import 'data/xtream_config.dart';
import 'data/xtream_movie_repository.dart';
import 'screens/main_shell.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) => const AppBootstrap();
}

/// Decides what the app is, on launch:
///
///   * saved portal   -> Xtream catalogue
///   * nothing saved  -> the setup screen
///   * demo chosen    -> the bundled sample catalogue
///
/// The repository is created here and nowhere else, so there is exactly one
/// place that knows a backend exists.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final CredentialsStore _store = CredentialsStore();
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();

  bool _loading = true;
  XtreamConfig? _config;
  MovieRepository? _repository;
  bool _demo = false;

  /// How long a keystore read or write is given before the app gives up on it.
  ///
  /// `flutter_secure_storage` talks to the platform Keystore, and on a device
  /// where that is unhappy the call does not fail — it hangs. Without a
  /// deadline the launch spinner would never resolve, so every call here is
  /// bounded.
  static const Duration _storageTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    XtreamConfig? config;
    try {
      config = await _store.read().timeout(_storageTimeout);
    } catch (_) {
      // An unreadable or unresponsive keystore is treated as "nothing saved".
      // The user lands on sign-in, which is a recoverable place to be.
      config = null;
    }

    if (!mounted) return;
    setState(() {
      _config = config;
      _repository =
          config == null ? null : XtreamMovieRepository(config: config);
      _loading = false;
    });
  }

  /// Starts a session.
  ///
  /// [remember] is false when the user cleared "Save on this device". The
  /// session still starts — it just is not written to the keystore.
  Future<void> _configure(XtreamConfig config, bool remember) async {
    final previous = _repository;

    // The session is live in memory before any storage work happens, so a
    // keystore that refuses to persist cannot leave the sign-in button looking
    // dead. Being asked to sign in again next launch is a far better outcome.
    setState(() {
      _config = config;
      _demo = false;
      _repository = XtreamMovieRepository(config: config);
    });

    previous?.dispose();

    if (!remember) {
      // Also erase anything saved earlier, so unchecking the box on a
      // re-sign-in actually forgets the previous account rather than silently
      // leaving it on disk.
      unawaited(_forget());
      return;
    }

    try {
      await _store.write(config).timeout(_storageTimeout);
    } catch (_) {
      // Not fatal: the session works, it just will not survive a restart.
    }
  }

  void _useDemo() {
    final previous = _repository;
    setState(() {
      _demo = true;
      _repository = MockMovieRepository();
    });
    previous?.dispose();
  }

  /// Leaves the session.
  ///
  /// The order here is the whole point. The screen changes *first*; clearing
  /// the keystore happens afterwards, in the background, and cannot fail the
  /// sign-out. A user with no connection, or on a device whose Keystore is
  /// broken, still gets out — which is the only behaviour that matters for a
  /// control that exists to protect their account.
  Future<void> _signOut() async {
    final previous = _repository;

    if (mounted) {
      setState(() {
        _config = null;
        _repository = null;
        _demo = false;
      });
    }

    previous?.dispose();
    unawaited(_forget());
  }

  /// Back to setup, but keep whatever is saved.
  ///
  /// Used to leave demo mode: there is no account to erase, and the saved
  /// portal should still be offered on the sign-in screen.
  Future<void> _exitDemo() async {
    final previous = _repository;
    setState(() {
      _repository = null;
      _demo = false;
    });
    previous?.dispose();
  }

  /// Erases the saved account, and says so if it could not.
  ///
  /// One retry, because the first call after a screen transition occasionally
  /// loses a race with the platform channel. If both attempts fail the user is
  /// told plainly, rather than being left believing the credentials are gone.
  Future<void> _forget() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _store.clear().timeout(_storageTimeout);
        return;
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }

    _messenger.currentState?.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        duration: Duration(seconds: 8),
        content: Text(
          'Signed out, but this device refused to erase the saved account. '
          'Sign in again and sign out, or clear the app data in Settings.',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The messenger key is owned here rather than by the shell, because the one
    // message that has to reach the user — "the saved account could not be
    // erased" — is raised *after* the shell has been torn down.
    return MaterialApp(
      title: 'FunFlix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      scaffoldMessengerKey: _messenger,
      home: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    final repository = _repository;
    if (repository == null) {
      return SetupScreen(
        initial: _config,
        onConfigured: _configure,
        onUseDemo: _useDemo,
      );
    }

    return MainShell(
      repository: repository,
      demoMode: _demo,
      onSignOut: _demo ? _exitDemo : _signOut,
    );
  }
}
