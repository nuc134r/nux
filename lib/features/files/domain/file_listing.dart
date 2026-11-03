import 'package:nux_backend/nux_backend.dart';

enum FileSort { name, size, modified }

/// Directories first, then by [sort]; names compare case-insensitively with numbers in order
/// (`file2` before `file10`).
List<FileEntry> sortEntries(Iterable<FileEntry> entries, {FileSort sort = FileSort.name, bool descending = false, bool showHidden = false}) {
  // Keys are made once per entry: a natural comparison per pair (regex, lower-casing, number parsing)
  // made large folders slow to show.
  final keyed = [
    for (final e in entries)
      if (showHidden || !e.isHidden) (e, NaturalKey(e.name)),
  ];
  keyed.sort((x, y) {
    final a = x.$1, b = y.$1;
    if (a.isBrowsable != b.isBrowsable) return a.isBrowsable ? -1 : 1;
    final c = switch (sort) {
      FileSort.name => x.$2.compareTo(y.$2),
      FileSort.size => a.size.compareTo(b.size),
      FileSort.modified => (a.modified ?? DateTime(0)).compareTo(b.modified ?? DateTime(0)),
    };
    final r = c == 0 ? x.$2.compareTo(y.$2) : c;
    return descending ? -r : r; // folders stay first either way
  });
  return [for (final k in keyed) k.$1];
}

/// Case-insensitive comparison where digit runs compare as numbers.
int compareNatural(String a, String b) => NaturalKey(a).compareTo(NaturalKey(b));

/// A name split once into text and number runs, for [compareNatural].
class NaturalKey implements Comparable<NaturalKey> {
  NaturalKey(this.name) : _parts = _split(name.toLowerCase());

  final String name;
  final List<Object> _parts; // String or BigInt

  static final _runs = RegExp(r'(\d+)|(\D+)');

  static List<Object> _split(String s) => [
        for (final m in _runs.allMatches(s)) m.group(1) != null ? BigInt.parse(m.group(1)!) : m.group(0)!,
      ];

  @override
  int compareTo(NaturalKey other) {
    final pa = _parts, pb = other._parts;
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final x = pa[i], y = pb[i];
      final c = x is BigInt && y is BigInt ? x.compareTo(y) : x.toString().compareTo(y.toString());
      if (c != 0) return c;
    }
    final c = pa.length.compareTo(pb.length);
    return c != 0 ? c : name.compareTo(other.name);
  }
}

/// `rwxr-xr-x` for the lower 9 bits of [mode].
String permissionString(int mode) {
  const chars = 'rwx';
  return [for (var bit = 8; bit >= 0; bit--) (mode >> bit) & 1 == 1 ? chars[(8 - bit) % 3] : '-'].join();
}

/// `755` → 0x1ed; null when not 1–4 octal digits.
int? parseOctalMode(String text) {
  final t = text.trim();
  if (!RegExp(r'^[0-7]{1,4}$').hasMatch(t)) return null;
  return int.parse(t, radix: 8) & 0xfff;
}

/// `1.4 MB` style sizes (1024-based, as file managers show them).
String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v >= 100 ? v.round() : v.toStringAsFixed(1)} ${units[u]}';
}

/// How a file is opened.
enum FileKind { text, image, markdown, archive, binary }

const _imageExt = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico'};
const _archiveExt = {'zip', 'gz', 'tgz', 'xz', 'bz2', 'zst', '7z', 'rar', 'tar', 'jar', 'apk', 'deb', 'rpm'};
const _binaryExt = {'so', 'o', 'a', 'class', 'exe', 'dll', 'bin', 'pdf', 'mp3', 'mp4', 'mkv', 'wav', 'ogg', 'ttf', 'otf', 'woff', 'woff2', 'sqlite', 'db'};

FileKind fileKindByName(String name) {
  final ext = posix.extension(name).toLowerCase().replaceFirst('.', '');
  if (_imageExt.contains(ext)) return FileKind.image;
  if (ext == 'md' || ext == 'markdown') return FileKind.markdown;
  if (_archiveExt.contains(ext)) return FileKind.archive;
  if (_binaryExt.contains(ext)) return FileKind.binary;
  return FileKind.text;
}

/// Text unless the first bytes contain NUL or are mostly not printable.
bool looksBinary(List<int> head) {
  final sample = head.length > 8192 ? head.sublist(0, 8192) : head;
  if (sample.isEmpty) return false;
  var odd = 0;
  for (final b in sample) {
    if (b == 0) return true;
    if (b < 7 || (b > 13 && b < 32 && b != 27)) odd++;
  }
  return odd / sample.length > .1;
}

/// How long ago something changed, coarse enough for a list ("5 min ago", "yesterday", or a date).
enum AgeUnit { justNow, minutes, hours, yesterday, days, sameYear, olderYear }

/// [time] relative to [now]: a unit and a count (minutes, hours or days; 0 otherwise). Future times
/// (clock skew) show as dates.
(AgeUnit, int) ageOf(DateTime time, DateTime now) {
  final d = now.difference(time);
  if (d.isNegative && d.inMinutes.abs() > 1) {
    return (time.year == now.year ? AgeUnit.sameYear : AgeUnit.olderYear, 0);
  }
  if (d.inMinutes < 1) return (AgeUnit.justNow, 0);
  if (d.inMinutes < 60) return (AgeUnit.minutes, d.inMinutes);
  if (d.inHours < 24 && time.day == now.day) return (AgeUnit.hours, d.inHours);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;
  if (days <= 1) return (AgeUnit.yesterday, 1);
  if (days < 7) return (AgeUnit.days, days);
  return (time.year == now.year ? AgeUnit.sameYear : AgeUnit.olderYear, 0);
}
