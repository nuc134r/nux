import 'dart:convert';

import 'package:nux_backend/nux_backend.dart';

/// Files the viewer cannot draw itself but the server can describe: it lists archives, queries SQLite
/// databases and reports on media, PDFs, pictures and programs with its own tools (tar, unzip, sqlite3,
/// ffprobe, pdfinfo, exiftool, readelf...). Each script tries the tools in turn and says which one answered,
/// so one round trip is enough; the parsers here turn their output into data.
enum InspectType { archive, database, media, pdf, image, executable }

/// How an archive is read and unpacked.
enum ArchiveFormat { tar, zip, sevenZip, deb, single }

const _tarExt = {'tar', 'tgz', 'tbz', 'tbz2', 'txz', 'tzst', 'tlz'};
const _zipExt = {'zip', 'jar', 'apk', 'aar', 'war', 'ear', 'whl', 'xpi', 'epub', 'ipa', 'nupkg', 'vsix'};
const _compressedExt = {'gz', 'xz', 'bz2', 'zst', 'lz4', 'lzma', 'z'};
const _databaseExt = {'db', 'sqlite', 'sqlite3', 'db3', 's3db'};
const _mediaExt = {
  'mp3', 'mp4', 'm4a', 'm4v', 'mkv', 'webm', 'mov', 'avi', 'wav', 'flac', 'ogg', 'oga', 'ogv', 'opus', 'aac', //
  'wma', 'wmv', 'flv', 'mpg', 'mpeg', 'ts', '3gp', 'amr', 'mid', 'midi',
};
const _imageExt = {
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico', 'heic', 'heif', 'avif', 'tif', 'tiff', 'raw', 'cr2', 'cr3', //
  'nef', 'arw', 'dng', 'orf', 'rw2', 'psd',
};
const _executableExt = {'so', 'o', 'ko', 'a', 'out', 'bin', 'elf', 'exe', 'dll', 'dylib', 'class', 'wasm', 'pyc'};

String _ext(String name) => posix.extension(name).toLowerCase().replaceFirst('.', '');

/// Picture formats Flutter draws itself (the rest only get details).
const drawableImageExt = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico'};

ArchiveFormat? archiveFormatFor(String name) {
  final lower = name.toLowerCase();
  final ext = _ext(lower);
  if (_tarExt.contains(ext) || posix.extension(posix.basenameWithoutExtension(lower)) == '.tar') {
    return ArchiveFormat.tar;
  }
  if (_zipExt.contains(ext)) return ArchiveFormat.zip;
  if (const {'7z', 'rar', 'cab', 'iso', 'rpm'}.contains(ext)) return ArchiveFormat.sevenZip;
  if (ext == 'deb') return ArchiveFormat.deb;
  if (_compressedExt.contains(ext)) return ArchiveFormat.single;
  return null;
}

/// What the server can tell about [name]; null for files the viewer shows itself (text, Markdown...).
InspectType? inspectTypeFor(String name) {
  final ext = _ext(name);
  if (archiveFormatFor(name) != null) return InspectType.archive;
  if (_databaseExt.contains(ext)) return InspectType.database;
  if (_mediaExt.contains(ext)) return InspectType.media;
  if (ext == 'pdf') return InspectType.pdf;
  if (_imageExt.contains(ext)) return InspectType.image;
  if (_executableExt.contains(ext)) return InspectType.executable;
  return null;
}

/// The server has none of the tools a preview needs.
class MissingToolException implements Exception {
  const MissingToolException(this.tools);

  /// The tools that would do, any one of them.
  final List<String> tools;

  @override
  String toString() => 'Needs ${tools.join(', ')}';
}

/// A tool ran and failed.
class InspectException implements Exception {
  const InspectException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------------------------------------
// Archives

/// One file or folder in an archive.
class ArchiveEntry {
  const ArchiveEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.size,
    this.modified,
    this.link,
  });

  /// As the archive stores it (`./usr/bin/x`): what extraction asks for.
  final String name;

  /// Without a leading `./` or trailing `/`.
  final String path;
  final bool isDir;
  final int? size;
  final String? modified;

  /// Where a link points.
  final String? link;
}

