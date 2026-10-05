import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Prefixed on purpose. The package re-exports an `Icon` model from its EPG
// library, which collides with Flutter's own `Icon` widget in this file.
import 'package:xtream_code_client/xtream_code_client.dart' as xtream;

import '../data/xtream_config.dart';
import '../theme/app_theme.dart';
import '../widgets/n_ui.dart';

/// The FunFlix high-fidelity sign-in screen.
///
/// Features modern glassmorphic surfaces, tactile micro-interactions,
/// smart URL/credential auto-fill, quick protocol/port chips, connection testing,
/// and instant access to the bundled sample catalogue.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.onConfigured,
    required this.onUseDemo,
    this.initial,
  });

  /// [remember] is false when the user clears "Save on this device" — the
  /// session still starts, it just is not written to the keystore.
  final void Function(XtreamConfig config, bool remember) onConfigured;

  final VoidCallback onUseDemo;
  final XtreamConfig? initial;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _TestState { idle, running, ok, rejected, failed }

class _SetupScreenState extends State<SetupScreen> {
  final _portal = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  final _portalFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _remember = true;
  bool _showErrors = false;

  _TestState _test = _TestState.idle;
  String _testDetail = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _portal.text = initial.portalUrl;
      _username.text = initial.username;
      _password.text = initial.password;
    }
  }

  @override
  void dispose() {
    _portal.dispose();
    _username.dispose();
    _password.dispose();
    _portalFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? get _portalError {
    if (!_showErrors) return null;
    final value = _portal.text.trim();
    if (value.isEmpty) return 'Enter the address of your portal.';
    if (value.contains(' ')) return 'Addresses cannot contain spaces.';
    if (value.length < 4) return 'That address looks too short.';
    return null;
  }

  String? get _usernameError {
    if (!_showErrors) return null;
    if (_username.text.trim().isEmpty) return 'Enter your username.';
    return null;
  }

  String? get _passwordError {
    if (!_showErrors) return null;
    if (_password.text.isEmpty) return 'Enter your password.';
    return null;
  }

  bool get _isComplete =>
      _portalError == null && _usernameError == null && _passwordError == null;

  XtreamConfig get _config => XtreamConfig(
        portalUrl: _portal.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
      );

  // ---------------------------------------------------------------------------
  // Smart Clipboard & URL Helper Chips
  // ---------------------------------------------------------------------------

  Future<void> _handleSmartPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final rawText = data?.text?.trim();
    if (rawText == null || rawText.isEmpty) {
      if (mounted) {
        _showToast('Clipboard is empty', icon: Icons.info_outline_rounded);
      }
      return;
    }

    _applySmartUrl(rawText);
  }

  void _applySmartUrl(String text) {
    final uri = Uri.tryParse(text);

    // 1. Check for query parameters (?username=...&password=...)
    if (uri != null && uri.hasQuery) {
      final query = uri.queryParameters;
      final user = query['username'] ?? query['user'];
      final pass = query['password'] ?? query['pass'];
      if (user != null && pass != null) {
        final host = uri.host;
        final portPart = uri.hasPort ? ':${uri.port}' : '';
        final scheme = uri.scheme.isNotEmpty ? '${uri.scheme}://' : 'http://';
        setState(() {
          _portal.text = '$scheme$host$portPart';
          _username.text = user;
          _password.text = pass;
          _showErrors = false;
        });
        _showToast(
          'Auto-filled portal, username, and password!',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.match,
        );
        return;
      }
    }

    // 2. Check for path-based playlist patterns: /live/user/pass/... or /movie/user/pass/...
    if (uri != null && uri.pathSegments.length >= 3) {
      final seg0 = uri.pathSegments[0].toLowerCase();
      if (seg0 == 'live' || seg0 == 'movie' || seg0 == 'series' || seg0 == 'get.php') {
        final user = uri.pathSegments[1];
        final pass = uri.pathSegments[2];
        final host = uri.host;
        final portPart = uri.hasPort ? ':${uri.port}' : '';
        final scheme = uri.scheme.isNotEmpty ? '${uri.scheme}://' : 'http://';
        setState(() {
          _portal.text = '$scheme$host$portPart';
          _username.text = user;
          _password.text = pass;
          _showErrors = false;
        });
        _showToast(
          'Auto-filled credentials from playlist URL!',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.match,
        );
        return;
      }
    }

    // 3. Fallback: plain URL
    setState(() {
      _portal.text = text;
      _showErrors = false;
    });
    _showToast('Portal URL pasted', icon: Icons.paste_rounded);
  }

  void _prependScheme(String scheme) {
    var text = _portal.text.trim();
    if (text.startsWith('http://')) {
      text = text.substring(7);
    } else if (text.startsWith('https://')) {
      text = text.substring(8);
    }
    setState(() {
      _portal.text = '$scheme$text';
    });
  }

  void _appendPort(String port) {
    var text = _portal.text.trim();
    // Remove existing port if present
    final colonIdx = text.lastIndexOf(':');
    final slashIdx = text.indexOf('://');
    if (colonIdx > (slashIdx == -1 ? -1 : slashIdx + 2)) {
      text = text.substring(0, colonIdx);
    }
    setState(() {
      _portal.text = '$text$port';
    });
  }

  void _showToast(String message, {IconData? icon, Color? color}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: color ?? const Color(0xFF22222A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _connect() {
    HapticFeedback.lightImpact();
    setState(() => _showErrors = true);
    if (!_isComplete) return;

    FocusScope.of(context).unfocus();
    widget.onConfigured(_config, _remember);
  }

  Future<void> _runTest() async {
    HapticFeedback.lightImpact();
    setState(() => _showErrors = true);
    if (!_isComplete) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _test = _TestState.running;
      _testDetail = '';
    });

    final client = xtream.XtreamClient(
      url: _config.normalisedPortalUrl,
      username: _config.username,
      password: _config.password,
    );

    try {
      final account = (await client.serverInformation()).data;
      final user = account.userInfo;
      final accepted = user.auth ?? false;
      if (!mounted) return;
      setState(() {
        _test = accepted ? _TestState.ok : _TestState.rejected;
        _testDetail = accepted
            ? 'Account verified: ${user.username ?? 'valid'} · '
                '${user.maxConnections ?? '?'} connection(s) · '
                'Expires ${_formatDate(user.expDate)}'
            : 'The server rejected these credentials. Double-check your username and password.';
      });
      HapticFeedback.mediumImpact();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _test = _TestState.failed;
        _testDetail = _describe(error);
      });
      HapticFeedback.mediumImpact();
    } finally {
      client.close();
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'unlimited';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String _describe(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Cannot reach portal server. Check host URL, port number, or try switching between Wi-Fi and mobile data.';
    }
    if (text.contains('TimeoutException')) {
      return 'The portal took too long to respond. The server might be down or blocked.';
    }
    if (text.contains('HandshakeException')) {
      return 'SSL/TLS certificate error. Try using http:// instead of https://, or verify your port.';
    }
    return text;
  }

  void _showHelpModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HelpBottomSheet(),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final busy = _test == _TestState.running;

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Stack(
        children: <Widget>[
          // Ambient Radial Red Glow at top
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 380,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: <Color>[
                      Color(0x3DE50914),
                      Color(0x0FE50914),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
                children: <Widget>[
                  // Top Wordmark
                  const Wordmark(size: 28, showBadge: true),
                  const SizedBox(height: 38),

                  // Heading & Subtitle
                  const Text('Sign In', style: AppTheme.display),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect your Xtream Codes or IPTV portal to begin streaming.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Portal address input
                  _ModernInputField(
                    controller: _portal,
                    focusNode: _portalFocus,
                    label: 'Portal address',
                    leadingIcon: Icons.dns_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.url],
                    errorText: _portalError,
                    onSubmitted: (_) => _usernameFocus.requestFocus(),
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                    trailing: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _portal,
                      builder: (context, val, _) {
                        if (val.text.isEmpty) {
                          return IconButton(
                            icon: const Icon(Icons.paste_rounded, size: 20),
                            color: AppColors.accent,
                            tooltip: 'Smart Paste',
                            onPressed: _handleSmartPaste,
                          );
                        }
                        return IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textMuted,
                          tooltip: 'Clear',
                          onPressed: () {
                            _portal.clear();
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),

                  // Quick Helper Chips for Portal URL
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: <Widget>[
                        _HelperChip(
                          label: 'http://',
                          onTap: () => _prependScheme('http://'),
                        ),
                        const SizedBox(width: 6),
                        _HelperChip(
                          label: 'https://',
                          onTap: () => _prependScheme('https://'),
                        ),
                        const SizedBox(width: 6),
                        _HelperChip(
                          label: ':8080',
                          onTap: () => _appendPort(':8080'),
                        ),
                        const SizedBox(width: 6),
                        _HelperChip(
                          label: ':2095',
                          onTap: () => _appendPort(':2095'),
                        ),
                        const SizedBox(width: 6),
                        _HelperChip(
                          label: ':25461',
                          onTap: () => _appendPort(':25461'),
                        ),
                        const SizedBox(width: 6),
                        _HelperChip(
                          label: 'Paste link',
                          icon: Icons.content_paste_rounded,
                          onTap: _handleSmartPaste,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Username input
                  _ModernInputField(
                    controller: _username,
                    focusNode: _usernameFocus,
                    label: 'Username',
                    leadingIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.username],
                    errorText: _usernameError,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                    trailing: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _username,
                      builder: (context, val, _) {
                        if (val.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textMuted,
                          tooltip: 'Clear',
                          onPressed: () {
                            _username.clear();
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password input
                  _ModernInputField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    leadingIcon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    errorText: _passwordError,
                    onSubmitted: (_) => _connect(),
                    onChanged: (_) {
                      if (_showErrors) setState(() {});
                    },
                    trailing: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: _obscure
                            ? AppColors.textSecondary
                            : AppColors.accent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Primary Sign In Button
                  NPrimaryButton(
                    label: 'Sign In',
                    busy: busy,
                    icon: Icons.login_rounded,
                    onTap: busy ? null : _connect,
                  ),
                  const SizedBox(height: 12),

                  // Test Connection Button
                  _TextAction(
                    label: 'Test connection',
                    busy: busy,
                    onTap: busy ? null : _runTest,
                  ),

                  // Connection Test Status Card
                  if (_test != _TestState.idle && _testDetail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _TestResultCard(state: _test, detail: _testDetail),
                  ],

                  const SizedBox(height: 14),

                  // Remember Me & Need Help Row (with Expanded to prevent any overflow)
                  Row(
                    children: <Widget>[
                      _CustomCheckbox(
                        value: _remember,
                        onChanged: (v) => setState(() => _remember = v),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Save on this device',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showHelpModal,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Text(
                            'Need help?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFF1E1E26), height: 1),
                  const SizedBox(height: 22),

                  // New Here Section with exact Browse the sample catalogue action
                  const Text(
                    'New here?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The app ships with a sample catalogue so you can look around '
                    'before connecting anything.',
                    style: AppTheme.body,
                  ),
                  const SizedBox(height: 12),
                  _TextAction(
                    label: 'Browse the sample catalogue',
                    onTap: widget.onUseDemo,
                  ),

                  const SizedBox(height: 30),

                  // Secure Hardware Keystore Footnote
                  const _SecurityFootnote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Modern Interactive Form Field
// -----------------------------------------------------------------------------

class _ModernInputField extends StatefulWidget {
  const _ModernInputField({
    required this.controller,
    required this.label,
    required this.leadingIcon,
    this.focusNode,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData leadingIcon;
  final FocusNode? focusNode;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<_ModernInputField> createState() => _ModernInputFieldState();
}

class _ModernInputFieldState extends State<_ModernInputField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final bool _ownsFocus = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.errorText != null;
    final isFocused = _focus.hasFocus;
    final hasContent = widget.controller.text.isNotEmpty;
    final isFloating = isFocused || hasContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 58,
          decoration: BoxDecoration(
            color: isFocused
                ? const Color(0xFF1B1B22)
                : const Color(0xFF15151B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: invalid
                  ? AppColors.accent
                  : (isFocused
                      ? AppColors.accent
                      : const Color(0xFF282832)),
              width: invalid || isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33E50914),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: <Widget>[
              // Leading Icon
              Positioned(
                left: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    widget.leadingIcon,
                    size: 20,
                    color: invalid
                        ? AppColors.accent
                        : (isFocused
                            ? AppColors.accent
                            : AppColors.textSecondary),
                  ),
                ),
              ),

              // Animated Floating Label
              AnimatedPositioned(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                left: 44,
                top: isFloating ? 7 : 18,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 140),
                  style: TextStyle(
                    fontSize: isFloating ? 11 : 15,
                    fontWeight:
                        isFloating ? FontWeight.w600 : FontWeight.w400,
                    color: invalid
                        ? AppColors.accent
                        : (isFocused
                            ? AppColors.accent
                            : AppColors.textSecondary),
                  ),
                  child: Text(widget.label),
                ),
              ),

              // Input Text Field
              Padding(
                padding: EdgeInsets.only(
                  left: 44,
                  right: widget.trailing == null ? 14 : 46,
                  top: isFloating ? 16 : 0,
                ),
                child: Center(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: widget.onSubmitted,
                    onChanged: widget.onChanged,
                    cursorColor: AppColors.accent,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              // Trailing action
              if (widget.trailing != null)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(child: widget.trailing),
                ),
            ],
          ),
        ),

        // Error message animated transition
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: invalid
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Quick Helper Chips
// -----------------------------------------------------------------------------

class _HelperChip extends StatelessWidget {
  const _HelperChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2C2C38), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Flat Text Button (Preserved for compatibility and secondary actions)
// -----------------------------------------------------------------------------

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF181820),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF282834), width: 0.8),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tactile Checkbox
// -----------------------------------------------------------------------------

class _CustomCheckbox extends StatelessWidget {
  const _CustomCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? AppColors.accent : const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? AppColors.accent : const Color(0xFF383846),
            width: 1.5,
          ),
          boxShadow: value
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x59E50914),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Test Result Card
// -----------------------------------------------------------------------------

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({required this.state, required this.detail});

  final _TestState state;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final (Color colour, Color bgColour, IconData icon, String title) =
        switch (state) {
      _TestState.ok => (
          AppColors.match,
          const Color(0x1446D369),
          Icons.check_circle_rounded,
          'Connection verified'
        ),
      _TestState.rejected => (
          AppColors.accent,
          const Color(0x14E50914),
          Icons.cancel_rounded,
          'Credentials refused'
        ),
      _TestState.failed => (
          const Color(0xFFFFA726),
          const Color(0x14FFA726),
          Icons.signal_wifi_connected_no_internet_4_rounded,
          'Could not reach server'
        ),
      _ => (
          AppColors.textSecondary,
          Colors.transparent,
          Icons.info_outline_rounded,
          'Status'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColour,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour.withAlpha(128), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFFD0D0D8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Interactive Help Modal Bottom Sheet
// -----------------------------------------------------------------------------

class _HelpBottomSheet extends StatelessWidget {
  const _HelpBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14141B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Grab handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A48),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: <Widget>[
              const Icon(Icons.help_center_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Xtream & IPTV Setup Help',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const _FaqItem(
            question: 'Where do I find my credentials?',
            answer:
                'Your IPTV or stream provider sends these via email or customer dashboard upon subscription. Look for "Xtream Codes API" or your M3U playlist link.',
          ),
          const SizedBox(height: 12),

          const _FaqItem(
            question: 'What is the Portal Address format?',
            answer:
                'It is the host and port of the server, e.g. "http://provider-domain.com:8080". If you were given a full playlist URL, use the "Smart Paste" button above to extract it automatically.',
          ),
          const SizedBox(height: 12),

          const _FaqItem(
            question: 'Common Connection Issues',
            answer:
                '• Ensure you specified the correct port (e.g. :8080 or :2095)\n'
                '• Many panels are plain http://, not https://\n'
                '• Verify your ISP does not block IPTV streams (try a VPN if needed)',
          ),
          const SizedBox(height: 20),

          NPrimaryButton(
            label: 'Got It',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Security Footnote
// -----------------------------------------------------------------------------

class _SecurityFootnote extends StatelessWidget {
  const _SecurityFootnote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.shield_outlined,
          size: 15,
          color: AppColors.textMuted,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your credentials are stored securely in this device\u2019s hardware Keystore, '
            'never uploaded to third-party servers. Only use an account you are authorised to access.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
