// Renders screenshots into docs/screenshots: `bash tool/screenshots.sh`.
// Skipped in a plain `flutter test`. Sample data only (example.com hosts, throwaway keys).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux_backend/nux_backend.dart' show CommandResult, FileEntry, FileSystem, LocalFileSystem, ProcessRunner, RunningProcess;
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/activity/activity_center.dart';
import 'package:nux/core/widgets/nux_menu.dart';
import 'package:nux/core/keys/key_bar_layout.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/domain/host_key_check.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/ssh/domain/ssh_prompter.dart';
import 'package:nux/features/ssh/presentation/dialog_prompter.dart';
import 'package:nux/features/terminal/domain/terminal_session.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/features/workspace/data/workspace_access.dart';
import 'package:nux/features/workspace/data/workspace_repository.dart';
import 'package:nux/features/workspace/domain/git_activity.dart';
import 'package:nux/features/workspace/presentation/workspace_drawer.dart';

import 'helpers.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _outDir = 'docs/screenshots';
const _phone = Size(412, 892);
const _desktop = Size(1280, 800);
const _statusBar = 32.0;

const _demo = '\x1b[1;32mdev@build\x1b[0m:\x1b[1;34m~/src/nux\x1b[0m\$ git status -sb\r\n'
    '## \x1b[32mmain\x1b[0m...\x1b[31morigin/main\x1b[0m [ahead 2]\r\n'
    ' \x1b[31mM\x1b[0m lib/features/terminal/terminal_view.dart\r\n'
    '\x1b[32mA\x1b[0m  lib/features/ssh/ssh_pool.dart\r\n'
    '\x1b[1;32mdev@build\x1b[0m:\x1b[1;34m~/src/nux\x1b[0m\$ ls --color\r\n'
    '\x1b[1;34mandroid\x1b[0m  \x1b[1;34mdocs\x1b[0m  \x1b[1;34mlib\x1b[0m  \x1b[1;34mpackages\x1b[0m  pubspec.yaml  README.md\r\n'
    '\x1b[1;32mdev@build\x1b[0m:\x1b[1;34m~/src/nux\x1b[0m\$ uptime\r\n'
    ' 10:24:07 up 41 days,  3:12,  2 users,  load average: 0.21, 0.18, 0.12\r\n'
    '\x1b[1;32mdev@build\x1b[0m:\x1b[1;34m~/src/nux\x1b[0m\$ ';

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    Future<ByteData> file(String path) async => ByteData.sublistView(await File(path).readAsBytes());
    Future<ByteData> material(String name) => file('$flutterRoot/bin/cache/artifacts/material_fonts/$name');
    await (FontLoader('Roboto')
          ..addFont(material('Roboto-Regular.ttf'))
          ..addFont(material('Roboto-Medium.ttf'))
          ..addFont(material('Roboto-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')..addFont(material('MaterialIcons-Regular.otf'))).load();
    await (FontLoader('JetBrains Mono')..addFont(file('assets/fonts/JetBrainsMono[wght].ttf'))).load();
    await (FontLoader('Fira Code')..addFont(file('assets/fonts/FiraCode-Regular.ttf'))).load();
    await (FontLoader('Hack')..addFont(file('assets/fonts/Hack-Regular.ttf'))).load();
    await (FontLoader('Source Code Pro')..addFont(file('assets/fonts/SourceCodePro-Regular.otf'))).load();
  });

  Future<void> terminalTab(WidgetTester tester, ProviderContainer c) async {
    final tab = container(c).terminal('sample');
    tab.session.state = TerminalState.connected; // shown as connected; nothing is dialled
    tab.session.terminal.write(Uint8List.fromList(utf8.encode(_demo)));
    c.read(workspaceProvider).open(tab);
  }

  /// A small project to browse; the files tab and viewer read it instead of SFTP.
  Directory sampleProject() {
    final root = Directory.systemTemp.createTempSync('nux-shot-');
    Directory('${root.path}/lib/src').createSync(recursive: true);
    Directory('${root.path}/test').createSync();
    Directory('${root.path}/.git').createSync();
    File('${root.path}/README.md').writeAsStringSync(
      '# demo\n\nA sample project.\n\n## Next\n\n- [x] Count taps\n- [ ] Reset button\n- [ ] Dark theme\n\n'
      '```dart\nvoid main() => runApp(const CounterApp());\n```\n',
    );
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: demo\nenvironment:\n  sdk: ^3.13.0\n');
    File('${root.path}/.gitignore').writeAsStringSync('build/\n');
    File('${root.path}/lib/main.dart').writeAsStringSync(_sampleDart);
    File('${root.path}/deploy.sh').writeAsStringSync('#!/bin/sh\nset -e\nrsync -a build/ server:/srv/demo/\n');
    return root;
  }

  Future<void> useLocal(ProviderContainer c, Directory root) async {
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(_Owned(LocalFileSystem(root.path)), release: () {});
  }

  final shots = <String, _Shot>{
    'hosts': const _Shot(ThemeMode.dark, Routes.home),
    'host_menu': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      await tester.tap(find.text('Build server'));
    }),
    'terminal': _Shot(ThemeMode.dark, Routes.home, act: terminalTab),
    'workspace': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      addTearDown(() => root.deleteSync(recursive: true));
      await useLocal(c, root);
      _workspaceRoot = root.path;
      final id = (await tester.runAsync(
        () => c.read(workspaceRepositoryProvider).create(name: 'demo', connectionId: 'sample', rootPath: root.path),
      ))!;
      await tester.runAsync(() => c.read(workspaceSwitcherProvider).switchTo(id));
      await settle(tester);
      c.read(workspaceProvider).gridOpen = true;
      await settle(tester);
      await tester.tap(find.byTooltip('Workspaces'));
      await settle(tester);
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('lib')));
    }),
    // A pull in progress in the workspace card, and its output (sample text, example.com remote).
    'git_output': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      addTearDown(() => root.deleteSync(recursive: true));
      await useLocal(c, root);
      _workspaceRoot = root.path;
      final id = (await tester.runAsync(
        () => c.read(workspaceRepositoryProvider).create(name: 'demo', connectionId: 'sample', rootPath: root.path),
      ))!;
      final activity = c.read(workspaceDrawerStateProvider).gitActivity[id] = GitActivity();
      final fetch = activity.start('git fetch -q --all --prune');
      activity.output(fetch, 'Fetching origin\n');
      activity.finish(fetch, 0);
      final pull = activity.start('git pull -q --no-rebase --ff-only', cancel: () {});
      activity.output(
        pull,
        'remote: Enumerating objects: 214, done.\nremote: Counting objects: 100% (214/214), done.\n'
        'remote: Compressing objects: 100% (96/96), done.\nReceiving objects:  45% (97/214), 1.20 MiB | 2.31 MiB/s\r',
      );
      await tester.runAsync(() => c.read(workspaceSwitcherProvider).switchTo(id));
      await settle(tester);
      c.read(workspaceProvider).gridOpen = true;
      await settle(tester);
      await tester.tap(find.byTooltip('Workspaces'));
      await settle(tester);
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.textContaining('git pull')));
    }),
    // The Activity sheet with sample entries (example.com host names only).
    'activity': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final a = c.read(activityCenterProvider);
      a.finish(a.start(ActivitySource.git, 'git push -q', subtitle: 'demo'), ActivityState.done, unread: false);
      a.event(ActivitySource.other, 'Saved deploy.sh', unread: false);
      a.event(
        ActivitySource.forwarding,
        'Forwarding Database stopped',
        subtitle: 'Port 5432 is already in use on this device',
        state: ActivityState.failed,
        retry: () {},
      );
      a.event(ActivitySource.update, 'nux 0.11.0 is available');
      final up = a.start(ActivitySource.transfer, 'Upload backup.tar', subtitle: '/srv/app', cancel: () {});
      a.update(up, progress: .35);
      final pull = a.start(ActivitySource.git, 'git pull -q --no-rebase --ff-only', subtitle: 'demo', cancel: () {});
      a.update(pull, progress: .45, subtitle: 'Receiving objects:  45% (97/214)');
      await settle(tester);
      await tester.tap(find.byType(NuxMenuButton).first);
      await settle(tester);
      await tester.tap(find.text('Activity'));
    }),
    'tabs': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      await terminalTab(tester, c);
      await settle(tester);
      c.read(workspaceProvider).open(container(c).terminal('sample'), foreground: false);
      c.read(workspaceProvider).gridOpen = true;
    }),
    'files': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      await useLocal(c, root);
      c.read(workspaceProvider).open(container(c).files('sample', path: root.path));
    }),
    'viewer': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      await useLocal(c, root);
      c.read(workspaceProvider).open(container(c).viewer('sample', '${root.path}/lib/main.dart'));
    }),
    'menu': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      await useLocal(c, root);
      c.read(workspaceProvider).open(container(c).files('sample', path: root.path));
      await settle(tester);
      await tester.tap(find.byTooltip('More'));
    }),
    'menu_sort': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      await useLocal(c, root);
      c.read(workspaceProvider).open(container(c).files('sample', path: root.path));
      await settle(tester);
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.text('Sort'));
    }),
    'markdown': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      final root = sampleProject();
      await useLocal(c, root);
      c.read(workspaceProvider).open(container(c).viewer('sample', '${root.path}/README.md'));
    }),
    'host_key': _Shot(ThemeMode.light, Routes.home, act: (tester, c) async {
      showDialog<void>(
        context: rootNavigatorKey.currentContext!,
        builder: (context) => const HostKeyDialog(
          question: HostKeyQuestion(
            host: 'build.example.com',
            port: 22,
            keyType: 'ssh-ed25519',
            fingerprint: 'SHA256:Zx3Fh0cY0tM9vYQm1T3H3m1v9b1gQ8x6xw7Qq2c0kDg',
            status: HostKeyStatus.changed,
            knownFingerprints: ['ssh-ed25519 SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'],
          ),
        ),
      );
    }),
    'editor': _Shot(ThemeMode.light, Routes.connection('sample')),
    'forwarding': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      await tester.tap(find.byTooltip('Forwardings'));
    }),
    'forward_rule': _Shot(ThemeMode.light, Routes.forward('sample')),
    'appearance': const _Shot(ThemeMode.dark, Routes.appearance),
    'appearance_colors': _Shot(ThemeMode.dark, Routes.appearance, act: (tester, c) async {
      await tester.tap(find.text('Like the app').first);
    }),
    'log': const _Shot(ThemeMode.light, Routes.log),
    'keys': _Shot(ThemeMode.dark, Routes.keyBar(KeyBarFor.terminal)),
    'keys_custom': _Shot(ThemeMode.dark, Routes.keyBar(KeyBarFor.editor), act: (tester, c) async {
      await tester.tap(find.text('Custom'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Add row'), 300, scrollable: find.byType(Scrollable).first);
    }),
    'key': _Shot(ThemeMode.dark, Routes.key('sample')),
    'generate': const _Shot(ThemeMode.light, Routes.newKey),
    'desktop': _Shot(ThemeMode.dark, Routes.home, size: _desktop, act: (tester, c) async {
      await terminalTab(tester, c);
    }),
  };

  for (final MapEntry(key: name, value: shot) in shots.entries) {
    testWidgets('screenshot $name', skip: !_enabled, (tester) async {
      debugDisableShadows = false;
      try {
        final db = memoryDb();
        final secrets = MemorySecretStore();
        await tester.runAsync(() async {
          await insertSamples(db, secrets);
          await SettingsRepository(db).set(SettingKeys.themeMode, shot.theme.name);
        });
        final phone = shot.size == _phone;
        final dpr = phone ? 2.5 : 1.5;
        tester.view.physicalSize = shot.size * dpr;
        tester.view.devicePixelRatio = dpr;
        if (phone) tester.view.padding = FakeViewPadding(top: _statusBar * dpr, bottom: 16 * dpr);
        addTearDown(tester.view.reset);

        final c = ProviderContainer(
          overrides: [
            ...testOverrides(db: db, secrets: secrets),
            workspaceOpenerProvider.overrideWithValue(
              (id) async => WorkspaceAccess(fs: LocalFileSystem(_workspaceRoot), runner: _FakeGit(), release: () {}),
            ),
          ],
        );
        addTearDown(c.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: _Frame(
                phone: phone,
                dark: shot.theme == ThemeMode.dark,
                child: UncontrolledProviderScope(container: c, child: const NuxApp()),
              ),
            ),
          ),
        );
        await settle(tester);
        if (shot.path != Routes.home) c.read(routerProvider).push(shot.path);
        await settle(tester);
        await shot.act?.call(tester, c);
        for (var i = 0; i < 4; i++) {
          await settle(tester);
        }

        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(_outDir).create(recursive: true);
          await File('$_outDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}

TabFactory container(ProviderContainer c) => c.read(tabFactoryProvider);

const _sampleDart = r'''import 'package:flutter/material.dart';

/// Counts taps. The classic, so the colours have something to show.
void main() => runApp(const CounterApp());

class CounterApp extends StatefulWidget {
  const CounterApp({super.key});

  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Tapped $_count times')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _count++),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
''';

class _Shot {
  const _Shot(this.theme, this.path, {this.size = _phone, this.act});

  final ThemeMode theme;
  final String path;
  final Size size;
  final Future<void> Function(WidgetTester tester, ProviderContainer container)? act;
}

/// Rounded corners and an Android-like status bar for phone shots; a plain window for desktop.
class _Frame extends StatelessWidget {
  const _Frame({required this.phone, required this.dark, required this.child});

  final bool phone;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!phone) return ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
    final color = dark ? Colors.white : Colors.black87;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _statusBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('10:24', style: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                  const Spacer(),
                  Icon(Icons.signal_cellular_alt, size: 16, color: color),
                  const SizedBox(width: 4),
                  Icon(Icons.wifi, size: 16, color: color),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full, size: 16, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The local file system with an owner on every entry, as SFTP reports it.
class _Owned implements FileSystem {
  _Owned(this._fs);

  final FileSystem _fs;

  FileEntry _own(FileEntry e) => FileEntry(
        path: e.path,
        type: e.type,
        size: e.size,
        modified: e.modified,
        mode: e.mode,
        linkTarget: e.linkTarget,
        targetIsDirectory: e.targetIsDirectory,
        owner: 'dev',
        group: 'dev',
      );

  @override
  Future<String> home() => _fs.home();
  @override
  Future<List<FileEntry>> list(String directory) async => [for (final e in await _fs.list(directory)) _own(e)];
  @override
  Future<FileEntry> stat(String path) async => _own(await _fs.stat(path));
  @override
  Future<Uint8List> readBytes(String path) => _fs.readBytes(path);
  @override
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress}) =>
      _fs.openRead(path, start: start, onProgress: onProgress);
  @override
  Future<void> writeBytes(String path, Uint8List bytes) => _fs.writeBytes(path, bytes);
  @override
  Future<void> writeStream(String path, Stream<List<int>> data, {int offset = 0, void Function(int written)? onProgress}) =>
      _fs.writeStream(path, data, offset: offset, onProgress: onProgress);
  @override
  Future<void> createDirectory(String path, {bool recursive = false}) => _fs.createDirectory(path, recursive: recursive);
  @override
  Future<void> rename(String from, String to) => _fs.rename(from, to);
  @override
  Future<void> delete(String path, {bool recursive = false}) => _fs.delete(path, recursive: recursive);
  @override
  Future<void> setMode(String path, int mode) => _fs.setMode(path, mode);
}

/// The folder the workspace drawer shows in screenshots.
String _workspaceRoot = '/';

/// A git status with a branch and two changes, without running git.
class _FakeGit implements ProcessRunner {
  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async =>
      CommandResult(
        exitCode: 0,
        stdout: '$_workspaceRoot\n## main...origin/main [ahead 1]\x00 M lib/main.dart\x00?? deploy.sh\x00',
        stderr: '',
      );

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) =>
      throw UnimplementedError();
}