/// A file or folder directly inside a folder of the archive.
class ArchiveNode {
  const ArchiveNode({required this.name, required this.path, required this.isDir, this.entry, this.size});

  final String name;
  final String path;
  final bool isDir;

  /// Null for a folder that only shows up in the paths of its files.
  final ArchiveEntry? entry;

  /// A file's size, or the sum of a folder's files.
  final int? size;
}

class ArchiveListing {
  ArchiveListing(this.tool, this.entries);

  /// What listed it (and unpacks it the same way): tar, bsdtar, unzip, pyzip, 7z, dpkg or single.
  final String tool;
  final List<ArchiveEntry> entries;

  int get fileCount => entries.where((e) => !e.isDir).length;

  /// What [dir] ('' for the top) holds: folders first, then files, by name.
  List<ArchiveNode> children(String dir) {
    final prefix = dir.isEmpty ? '' : '$dir/';
    final folders = <String, int>{};
    final explicit = <String, ArchiveEntry>{};
    final files = <ArchiveNode>[];
    for (final e in entries) {
      if (!e.path.startsWith(prefix) || e.path == dir) continue;
      final rest = e.path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash >= 0) {
        final name = rest.substring(0, slash);
        folders[name] = (folders[name] ?? 0) + (e.isDir ? 0 : e.size ?? 0);
      } else if (e.isDir) {
        folders.putIfAbsent(rest, () => 0);
        explicit[rest] = e;
      } else {
        files.add(ArchiveNode(name: rest, path: e.path, isDir: false, entry: e, size: e.size));
      }
    }
    final dirs = [
      for (final MapEntry(key: name, value: size) in folders.entries)
        ArchiveNode(name: name, path: '$prefix$name', isDir: true, entry: explicit[name], size: size),
    ];
    int byName(ArchiveNode a, ArchiveNode b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return [...dirs..sort(byName), ...files..sort(byName)];
  }

  /// The archive's entries under [path] (itself included), as extraction names them.
  List<String> namesUnder(String path) => [
    for (final e in entries)
      if (e.path == path || e.path.startsWith('$path/')) e.name,
  ];
}

/// `report.tar.gz` → `report`; `data.json.gz` → `data.json`.
String archiveStem(String name) {
  var stem = posix.basename(name);
  final lower = stem.toLowerCase();
  for (final suffix in ['.tar.gz', '.tar.xz', '.tar.bz2', '.tar.zst', '.tar.lz4', '.tar.lzma']) {
    if (lower.endsWith(suffix)) return stem.substring(0, stem.length - suffix.length);
  }
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  return stem;
}

const _sevenZip = r'Z=$(command -v 7z || command -v 7zz || command -v 7za)';

/// Lists the archive at [path]; the first output line names the tool (`@tar`...).
String archiveListScript(String path) {
  final f = shellQuote(path);
  final format = archiveFormatFor(path) ?? ArchiveFormat.tar;
  String has(String tool) => 'command -v $tool >/dev/null 2>&1';
  const pyzip =
      'import zipfile,sys\n'
      'for i in zipfile.ZipFile(sys.argv[1]).infolist(): print(i.file_size, i.filename)';
  final bsdtar = '; elif ${has('bsdtar')}; then echo @bsdtar; bsdtar -tvf $f';
  final sevenZip = '; elif $_sevenZip; then echo @7z; "\$Z" l -slt $f';
  return switch (format) {
    ArchiveFormat.tar => 'if ${has('tar')}; then echo @tar; tar -tvf $f$bsdtar; else echo @none; fi',
    ArchiveFormat.zip =>
      'if ${has('unzip')}; then echo @unzip; unzip -l $f$bsdtar$sevenZip; '
          'elif ${has('python3')}; then echo @pyzip; python3 -c ${shellQuote(pyzip)} $f; else echo @none; fi',
    ArchiveFormat.sevenZip => 'if $_sevenZip; then echo @7z; "\$Z" l -slt $f$bsdtar; else echo @none; fi',
    ArchiveFormat.deb => 'if ${has('dpkg-deb')}; then echo @dpkg; dpkg-deb -c $f$bsdtar; else echo @none; fi',
    ArchiveFormat.single => 'echo @single',
  };
}

