import 'package:flutter/material.dart';
// Prefixed on purpose. The package re-exports an `Icon` model from its EPG
// library, which collides with Flutter's own `Icon` widget in this file.
import 'package:xtream_code_client/xtream_code_client.dart' as xtream;

import '../data/xtream_config.dart';
import '../theme/app_theme.dart';
import '../widgets/n_ui.dart';

/// The Netflix-style sign-in.
///
/// Three fields rather than two, because a portal needs a host as well as a
/// username and password — but the shape, spacing and hierarchy follow the
/// familiar sign-in: wordmark, heading, stacked fields, one red action.
///
/// Nothing is pre-filled and nothing is defaulted. The app has no idea what
/// service it is talking to until someone types one in here.
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

/// Netflix fills its fields with a flat #333 rather than a border.
const Color _fieldFill = Color(0xFF333333);

class _SetupScreenState extends State<SetupScreen> {
  final _portal = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _helpOpen = false;
  bool _remember = true;

  /// Errors only appear once the user has tried to continue, so the form does
  /// not open covered in red before anyone has typed anything.
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
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

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
      _portalError == null &&
      _usernameError == null &&
      _passwordError == null;

  XtreamConfig get _config => XtreamConfig(
        portalUrl: _portal.text,
        username: _username.text.trim(),
        password: _password.text,
      );

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _connect() {
    setState(() => _showErrors = true);
    if (!_isComplete) return;

    FocusScope.of(context).unfocus();
    widget.onConfigured(_config, _remember);
  }

  /// Makes one real call to confirm the line is live before the user commits.
  ///
  /// `user_info.auth` is true for a good login and false for a rejected one.
  /// Checking it here means a bad account fails immediately instead of
  /// surfacing as an empty catalogue twenty seconds later.
  Future<void> _runTest() async {
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
            ? 'Signed in as ${user.username ?? 'unknown'} · '
                '${user.maxConnections ?? '?'} connection(s) · '
                'expires ${_formatDate(user.expDate)}'
            : 'The panel refused these credentials. Check the username and '
                'password, then try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _test = _TestState.failed;
        _testDetail = _describe(error);
      });
    } finally {
      client.close();
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'unknown';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String _describe(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Could not reach that host. Check the address and the port.';
    }
    if (text.contains('TimeoutException')) {
      return 'The portal did not answer in time.';
    }
    if (text.contains('HandshakeException')) {
      return 'TLS handshake failed. Many panels are plain http:// on a '
          'non-standard port — try that.';
    }
    return text;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final busy = _test == _TestState.running;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x1AE50914), AppColors.background],
            stops: <double>[0, 0.45],
          ),
        ),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
            children: <Widget>[
              const Wordmark(size: 30),
              const SizedBox(height: 52),

              const Text('Sign In', style: AppTheme.display),
              const SizedBox(height: 24),

              _FloatField(
                controller: _portal,
                label: 'Portal address',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.url],
                errorText: _portalError,
                onSubmitted: (_) => _usernameFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _FloatField(
                controller: _username,
                label: 'Username',
                focusNode: _usernameFocus,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.username],
                errorText: _usernameError,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _FloatField(
                controller: _password,
                label: 'Password',
                focusNode: _passwordFocus,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                errorText: _passwordError,
                onSubmitted: (_) => _connect(),
                trailing: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              NPrimaryButton(
                label: 'Sign In',
                busy: busy,
                onTap: busy ? null : _connect,
              ),

              const SizedBox(height: 10),
              _TextAction(
                label: 'Test connection',
                busy: busy,
                onTap: busy ? null : _runTest,
              ),

              if (_test != _TestState.idle && _testDetail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                _TestResult(state: _test, detail: _testDetail),
              ],

              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  _Checkbox(
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
                    onTap: () => setState(() => _helpOpen = !_helpOpen),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
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

              if (_helpOpen) ...<Widget>[
                const SizedBox(height: 14),
                const _HelpBody(),
              ],

              const SizedBox(height: 34),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 22),

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
              const _Footnote(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

/// Netflix-style field: a flat dark box with the label floating up out of the
/// way once the field is focused or filled.
class _FloatField extends StatefulWidget {
  const _FloatField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_FloatField> createState() => _FloatFieldState();
}

class _FloatFieldState extends State<_FloatField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final bool _ownsFocus = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onChanged);
    widget.controller.removeListener(_onChanged);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.errorText != null;
    final floating = _focus.hasFocus || widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: invalid ? AppColors.accent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              // The label doubles as the placeholder. It shrinks and moves up
              // once there is content, which is what keeps a three-field form
              // from reading as a wall of boxes.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                left: 16,
                top: floating ? 7 : 19,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 140),
                  style: TextStyle(
                    fontSize: floating ? 11 : 16,
                    color: invalid ? AppColors.accent : AppColors.textSecondary,
                  ),
                  child: Text(widget.label),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: widget.trailing == null ? 16 : 46,
                  top: floating ? 20 : 0,
                ),
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
                  cursorColor: AppColors.accent,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.only(top: 18, bottom: 8),
                  ),
                ),
              ),
              if (widget.trailing != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: widget.trailing),
                ),
            ],
          ),
        ),
        if (invalid) ...<Widget>[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Flat text button. Used for the secondary actions so they do not compete
/// with the single red primary.
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: value ? AppColors.accent : AppColors.textMuted,
              width: 1.5,
            ),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result + help
// ---------------------------------------------------------------------------

class _TestResult extends StatelessWidget {
  const _TestResult({required this.state, required this.detail});

  final _TestState state;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final (Color colour, IconData icon, String title) = switch (state) {
      _TestState.ok => (
          AppColors.match,
          Icons.check_circle_outline_rounded,
          'Connection works'
        ),
      _TestState.rejected => (
          AppColors.accent,
          Icons.block_rounded,
          'Credentials refused'
        ),
      _TestState.failed => (
          const Color(0xFFEF9F27),
          Icons.warning_amber_rounded,
          'Could not connect'
        ),
      _ => (AppColors.textSecondary, Icons.info_outline_rounded, 'Status'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: colour, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
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

class _HelpBody extends StatelessWidget {
  const _HelpBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Your provider sends these when you subscribe — usually as a single '
        'link, or as a host, a username and a password.\n\n'
        'The address is the host and port, for example '
        'http://your-host:2095. Leave the http:// off if you are not sure; the '
        'app adds it. If the panel runs on a non-standard port, include it.\n\n'
        'Still stuck? Ask your provider for your "Xtream codes" or "M3U" '
        'details — those are exactly the three values above.',
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Your credentials are stored in this device\u2019s keystore, never on a '
      'server. Use an account you are authorised to use.',
      style: TextStyle(
        fontSize: 11.5,
        height: 1.6,
        color: AppColors.textMuted,
      ),
    );
  }
}
