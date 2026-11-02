import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/app_info.dart';
import 'package:nux/features/updates/domain/release.dart';

Map<String, dynamic> _release(String tag, {bool pre = false, bool draft = false, List<String> apks = const ['nux.apk']}) => {
      'tag_name': tag,
      'prerelease': pre,
      'draft': draft,
      'html_url': 'https://github.com/$releasesRepo/releases/tag/$tag',
      'body': 'notes',
      'assets': [
        for (final a in apks) {'name': a, 'browser_download_url': 'https://example.com/$a'},
      ],
    };

void main() {
  test('compareVersions', () {
    expect(compareVersions('1.2.10', '1.3'), lessThan(0));
    expect(compareVersions('1.3.0', '1.3'), 0);
    expect(compareVersions('1.3.0+7', '1.3.0+1'), 0);
    expect(compareVersions('1.3.0-beta.1', '1.3.0'), lessThan(0));
    expect(compareVersions('1.3.0-beta.2', '1.3.0-beta.10'), lessThan(0));
    expect(compareVersions('1.3.0-5-g1a2b3c4', '1.3.0'), greaterThan(0));
    expect(compareVersions('1.3.0-5-g1a2b3c4', '1.3.1-beta.1'), lessThan(0));
  });

  test('fromGitHub skips drafts, pre-releases (unless allowed) and releases without APKs', () {
    expect(Release.fromGitHub(_release('v1.0.0', draft: true)), isNull);
    expect(Release.fromGitHub(_release('v1.0.0', pre: true)), isNull);
    expect(Release.fromGitHub(_release('v1.0.0', pre: true), allowPrerelease: true)?.prerelease, isTrue);
    expect(Release.fromGitHub(_release('v1.0.0', apks: [])), isNull);
    expect(Release.fromGitHub(_release('v1.2.0'))?.version, '1.2.0');
  });

  test('newest picks the highest version, not the first listed', () {
    final list = [_release('v1.1.0'), _release('v1.2.0-beta.1', pre: true), _release('v1.0.0')];
    expect(Release.newest(list)?.version, '1.1.0');
    expect(Release.newest(list, allowPrerelease: true)?.version, '1.2.0-beta.1');
  });

  test('apkFor prefers the ABI split, then the universal APK', () {
    final r = Release.fromGitHub(_release('v1.0.0', apks: ['nux-1.0.0.apk', 'nux-1.0.0-arm64-v8a.apk']))!;
    expect(r.apkFor('arm64-v8a'), endsWith('-arm64-v8a.apk'));
    expect(r.apkFor('x86_64'), endsWith('nux-1.0.0.apk'));
  });

  test('displayVersion hides the build number and CI suffix', () {
    expect(displayVersion('1.2.0-5-g1a2b3c4+42'), '1.2.0');
    expect(displayVersion('1.3.0-beta.1+3'), '1.3.0-beta.1');
  });
}
