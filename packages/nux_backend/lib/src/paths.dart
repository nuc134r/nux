import 'package:path/path.dart' as p;

/// POSIX path helpers for remote paths (SSH/Termux are always POSIX).
final posix = p.Context(style: p.Style.posix);

/// `/a/b/c` → [`/`, `/a`, `/a/b`, `/a/b/c`] for breadcrumbs.
List<String> pathAncestors(String path) {
  final normalized = posix.normalize(path);
  final parts = posix.split(normalized);
  return [for (var i = 1; i <= parts.length; i++) posix.joinAll(parts.take(i))];
}

/// A name for a copy that does not collide with [taken]: `a.txt` → `a (2).txt`.
String uniqueName(String name, Set<String> taken) {
  if (!taken.contains(name)) return name;
  final ext = posix.extension(name);
  final base = ext.isEmpty || ext == name ? name : name.substring(0, name.length - ext.length);
  for (var i = 2;; i++) {
    final candidate = '$base ($i)$ext';
    if (!taken.contains(candidate)) return candidate;
  }
}
