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
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/domain/host_key_check.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/ssh/domain/ssh_prompter.dart';
import 'package:nux/features/ssh/presentation/dialog_prompter.dart';
import 'package:nux/features/terminal/domain/terminal_session.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';

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
  });

  Future<void> terminalTab(WidgetTester tester, ProviderContainer c) async {
    final tab = container(c).terminal('sample');
    tab.session.state = TerminalState.connected; // shown as connected; nothing is dialled
    tab.session.terminal.write(Uint8List.fromList(utf8.encode(_demo)));
    c.read(workspaceProvider).open(tab);
  }

  final shots = <String, _Shot>{
    'hosts': const _Shot(ThemeMode.dark, Routes.home),
    'terminal': _Shot(ThemeMode.dark, Routes.home, act: terminalTab),
    'tabs': _Shot(ThemeMode.dark, Routes.home, act: (tester, c) async {
      await terminalTab(tester, c);
      await settle(tester);
      c.read(workspaceProvider).open(container(c).terminal('sample'), foreground: false);
      c.read(workspaceProvider).gridOpen = true;
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

        final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
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
        await settle(tester);
        await settle(tester);

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
