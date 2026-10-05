import 'package:flutter/foundation.dart';

/// What the portal says about the signed-in account.
///
/// Read-only, and deliberately narrow: the profile screen needs to answer
/// "who am I signed in as, and until when" without the UI ever touching a
/// `UserInfo` payload. Nothing here is a credential.
@immutable
class AccountSnapshot {
  const AccountSnapshot({
    required this.username,
    required this.status,
    required this.isTrial,
    required this.expiresAt,
    required this.createdAt,
    required this.maxConnections,
    required this.activeConnections,
    this.serverVersion,
    this.serverTimezone,
    this.allowedFormats = const <String>[],
  });

  /// What the portal calls the account. Not the password — never the password.
  final String username;

  /// "Active", "Expired", "Disabled", or whatever the panel chose to say.
  final String status;

  final bool isTrial;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final int? maxConnections;
  final int? activeConnections;

  /// Panel build string, e.g. "1.5.12".
  final String? serverVersion;

  final String? serverTimezone;

  /// Containers the account is allowed to request, e.g. `["m3u8", "ts"]`.
  final List<String> allowedFormats;

  bool get isActive => status.trim().toLowerCase() == 'active';

  /// "Active" / "Trial · Active" / "Expired".
  String get planLabel {
    final base = status.trim().isEmpty ? 'Unknown' : status.trim();
    return isTrial ? 'Trial · $base' : base;
  }

  String get expiryLabel => expiresAt == null ? 'No expiry given' : _date(expiresAt!);

  String get memberSinceLabel =>
      createdAt == null ? 'Unknown' : _date(createdAt!);

  /// "1 of 2 in use" — the number that explains a stream that will not open.
  String get connectionsLabel {
    if (maxConnections == null) return 'Unknown';
    final active = activeConnections ?? 0;
    return '$active of $maxConnections in use';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = (local.month >= 1 && local.month <= 12)
        ? months[local.month - 1]
        : '${local.month}';
    return '${local.day} $month ${local.year}';
  }
}
