import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EsewaService {
  /// Opens a WebView and posts form data to eSewa payment URL.
  /// esewaParams should contain: scd (merchant), pid, amt, su, fu
  static Future<bool> openPayment(
      BuildContext context, Map<String, String> esewaParams,
      {String paymentUrl = 'https://esewa.com.np/epay/main'}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EsewaWebView(
          esewaParams: esewaParams,
          paymentUrl: paymentUrl,
        ),
      ),
    );

    return result ?? false;
  }
}

class _EsewaWebView extends StatefulWidget {
  final Map<String, String> esewaParams;
  final String paymentUrl;
  const _EsewaWebView(
      {required this.esewaParams, required this.paymentUrl, Key? key})
      : super(key: key);

  @override
  State<_EsewaWebView> createState() => _EsewaWebViewState();
}

class _EsewaWebViewState extends State<_EsewaWebView> {
  late final WebViewController _controller;

  String _buildAutoPostHtml() {
    final buffer = StringBuffer();
    buffer.writeln(
        '<html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body>');
    buffer.writeln(
        '<form id="esewaForm" method="post" action="${widget.paymentUrl}">');
    widget.esewaParams.forEach((k, v) {
      final safeVal = v
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('"', '&quot;');
      buffer.writeln('<input type="hidden" name="$k" value="$safeVal"/>');
    });
    buffer.writeln('</form>');
    buffer.writeln(
        '<script>document.getElementById("esewaForm").submit();</script>');
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // detect redirect to success or fail and close
          final url = req.url;
          if (url.contains('/api/payments/esewa/callback') ||
              url.contains('?status=failed')) {
            // pop with success true if callback contains success info
            Navigator.of(context).pop(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
  }

  @override
  Widget build(BuildContext context) {
    final html = _buildAutoPostHtml();
    return Scaffold(
        appBar: AppBar(
          title: const Text('eSewa Payment'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            )
          ],
        ),
        body: WebViewWidget(controller: _controller));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final html = _buildAutoPostHtml();
    _controller.loadHtmlString(html, baseUrl: widget.paymentUrl);
  }
}
