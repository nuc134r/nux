// Syntax highlighting for the file types people open most; others show as plain text.
import 'package:nux_backend/nux_backend.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cmake.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/elixir.dart';
import 'package:re_highlight/languages/erlang.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/groovy.dart';
import 'package:re_highlight/languages/haskell.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/languages/perl.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/protobuf.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/vim.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';

/// Highlighting language names by file extension.
const _byExtension = {
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'bashrc': 'bash',
  'zshrc': 'bash',
  'profile': 'bash',
  'env': 'bash',
  'c': 'c',
  'h': 'c',
  'cmake': 'cmake',
  'cc': 'cpp',
  'cpp': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'hh': 'cpp',
  'hxx': 'cpp',
  'cs': 'csharp',
  'css': 'css',
  'dart': 'dart',
  'diff': 'diff',
  'patch': 'diff',
  'dockerfile': 'dockerfile',
  'ex': 'elixir',
  'exs': 'elixir',
  'erl': 'erlang',
  'hrl': 'erlang',
  'go': 'go',
  'gradle': 'gradle',
  'graphql': 'graphql',
  'gql': 'graphql',
  'groovy': 'groovy',
  'hs': 'haskell',
  'ini': 'ini',
  'cfg': 'ini',
  'conf': 'ini',
  'toml': 'ini',
  'service': 'ini',
  'desktop': 'ini',
  'gitconfig': 'ini',
  'editorconfig': 'ini',
  'java': 'java',
  'js': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'jsx': 'javascript',
  'json': 'json',
  'jsonc': 'json',
  'arb': 'json',
  'lock': 'json',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'lua': 'lua',
  'mk': 'makefile',
  'makefile': 'makefile',
  'md': 'markdown',
  'markdown': 'markdown',
  'nginx': 'nginx',
  'pl': 'perl',
  'pm': 'perl',
  'php': 'php',
  'ps1': 'powershell',
  'psm1': 'powershell',
  'properties': 'properties',
  'proto': 'protobuf',
  'py': 'python',
  'pyw': 'python',
  'r': 'r',
  'rb': 'ruby',
  'gemspec': 'ruby',
  'rs': 'rust',
  'scala': 'scala',
  'sc': 'scala',
  'scss': 'scss',
  'sass': 'scss',
  'sql': 'sql',
  'swift': 'swift',
  'ts': 'typescript',
  'tsx': 'typescript',
  'mts': 'typescript',
  'vim': 'vim',
  'vimrc': 'vim',
  'xml': 'xml',
  'html': 'xml',
  'htm': 'xml',
  'svg': 'xml',
  'plist': 'xml',
  'xaml': 'xml',
  'csproj': 'xml',
  'iml': 'xml',
  'yaml': 'yaml',
  'yml': 'yaml',
};

/// Whole file names that say what they are.
const _byName = {
  'Dockerfile': 'dockerfile',
  'Makefile': 'makefile',
  'GNUmakefile': 'makefile',
  'CMakeLists.txt': 'cmake',
  'Jenkinsfile': 'groovy',
  'Vagrantfile': 'ruby',
  'Gemfile': 'ruby',
  'nginx.conf': 'nginx',
};

final _modes = <String, Mode>{
  'bash': langBash,
  'c': langC,
  'cmake': langCmake,
  'cpp': langCpp,
  'csharp': langCsharp,
  'css': langCss,
  'dart': langDart,
  'diff': langDiff,
  'dockerfile': langDockerfile,
  'elixir': langElixir,
  'erlang': langErlang,
  'go': langGo,
  'gradle': langGradle,
  'graphql': langGraphql,
  'groovy': langGroovy,
  'haskell': langHaskell,
  'ini': langIni,
  'java': langJava,
  'javascript': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'lua': langLua,
  'makefile': langMakefile,
  'markdown': langMarkdown,
  'nginx': langNginx,
  'perl': langPerl,
  'php': langPhp,
  'powershell': langPowershell,
  'properties': langProperties,
  'protobuf': langProtobuf,
  'python': langPython,
  'r': langR,
  'ruby': langRuby,
  'rust': langRust,
  'scala': langScala,
  'scss': langScss,
  'sql': langSql,
  'swift': langSwift,
  'typescript': langTypescript,
  'vim': langVim,
  'xml': langXml,
  'yaml': langYaml,
};

/// The highlighting language for [fileName] (by name, then extension), or null for plain text.
String? languageFor(String fileName) {
  final base = posix.basename(fileName);
  final byName = _byName[base];
  if (byName != null) return byName;
  final lower = base.toLowerCase();
  final ext = lower.startsWith('.') && !lower.substring(1).contains('.')
      ? lower.substring(1)
      : posix.extension(lower).replaceFirst('.', '');
  return _byExtension[ext];
}

Mode? modeFor(String language) => _modes[language];

/// A guess from the first line (`#!/usr/bin/env python3`) for files without an extension.
String? languageFromShebang(String firstLine) {
  if (!firstLine.startsWith('#!')) return null;
  for (final (needle, lang) in [
    ('python', 'python'),
    ('node', 'javascript'),
    ('bash', 'bash'),
    ('/sh', 'bash'),
    ('zsh', 'bash'),
    ('ruby', 'ruby'),
    ('perl', 'perl'),
    ('php', 'php'),
  ]) {
    if (firstLine.contains(needle)) return lang;
  }
  return null;
}
