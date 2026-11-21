import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Shows a page of the Shabekin website inside the app (same pages, options and photos as the site).
/// Signed-in users are logged in automatically through a one-time code issued by the plugin.
class SiteView extends StatefulWidget {
  final String page; // site page slug, e.g. 'services', 'vehicle-rental', 'dashboard'
  const SiteView({super.key, required this.page});

  @override
  State<SiteView> createState() => _SiteViewState();
}

class _SiteViewState extends State<SiteView> {
  WebViewController? _c;
  String? _error;
  bool _loading = true;
  bool _canBack = false;
  String _sig = '';
  String? _host;
  DateTime _lastRelogin = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _sig = '${s.lang}|${s.loggedIn}';
    _open();
  }

  Future<void> _open() async {
    final s = context.read<AppState>();
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await s.api.webLink(widget.page);
      if (url.isEmpty) throw Exception('empty url');
      _host = Uri.parse(url).host;
      final c = _c ?? _makeController();
      _c = c;
      await c.loadRequest(Uri.parse(url));
    } catch (e) {
      if (mounted) setState(() {
        _error = errText(e);
        _loading = false;
      });
    }
  }

  WebViewController _makeController() {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.scheme == 'http' || u.scheme == 'https') {
            if (u.host == _host) {
              final signedIn = context.read<AppState>().loggedIn;
              final expired = u.path.contains('wp-login.php') && !u.queryParameters.containsKey('action');
              // The site session ended: sign in again silently (at most once every 20 seconds).
              if (signedIn && expired && DateTime.now().difference(_lastRelogin).inSeconds > 20) {
                _lastRelogin = DateTime.now();
                _open();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }
            openUrl(req.url); // other websites open in the browser
            return NavigationDecision.prevent;
          }
          openUrl(req.url); // tel:, mailto:, whatsapp: ...
          return NavigationDecision.prevent;
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) async {
          final b = await _c?.canGoBack() ?? false;
          if (mounted) setState(() {
            _loading = false;
            _canBack = b;
          });
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? false) && mounted) setState(() => _error = context.tr('load_failed'));
        },
      ));
    // File fields on the site forms (licence photos, documents). Resolved at runtime so the app
    // still builds if the WebView plugin changes this API.
    try {
      final dynamic p = c.platform;
      p.setOnShowFileSelector(_pickFiles);
    } catch (_) {}
    return c;
  }

  Future<List<String>> _pickFiles(dynamic params) async {
    try {
      final multi = params.mode.toString().toLowerCase().contains('multiple');
      final r = await FilePicker.platform.pickFiles(allowMultiple: multi, type: FileType.any);
      if (r == null) return <String>[];
      return r.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _back() async {
    if (_canBack) {
      await _c?.goBack();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sig = '${s.lang}|${s.loggedIn}';
    if (sig != _sig) {
      _sig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open();
      });
    }
    final canPop = Navigator.canPop(context);
    return Column(children: [
      Container(
        color: kGreen,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              SizedBox(
                width: 48,
                child: (_canBack || canPop) ? IconButton(tooltip: context.tr('site_back'), icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _back) : null,
              ),
              Expanded(child: Center(child: Image.asset('assets/logo.png', height: 30))),
              SizedBox(
                width: 48,
                child: IconButton(tooltip: context.tr('site_reload'), icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _c == null ? _open() : _c!.reload()),
              ),
            ]),
          ),
        ),
      ),
      SizedBox(height: 3, child: _loading ? const LinearProgressIndicator(minHeight: 3, color: kGold, backgroundColor: kGreen) : const ColoredBox(color: kGold)),
      Expanded(
        child: _error != null
            ? ErrorView(message: _error!, onRetry: _open)
            : (_c == null ? const Center(child: CircularProgressIndicator()) : WebViewWidget(controller: _c!)),
      ),
    ]);
  }
}
