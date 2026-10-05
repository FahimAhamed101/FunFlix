import 'package:flutter/material.dart';

import '../data/movie_repository.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import '../widgets/n_ui.dart';
import 'home_screen.dart' show ProfileAvatar;

/// The account tab.
///
/// Two jobs: show what the portal says about the subscription, and get the
/// user out. The second one is why the sign-out control sits outside every
/// loading and error branch — signing out must work when the network does not.
class MyNetflixScreen extends StatefulWidget {
  const MyNetflixScreen({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.demoMode = false,
  });

  final MovieRepository repository;

  /// Returns to the sign-in screen. Owned by the app shell, which flips the
  /// visible screen *before* touching any storage.
  final Future<void> Function() onSignOut;

  final bool demoMode;

  @override
  State<MyNetflixScreen> createState() => _MyNetflixScreenState();
}

class _MyNetflixScreenState extends State<MyNetflixScreen> {
  AccountSnapshot? _account;
  bool _loading = true;
  Object? _error;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await widget.repository.fetchAccount();
      if (!mounted) return;
      setState(() {
        _account = account;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    // No try/catch here on purpose: the shell is responsible for making this
    // call succeed even when the keystore or the network fails, and swallowing
    // an error here would only hide it.
    await widget.onSignOut();
    if (!mounted) return;
    setState(() => _signingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: <Widget>[
            const Text('My Netflix', style: AppTheme.display),
            const SizedBox(height: 20),

            _ProfileCard(
              username: _account?.username,
              demoMode: widget.demoMode,
            ),
            const SizedBox(height: 22),

            if (widget.demoMode)
              const _Notice(
                icon: Icons.science_outlined,
                text:
                    'You are browsing the built-in sample catalogue. Nothing '
                    'here is coming from a portal, and nothing is being sent '
                    'anywhere.',
              ),

            if (widget.demoMode) const SizedBox(height: 22),

            const _SectionTitle('Subscription'),
            const SizedBox(height: 10),

            if (_loading)
              const _AccountSkeleton()
            else if (_error != null)
              _AccountError(error: _error!, onRetry: _load)
            else if (_account != null)
              _AccountDetails(account: _account!)
            else
              const Text(
                'This source does not report account information.',
                style: AppTheme.body,
              ),

            const SizedBox(height: 26),
            const _SectionTitle('Session'),
            const SizedBox(height: 10),

            NSecondaryButton(
              label: widget.demoMode ? 'Connect a portal' : 'Switch account',
              icon: Icons.swap_horiz_rounded,
              onTap: _signingOut ? () {} : _signOut,
            ),
            const SizedBox(height: 10),

            _PressableOutline(
              label: 'Sign out',
              busy: _signingOut,
              onTap: _signingOut ? null : _signOut,
            ),

            const SizedBox(height: 16),
            const Text(
              'Signing out clears the portal address and the account details '
              'from this device. It works with no connection — the app returns '
              'to the sign-in screen immediately.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.username, required this.demoMode});

  final String? username;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final name = (username == null || username!.trim().isEmpty)
        ? (demoMode ? 'Sample catalogue' : 'Signed in')
        : username!.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          const ProfileAvatar(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  demoMode ? 'Offline sample data' : 'Portal account',
                  style: AppTheme.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.account});

  final AccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: <Widget>[
          _Row(
            label: 'Status',
            value: account.planLabel,
            highlight: account.isActive,
          ),
          _Row(label: 'Expires', value: account.expiryLabel),
          _Row(label: 'Member since', value: account.memberSinceLabel),
          _Row(label: 'Connections', value: account.connectionsLabel),
          if (account.serverVersion != null)
            _Row(label: 'Server build', value: account.serverVersion!),
          if (account.serverTimezone != null)
            _Row(label: 'Server timezone', value: account.serverTimezone!),
          if (account.allowedFormats.isNotEmpty)
            _Row(
              label: 'Formats',
              value: account.allowedFormats.join(', '),
              last: true,
            )
          else
            const _Row(label: 'Formats', value: 'Not reported', last: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.match : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTheme.sectionTitle);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An outlined destructive action.
///
/// Outlined rather than filled red: "Sign out" sits directly under "Switch
/// account", and two red buttons in a column read as one control.
class _PressableOutline extends StatelessWidget {
  const _PressableOutline({required this.label, required this.onTap, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled
                ? const Color(0x59FFFFFF)
                : const Color(0x26FFFFFF),
            width: 1,
          ),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}

class _AccountSkeleton extends StatelessWidget {
  const _AccountSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Could not read the account details',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _short(error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          NSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            expand: false,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }

  static String _short(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'Could not reach the portal. Check your connection.';
    }
    if (text.contains('TimeoutException')) {
      return 'The portal did not answer in time.';
    }
    return text.length > 140 ? '${text.substring(0, 140)}...' : text;
  }
}
