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
  Widget buildContent(BuildContext context) => _BrowserView(tab: this);

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    return [
      NuxMenuAction(icon: Icons.arrow_back, label: l10n.goBack, enabled: c != null, onSelected: () => c?.goBack()),
      NuxMenuAction(
        icon: Icons.arrow_forward,
        label: l10n.goForward,
        enabled: c != null,
        onSelected: () => c?.goForward(),
      ),
      NuxMenuAction(icon: Icons.refresh, label: l10n.reloadPage, enabled: c != null, onSelected: () => c?.reload()),
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
  late final _address = TextEditingController(text: widget.tab.url);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_changed);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_changed);
    _address.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    // The address follows the page, except while it is being edited.
    if (!_focus.hasFocus && _address.text != widget.tab.url) _address.text = widget.tab.url;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: TextField(
              controller: _address,
              focusNode: _focus,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autofocus: tab.url.isEmpty,
              onTap: () => _address.selection = TextSelection(baseOffset: 0, extentOffset: _address.text.length),
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                _focus.unfocus();
                tab.go(v);
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.addressHint,
                prefixIcon: const Icon(Icons.public, size: 18),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
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