/// The tools an [ArchiveFormat] can be read with, for "needs ..." messages.
List<String> archiveTools(ArchiveFormat format) => switch (format) {
  ArchiveFormat.tar => ['tar', 'bsdtar'],
  ArchiveFormat.zip => ['unzip', 'bsdtar', '7z', 'python3'],
  ArchiveFormat.sevenZip => ['7z', 'bsdtar'],
  ArchiveFormat.deb => ['dpkg-deb', 'bsdtar'],
  ArchiveFormat.single => [_decompressor(ArchiveFormat.single, '')],
};

/// Parses what [archiveListScript] printed for [path].
ArchiveListing parseArchiveListing(String path, CommandResult r) {
  final lines = const LineSplitter().convert(r.stdout);
  final tool = lines.isEmpty ? '' : lines.first.trim();
  final body = lines.skip(1);
  final format = archiveFormatFor(path) ?? ArchiveFormat.tar;
  if (tool == '@none' || tool.isEmpty) throw MissingToolException(archiveTools(format));
  if (!r.ok && body.isEmpty) throw InspectException(r.stderr.trim().isEmpty ? 'exit ${r.exitCode}' : r.stderr.trim());
  final entries = switch (tool) {
    '@tar' || '@bsdtar' || '@dpkg' => [for (final l in body) ?_tarLine(l)],
    '@unzip' => [for (final l in body) ?_unzipLine(l)],
    '@pyzip' => [for (final l in body) ?_pyzipLine(l)],
    '@7z' => _sevenZipEntries(body),
    '@single' => [_entry(archiveStem(path), isDir: false)],
    _ => throw InspectException('Unexpected output: $tool'),
  };
  if (!r.ok && entries.isEmpty) throw InspectException(r.stderr.trim());
  return ArchiveListing(tool.substring(1), entries.where((e) => e.path.isNotEmpty).toList());
}

ArchiveEntry _entry(String name, {required bool isDir, int? size, String? modified, String? link}) {
  var path = name;
  while (path.startsWith('./')) {
    path = path.substring(2);
  }
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return ArchiveEntry(
    name: name,
    path: path == '.' ? '' : path,
    isDir: isDir || name.endsWith('/'),
    size: size,
    modified: modified,
    link: link,
  );
}

// GNU tar and dpkg-deb: `-rw-r--r-- user/group 1234 2026-01-02 10:00 path`.
final _gnuTar = RegExp(r'^([-dlhcbps])\S{9}\S*\s+\S+\s+(\d+)\s+(\d{4}-\d\d-\d\d \d\d:\d\d(?::\d\d)?)\s(.*)$');
// bsdtar: `-rw-r--r--  0 user group 1234 Jan  2 10:00 path`.
final _bsdTar = RegExp(
  r'^([-dlhcbps])\S{9}\S*\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\w{3}\s+\d{1,2}\s+(?:\d\d:\d\d|\d{4}))\s(.*)$',
);

ArchiveEntry? _tarLine(String line) {
  final m = _gnuTar.firstMatch(line) ?? _bsdTar.firstMatch(line);
  if (m == null) return null;
  final type = m[1]!;
  var name = m[4]!;
  String? link;
  if (type == 'l' && name.contains(' -> ')) {
    final i = name.indexOf(' -> ');
    link = name.substring(i + 4);
    name = name.substring(0, i);
  } else if (type == 'h' && name.contains(' link to ')) {
    final i = name.indexOf(' link to ');
    link = name.substring(i + 9);
    name = name.substring(0, i);
  }
  return _entry(name, isDir: type == 'd', size: int.tryParse(m[2]!), modified: m[3], link: link);
}

// `    1234  2026-01-02 10:00   path` (the date may be MM-DD-YYYY).
final _unzip = RegExp(r'^\s*(\d+)\s+(\d[\d-]+\d)\s+(\d\d:\d\d)\s+(.+)$');

ArchiveEntry? _unzipLine(String line) {
  final m = _unzip.firstMatch(line);
  if (m == null) return null;
  final name = m[4]!;
  return _entry(name, isDir: name.endsWith('/'), size: int.tryParse(m[1]!), modified: '${m[2]} ${m[3]}');
}

