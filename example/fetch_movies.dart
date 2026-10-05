// Minimal, runnable example: pull the movie (VOD) catalogue from an
// Xtream-compatible portal and print it.
//
//   dart run example/fetch_movies.dart <portal-url> <username> <password>
//
// or, so the credentials stay out of your shell history:
//
//   XTREAM_URL=... XTREAM_USER=... XTREAM_PASS=... dart run example/fetch_movies.dart
//
// Point it at a portal you are entitled to use. The client is only as
// authorised as the account you give it.

import 'dart:io';

import 'package:xtream_code_client/xtream_code_client.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final portal = args.isNotEmpty ? args[0] : env['XTREAM_URL'] ?? '';
  final username = args.length > 1 ? args[1] : env['XTREAM_USER'] ?? '';
  final password = args.length > 2 ? args[2] : env['XTREAM_PASS'] ?? '';

  if (portal.isEmpty || username.isEmpty || password.isEmpty) {
    stderr.writeln(
      'usage: dart run example/fetch_movies.dart <portal-url> <username> <password>\n'
      '   or: set XTREAM_URL / XTREAM_USER / XTREAM_PASS',
    );
    exitCode = 64;
    return;
  }

  final client = XtreamClient(
    url: portal,
    username: username,
    password: password,
  );

  try {
    // 1. Confirm the line is actually valid before asking for anything else.
    //    `auth` is true for a good login and false for a rejected one.
    final account = (await client.serverInformation()).data;
    final user = account.userInfo;
    stdout.writeln('Account');
    stdout.writeln('  status          : ${user.status ?? '-'}');
    stdout.writeln('  auth            : ${user.auth ?? false}');
    stdout.writeln('  max connections : ${user.maxConnections ?? '-'}');
    stdout.writeln('  expires         : ${_date(user.expDate)}');
    stdout.writeln(
      '  server          : ${account.serverInfo.url ?? '-'}:'
      '${account.serverInfo.port ?? '-'}',
    );
    stdout.writeln('  timezone        : ${account.serverInfo.timezone ?? '-'}');

    if (user.auth != true) {
      stderr.writeln('\nLine was rejected — stopping before the catalogue calls.');
      exitCode = 1;
      return;
    }

    // 2. Categories give you the shelf names, keyed by id.
    final categories = (await client.vodCategories()).data;
    final namesById = <int, String>{};
    for (final category in categories) {
      final id = category.categoryId;
      final name = category.categoryName;
      if (id != null && name != null) namesById[id] = name;
    }
    stdout.writeln('\nVOD categories: ${categories.length}');
    for (final category in categories.take(5)) {
      stdout.writeln('  ${category.categoryId}  ${category.categoryName ?? '-'}');
    }

    // 3. The item list is what a grid renders from. It carries title, artwork,
    //    rating and container — but not the synopsis.
    final items = (await client.vodItems()).data;
    stdout.writeln('\nVOD items: ${items.length}');

    for (final item in items.take(5)) {
      final id = item.streamId;
      stdout.writeln('\n  ${item.name ?? item.title ?? 'Untitled'}');
      stdout.writeln('    stream id : ${id ?? '-'}');
      stdout.writeln('    category  : ${namesById[item.categoryId] ?? '-'}');
      stdout.writeln('    rating    : ${item.rating ?? '-'}');
      stdout.writeln('    container : ${item.containerExtension ?? '-'}');
      stdout.writeln('    artwork   : ${item.streamIcon ?? '-'}');

      if (id == null) {
        stdout.writeln('    play      : (no stream id, cannot build a URL)');
        continue;
      }

      // 4. Per-title detail is a separate call. It is where plot, cast,
      //    genre and duration live — which is why you do not fetch it for the
      //    whole catalogue up front.
      final detail = (await client.vodInfo(item)).data;
      stdout.writeln('    plot      : ${_clip(detail.info.plot)}');
      stdout.writeln('    genre     : ${detail.info.genre ?? '-'}');
      stdout.writeln('    cast      : ${_clip(detail.info.cast)}');
      stdout.writeln('    duration  : ${detail.info.duration ?? '-'}');
      stdout.writeln('    released  : ${_date(detail.info.releaseDate)}');

      // 5. This is the string you hand to a player widget.
      final url = client.movieUrl(id, item.containerExtension ?? 'mp4');
      stdout.writeln('    play      : $url');
    }

    if (items.length > 5) {
      stdout.writeln('\n...and ${items.length - 5} more.');
    }
  } finally {
    client.close();
  }
}

String _date(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String _clip(String? value, {int max = 90}) {
  if (value == null || value.trim().isEmpty) return '-';
  final flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= max ? flat : '${flat.substring(0, max)}...';
}
