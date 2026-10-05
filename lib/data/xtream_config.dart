/// Where the app points, and who it authenticates as.
///
/// Deliberately a plain value object with no defaults baked in. Nothing in this
/// codebase hard-codes a portal, which is what keeps the app a player rather
/// than a clone of any one service — the operator supplies these at setup.
class XtreamConfig {
  const XtreamConfig({
    required this.portalUrl,
    required this.username,
    required this.password,
  });

  /// Host and port of the portal, e.g. `http://example.invalid:2095`.
  /// Scheme is optional; [normalisedPortalUrl] fills it in.
  final String portalUrl;

  final String username;
  final String password;

  /// The portal as the client needs it: always has a scheme, never a trailing
  /// slash. Panels are inconsistent about both, and the client builds URLs by
  /// concatenation.
  String get normalisedPortalUrl {
    var url = portalUrl.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Never log this. Kept here so the redaction rule lives next to the data.
  String get redacted =>
      'XtreamConfig($normalisedPortalUrl, user=${username.isEmpty ? '<empty>' : '<set>'}, '
      'pass=${password.isEmpty ? '<empty>' : '<set>'})';
}