final _pyzip = RegExp(r'^(\d+) (.+)$');

ArchiveEntry? _pyzipLine(String line) {
  final m = _pyzip.firstMatch(line);
  if (m == null) return null;
  return _entry(m[2]!, isDir: m[2]!.endsWith('/'), size: int.tryParse(m[1]!));
}

/// `7z l -slt`: `Key = value` blocks after the `----------` line.
List<ArchiveEntry> _sevenZipEntries(Iterable<String> lines) {
  final out = <ArchiveEntry>[];
  var started = false;
  var block = <String, String>{};
  void flush() {
    final path = block['Path'];
    if (path != null) {
      final attributes = block['Attributes'] ?? '';
      out.add(
        _entry(
          path,
          isDir: block['Folder'] == '+' || attributes.startsWith('D'),
          size: int.tryParse(block['Size'] ?? ''),
          modified: block['Modified'],
        ),
      );
    }
    block = {};
  }

  for (final line in lines) {
    if (!started) {
      started = line.startsWith('----------');
      continue;
    }
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    final i = line.indexOf(' = ');
    if (i > 0) block[line.substring(0, i)] = line.substring(i + 3);
  }
  flush();
  return out;
}

String _decompressor(ArchiveFormat format, String path) => switch (_ext(path)) {
  'xz' || 'lzma' => 'xz',
  'bz2' => 'bzip2',
  'zst' => 'zstd',
  'lz4' => 'lz4',
  _ => 'gzip',
};

/// Unpacks [names] (everything when empty) of the archive at [path] into the folder [destExpr] (a shell
/// word: quoted path or "$D"), with the [tool] that listed it.
String archiveExtractScript(String path, String tool, String destExpr, List<String> names) {
  final f = shellQuote(path);
  final list = names.map(shellQuote).join(' ');
  return switch (tool) {
    'tar' => 'tar -xf $f -C $destExpr $list',
    'bsdtar' => 'bsdtar -xf $f -C $destExpr $list',
    'dpkg' => names.isEmpty ? 'dpkg-deb -x $f $destExpr' : 'dpkg-deb --fsys-tarfile $f | tar -xf - -C $destExpr $list',
    'unzip' => 'unzip -o -q $f $list -d $destExpr',
    'pyzip' =>
      'python3 -c ${shellQuote('import zipfile,sys\nzipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2], sys.argv[3:] or None)')} '
          '$f $destExpr $list',
    '7z' => '$_sevenZip && "\$Z" x -y -o$destExpr $f $list >/dev/null',
    'single' => '${_decompressor(ArchiveFormat.single, path)} -dc $f > $destExpr/${shellQuote(archiveStem(path))}',
    _ => 'false',
  };
}

/// Unpacks [names] into a new temporary folder on the server and prints its path.
String archiveExtractToTempScript(String path, String tool, List<String> names) =>
    r'D=$(mktemp -d "${TMPDIR:-/tmp}/nux-XXXXXX") || exit 1; '
    '${archiveExtractScript(path, tool, r'"$D"', names)} || exit 1; '
    r'printf %s "$D"';

/// Unpacks everything (or [names]) into [dest], creating it.
String archiveExtractAllScript(String path, String tool, String dest, [List<String> names = const []]) =>
    'mkdir -p ${shellQuote(dest)} && ${archiveExtractScript(path, tool, shellQuote(dest), names)}';

// ---------------------------------------------------------------------------------------------------------
// SQLite

/// Runs [sql] read-only on the database at [path] and prints the rows as JSON: with sqlite3 when it knows
/// `-json` (3.33+), else Python's sqlite3 module.
String sqliteQueryScript(String path, String sql) {
  const py =
      'import sqlite3,json,sys,urllib.request\n'
      "c=sqlite3.connect('file:'+urllib.request.pathname2url(sys.argv[1])+'?mode=ro',uri=True)\n"
      'cur=c.execute(sys.argv[2])\n'
      'cols=[d[0] for d in cur.description or []]\n'
      "v=lambda x: ('<%d bytes>' % len(x)) if isinstance(x,(bytes,bytearray)) else x\n"
      'print(json.dumps([dict(zip(cols,map(v,r))) for r in cur.fetchall()]))';
  final f = shellQuote(path);
  final q = shellQuote(sql);
  return "if command -v sqlite3 >/dev/null 2>&1 && sqlite3 -json :memory: 'select 1' >/dev/null 2>&1; then "
      'sqlite3 -readonly -json $f $q; '
      'elif command -v python3 >/dev/null 2>&1; then python3 -c ${shellQuote(py)} $f $q; '
      'else echo @none; fi';
}

