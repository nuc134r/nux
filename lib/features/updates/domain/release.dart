/// A published GitHub release of the app.
class Release {
  const Release({
    required this.version,
    required this.pageUrl,
    required this.apks,
    this.notes = '',
    this.prerelease = false,
  });

  /// "1.3.0" (the tag without its leading "v").
  final String version;
  final String pageUrl;
  final String notes;
  final bool prerelease;

  /// APK assets by file name → download URL.
  final Map<String, String> apks;

  /// The APK for [abi] ("arm64-v8a", …) if published, else the universal one.
  String? apkFor(String? abi) {
    if (abi != null) {
      for (final e in apks.entries) {
        if (e.key.endsWith('-$abi.apk')) return e.value;
      }
    }
    const abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    for (final e in apks.entries) {
      if (!abis.any((a) => e.key.endsWith('-$a.apk'))) return e.value;
    }
    return apks.values.firstOrNull;
  }

  /// Parses one release of the GitHub API; null for drafts, releases without APKs and
  /// (unless [allowPrerelease]) pre-releases.
  static Release? fromGitHub(Map<String, dynamic> json, {bool allowPrerelease = false}) {
    final prerelease = json['prerelease'] == true;
    if (json['draft'] == true || (prerelease && !allowPrerelease)) return null;
    final tag = json['tag_name'] as String?;
    if (tag == null) return null;
    final apks = <String, String>{
      for (final a in (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>())
        if ((a['name'] as String? ?? '').endsWith('.apk')) a['name'] as String: a['browser_download_url'] as String,
    };
    if (apks.isEmpty) return null;
    return Release(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      pageUrl: json['html_url'] as String? ?? '',
      notes: json['body'] as String? ?? '',
      apks: apks,
      prerelease: prerelease,
    );
  }

  /// The newest usable release in a GitHub `releases` list (which is sorted by date, not version).
  static Release? newest(List<dynamic> json, {bool allowPrerelease = false}) {
    Release? best;
    for (final item in json.cast<Map<String, dynamic>>()) {
      final r = fromGitHub(item, allowPrerelease: allowPrerelease);
      if (r != null && (best == null || compareVersions(r.version, best.version) > 0)) best = r;
    }
    return best;
  }
}

/// Compares "1.2.10" with "1.3" numerically; build metadata (+N) is ignored, a pre-release
/// ("1.3.0-beta.1") sorts before its release and a CI build after a tag ("1.3.0-5-g1a2b3c4",
/// see tool/version.sh) sorts after it, by commit count. Pre-releases compare by their numbers
/// ("beta.2" < "beta.10").
int compareVersions(String a, String b) {
  final afterTag = RegExp(r'^(.*)-(\d+)-g[0-9a-f]+$');
  // (numbers, rank, pre-release numbers): pre-release -1, release 0, N commits after the tag N.
  (List<int>, int, List<int>) parse(String v) {
    var core = v.split('+').first;
    var rank = 0;
    var pre = const <int>[];
    final m = afterTag.firstMatch(core);
    if (m != null) {
      core = m.group(1)!;
      rank = int.parse(m.group(2)!);
    }
    final dash = core.indexOf('-');
    if (dash >= 0) {
      if (m == null) rank = -1;
      pre = RegExp(r'\d+').allMatches(core.substring(dash)).map((x) => int.parse(x[0]!)).toList();
      core = core.substring(0, dash);
    }
    return (core.split('.').map((p) => int.tryParse(p) ?? 0).toList(), rank, pre);
  }

  int compareLists(List<int> x, List<int> y) {
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p.compareTo(q);
    }
    return 0;
  }

  final (na, rankA, preA) = parse(a);
  final (nb, rankB, preB) = parse(b);
  final byNumbers = compareLists(na, nb);
  if (byNumbers != 0) return byNumbers;
  if (rankA != rankB) return rankA.compareTo(rankB);
  return compareLists(preA, preB);
}
