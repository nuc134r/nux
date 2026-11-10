import 'dart:convert';

/// A saved terminal command, run from a terminal tab's menu.
class Snippet {
  const Snippet(this.name, this.command);

  final String name;

  /// What is typed; several lines run one after the other.
  final String command;

  Map<String, String> toJson() => {'name': name, 'command': command};

  static Snippet? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'], command = json['command'];
    if (name is! String || command is! String || command.trim().isEmpty) return null;
    return Snippet(name, command);
  }

  @override
  bool operator ==(Object other) => other is Snippet && other.name == name && other.command == command;

  @override
  int get hashCode => Object.hash(name, command);
}

/// The presets: (id, command); the id names its localized title (see snippetPresetName).
const snippetPresets = [
  ('disk', 'df -h'),
  ('dirs', 'du -xh --max-depth=1 . 2>/dev/null | sort -rh | head -20'),
  ('files', r'find . -xdev -type f -size +50M -exec ls -lh {} + 2>/dev/null | sort -k5 -rh | head -20'),
  ('mem', 'ps aux --sort=-%mem | head -15'),
  ('cpu', 'ps aux --sort=-%cpu | head -15'),
  ('free', 'free -h'),
  ('uptime', 'uptime'),
  ('ports', 'ss -tulpn'),
  ('log', 'journalctl -n 100 --no-pager'),
  ('failed', 'systemctl --failed'),
  ('docker', r"docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"),
  ('ip', 'ip -br addr'),
];

String encodeSnippets(List<Snippet> snippets) => jsonEncode([for (final s in snippets) s.toJson()]);

/// The saved list; null when there is none (or it cannot be read): the presets apply.
List<Snippet>? decodeSnippets(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final list = jsonDecode(json);
    if (list is! List) return null;
    return [for (final item in list) ?Snippet.fromJson(item)];
  } on FormatException {
    return null;
  }
}
