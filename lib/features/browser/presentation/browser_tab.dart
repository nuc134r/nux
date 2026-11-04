import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tab_switcher/tab_switcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../../workspace/domain/nux_tab.dart';
import '../domain/address.dart';

/// A web page in a tab: an address bar, the page, and Back / Forward / Reload in ⋮. Mostly for what nux
/// forwards to `localhost`, but any site works. The page (with its history) lives in the tab object.
class BrowserTab extends NuxTab {
  BrowserTab({required this._url, String? id}) : id = id ?? 'browser:${newId()}';

  static const kindName = 'browser';

  @override
  final String id;

  String _url;
  String? _title;
  int progress = 100;

  /// Null where web views do not exist (tests, desktop for now).
  late final WebViewController? controller = WebViewPlatform.instance == null ? null : _create();

  WebViewController _create() {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            progress = p;
            notifyListeners();
          },
          onUrlChange: (change) {
            if (change.url != null) _url = change.url!;
            notifyListeners();
          },
          onPageFinished: (url) async {
            _url = url;
            _title = await controller?.getTitle();
            notifyListeners();
          },
        ),
      );
    if (_url.isNotEmpty) c.loadRequest(Uri.parse(_url));
    return c;
  }

  String get url => _url;

  void go(String typed) {
    final uri = addressToUri(typed);
    _url = '$uri';
    _title = null;
    controller?.loadRequest(uri);
    notifyListeners();
  }

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'url': _url};

  @override
  String get title {
    if (_title != null && _title!.trim().isNotEmpty) return _title!;
    final host = Uri.tryParse(_url)?.host ?? '';
    return host.isEmpty ? currentL10n.value.browser : host;
  }

  @override
  String? get subtitle => _url.isEmpty ? null : _url;

  @override
  IconData get icon => Icons.public;

  @override
  void Function(BuildContext context)? get onHeaderTap => (context) async {
    final typed = await askAddress(context, initial: _url);
    if (typed != null) go(typed);
  };

  @override
  Widget buildContent(BuildContext context) => _BrowserView(tab: this);

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    return [
      // Back, Forward and Reload on one line.
      NuxMenuCustom((menuContext) {
        Widget button(IconData icon, String tooltip, Future<void> Function()? action) => IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: c == null || action == null ? null : () => Navigator.of(menuContext).pop<VoidCallback>(action),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              button(Icons.arrow_back, l10n.goBack, c?.goBack),
              button(Icons.arrow_forward, l10n.goForward, c?.goForward),
              button(Icons.refresh, l10n.reloadPage, c?.reload),
            ],
          ),
        );
      }),
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.open_in_new,
        label: l10n.openInOtherApp,
        enabled: _url.isNotEmpty,
        onSelected: () => launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication),
      ),
      NuxMenuAction(
        icon: Icons.link,
        label: l10n.copyLink,
        enabled: _url.isNotEmpty,
        onSelected: () => Clipboard.setData(ClipboardData(text: _url)),
      ),
    ];
  }
}

class _BrowserView extends StatefulWidget {
  const _BrowserView({required this.tab});

  final BrowserTab tab;

  @override
  State<_BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<_BrowserView> {
  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_changed);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tab = widget.tab;
    final c = tab.controller;
    final active = TabSwitcher.isActive(context);
    return PopScope(
      // Back goes back in the page's history first.
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c == null) return;
        if (await c.canGoBack()) await c.goBack();
      },
      child: Column(
        children: [
          SizedBox(
            height: 2,
            child: tab.progress < 100 ? LinearProgressIndicator(value: tab.progress / 100, minHeight: 2) : null,
          ),
          Expanded(
            child: c == null ? Center(child: Text(l10n.webViewUnavailable)) : WebViewWidget(controller: c),
          ),
        ],
      ),
    );
  }
}

/// Opens [url] in a new browser tab.
void openBrowserTab(TabSwitcherController tabs, String url) => tabs.open(BrowserTab(url: url));

/// Asks for an address (or words to search); null when cancelled.
Future<String?> askAddress(BuildContext context, {String initial = ''}) async {
  final l10n = context.l10n;
  final text = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.browser),
      content: TextField(
        controller: text,
        autofocus: true,
        autocorrect: false,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(hintText: l10n.addressHint, prefixIcon: const Icon(Icons.public, size: 18)),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, text.text), child: Text(l10n.open)),
      ],
    ),
  );
  // Not disposed here: the dialog's closing animation still uses it (it is collected with the dialog).
  return result == null || result.trim().isEmpty ? null : result;
}