/// Rows from [sqliteQueryScript]; columns keep their order.
List<Map<String, Object?>> parseSqliteRows(CommandResult r) {
  final out = r.stdout.trim();
  if (out == '@none') throw const MissingToolException(['sqlite3', 'python3']);
  if (!r.ok) throw InspectException(r.stderr.trim().isEmpty ? 'exit ${r.exitCode}' : r.stderr.trim());
  if (out.isEmpty) return const [];
  final data = jsonDecode(out);
  if (data is! List) throw const InspectException('Unexpected output');
  return [for (final row in data) Map<String, Object?>.from(row as Map)];
}

/// `"my ""table"""`: an identifier for SQL.
String sqlIdentifier(String name) => '"${name.replaceAll('"', '""')}"';

const sqliteTablesQuery =
    "select name, type from sqlite_master where type in ('table', 'view') and name not like 'sqlite_%' order by name";

String sqliteCountQuery(String table) => 'select count(*) as n from ${sqlIdentifier(table)}';

String sqliteRowsQuery(String table, {int limit = 100, int offset = 0}) =>
    'select * from ${sqlIdentifier(table)} limit $limit offset $offset';

// ---------------------------------------------------------------------------------------------------------
// Details: media, PDFs, pictures, programs

/// One part of a file's details: name-value pairs or text.
class DetailSection {
  const DetailSection(this.kind, {this.pairs = const [], this.text});

  /// file, media, pdf, pdfText, metadata, elf, libraries, strings.
  final String kind;
  final List<(String, String)> pairs;
  final String? text;
}

const _marker = '@@nux:';

/// Describes the file at [path] as [type] (null: only `file`, and the readable strings in it).
String detailsScript(String path, InspectType? type) {
  final f = shellQuote(path);
  String section(String name, String tool, String command) =>
      'if command -v $tool >/dev/null 2>&1; then echo $_marker$name; $command 2>/dev/null; fi; ';
  final parts = StringBuffer(section('file', 'file', 'file -b $f'));
  switch (type) {
    case InspectType.media:
      parts.write(
        'if command -v ffprobe >/dev/null 2>&1; then echo ${_marker}ffprobe; '
        'ffprobe -v error -show_format -show_streams -of json $f 2>/dev/null; '
        'elif command -v exiftool >/dev/null 2>&1; then echo ${_marker}metadata; exiftool $f 2>/dev/null | head -n 300; fi; ',
      );
    case InspectType.pdf:
      parts
        ..write(section('pdfinfo', 'pdfinfo', 'pdfinfo $f'))
        ..write(section('pdftext', 'pdftotext', 'pdftotext -l 30 -layout $f - | head -c 300000'));
    case InspectType.image:
      parts.write(
        'if command -v exiftool >/dev/null 2>&1; then echo ${_marker}metadata; exiftool $f 2>/dev/null | head -n 300; '
        'elif command -v identify >/dev/null 2>&1; then echo ${_marker}identify; identify $f 2>/dev/null; fi; ',
      );
    case InspectType.executable || null:
      parts
        ..write(section('elf', 'readelf', 'readelf -h $f'))
        ..write(section('libraries', 'readelf', "readelf -d $f | grep '(NEEDED)'"))
        ..write(section('strings', 'strings', 'strings -n 6 $f | head -n 3000'));
    case InspectType.archive || InspectType.database:
      break;
  }
  return parts.toString();
}

/// Parses what [detailsScript] printed. Empty when the server has none of the tools.
List<DetailSection> parseDetails(String output) {
  final raw = <(String, StringBuffer)>[];
  for (final line in const LineSplitter().convert(output)) {
    if (line.startsWith(_marker)) {
      raw.add((line.substring(_marker.length).trim(), StringBuffer()));
    } else if (raw.isNotEmpty) {
      raw.last.$2.writeln(line);
    }
  }
  final out = <DetailSection>[];
  for (final (name, buffer) in raw) {
    final text = buffer.toString().trimRight();
    if (text.trim().isEmpty) continue;
    switch (name) {
      case 'file':
        out.add(DetailSection('file', pairs: [('Type', text.trim())]));
      case 'ffprobe':
        final media = _ffprobe(text);
        if (media != null) out.add(media);
      case 'pdfinfo':
        out.add(DetailSection('pdf', pairs: _colonPairs(text)));
      case 'pdftext':
        out.add(DetailSection('pdfText', text: text));
      case 'metadata':
        out.add(DetailSection('metadata', pairs: _colonPairs(text)));
      case 'identify':
        out.add(DetailSection('metadata', text: text));
      case 'elf':
        final pairs = _colonPairs(text).where((p) => p.$1 != 'ELF Header' && p.$1 != 'Magic').toList();
        if (pairs.isNotEmpty) out.add(DetailSection('elf', pairs: pairs));
      case 'libraries':
        final libs = [for (final m in RegExp(r'\[([^\]]+)\]').allMatches(text)) m[1]!];
        if (libs.isNotEmpty) out.add(DetailSection('libraries', text: libs.join('\n')));
      case 'strings':
        out.add(DetailSection('strings', text: text));
    }
  }
  return out;
}

/// `Key:   value` (pdfinfo, readelf) or `Key   : value` (exiftool) lines.
List<(String, String)> _colonPairs(String text) => [
  for (final line in const LineSplitter().convert(text))
    if (line.contains(':')) (line.substring(0, line.indexOf(':')).trim(), line.substring(line.indexOf(':') + 1).trim()),
];

String _duration(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
}

DetailSection? _ffprobe(String json) {
  final Map<String, Object?> data;
  try {
    data = Map<String, Object?>.from(jsonDecode(json) as Map);
  } catch (_) {
    return null;
  }
  final format = Map<String, Object?>.from((data['format'] as Map?) ?? const {});
  final pairs = <(String, String)>[];
  void add(String key, Object? value) {
    if (value != null && '$value'.isNotEmpty) pairs.add((key, '$value'));
  }

  add('Format', format['format_long_name'] ?? format['format_name']);
  final duration = double.tryParse('${format['duration']}');
  if (duration != null) add('Duration', _duration(duration));
  final bitRate = int.tryParse('${format['bit_rate']}');
  if (bitRate != null) add('Bitrate', '${(bitRate / 1000).round()} kb/s');
  for (final s in (data['streams'] as List?) ?? const []) {
    final stream = Map<String, Object?>.from(s as Map);
    final codec = stream['codec_name'] ?? '?';
    switch (stream['codec_type']) {
      case 'video':
        final rate = '${stream['avg_frame_rate'] ?? ''}'.split('/');
        final fps = rate.length == 2 && (int.tryParse(rate[1]) ?? 0) > 0
            ? (int.parse(rate[0]) / int.parse(rate[1])).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')
            : null;
        add('Video', '$codec, ${stream['width']}×${stream['height']}${fps == null || fps == '0' ? '' : ', $fps fps'}');
      case 'audio':
        final channels = stream['channel_layout'] ?? (stream['channels'] == null ? null : '${stream['channels']} ch');
        add('Audio', [codec, if (stream['sample_rate'] != null) '${stream['sample_rate']} Hz', ?channels].join(', '));
      case 'subtitle':
        final lang = (stream['tags'] as Map?)?['language'];
        add('Subtitles', [codec, ?lang].join(', '));
    }
  }
  final tags = Map<String, Object?>.from((format['tags'] as Map?) ?? const {});
  for (final key in ['title', 'artist', 'album', 'date', 'genre', 'comment', 'encoder', 'creation_time']) {
    final value = tags[key] ?? tags[key.toUpperCase()];
    add(key[0].toUpperCase() + key.substring(1).replaceAll('_', ' '), value);
  }
  return DetailSection('media', pairs: pairs);
}
