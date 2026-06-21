import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

/// Result returned from the eSewa WebView flow.
class EsewaPaymentResult {
  final bool completed;
  final String? pid;
  final String? status; // 'paid' | 'pending' | 'failed' | 'cancelled'
  final String? refId;
  final String? message;

  const EsewaPaymentResult({
    required this.completed,
    this.pid,
    this.status,
    this.refId,
    this.message,
  });

  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled' || (!completed && status == null);
}

/// eSewa service that opens a WebView to eSewa's payment page and waits for
/// the callback to land on our backend. After the WebView closes, we poll the
/// backend's status endpoint to confirm the final payment state.
class EsewaService {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _pollTimeout = Duration(seconds: 30);

  /// Opens eSewa in a WebView. Returns the final payment result.
  /// [backendBaseUrl] should NOT include the `/api` suffix.
  /// [esewaParams] must contain: scd, pid, amt, su, fu, tAmt, txAmt, psc, pdc
  /// [paymentUrl] is the eSewa endpoint (UAT or production).
  static Future<EsewaPaymentResult> openPayment({
    required BuildContext context,
    required Map<String, String> esewaParams,
    required String paymentUrl,
    String? backendBaseUrl,
    String? bearerToken,
  }) async {
    final pid = esewaParams['pid'];
    final completer = Completer<EsewaPaymentResult>();

    final result = await Navigator.push<EsewaPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _EsewaWebView(
          esewaParams: esewaParams,
          paymentUrl: paymentUrl,
        ),
      ),
    );

    // If user closed the WebView without a redirect, treat as cancelled.
    if (result == null) {
      // Best-effort: poll once to see if eSewa actually succeeded server-side.
      if (pid != null && backendBaseUrl != null) {
        final polled = await _pollStatus(
          backendBaseUrl: backendBaseUrl,
          pid: pid,
          bearerToken: bearerToken,
        );
        if (polled != null) return polled;
      }
      return EsewaPaymentResult(
        completed: false,
        pid: pid,
        status: 'cancelled',
        message: 'Payment cancelled by user',
      );
    }
    return result;
  }

  /// Poll the backend status endpoint until the payment reaches a terminal
  /// state (paid/failed) or the timeout expires.
  static Future<EsewaPaymentResult?> _pollStatus({
    required String backendBaseUrl,
    required String pid,
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$backendBaseUrl/payments/esewa/status/$pid');
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final body = json.decode(res.body) as Map<String, dynamic>;
          final status = body['status'] as String?;
          if (status == 'paid' || status == 'failed') {
            return EsewaPaymentResult(
              completed: status == 'paid',
              pid: pid,
              status: status,
              refId: body['esewa_ref_id'] as String?,
              message: status == 'paid' ? 'Payment successful' : 'Payment failed',
            );
          }
        }
      } catch (_) {
        // ignore and keep polling
      }
      await Future.delayed(_pollInterval);
    }
    return null;
  }
}

class _EsewaWebView extends StatefulWidget {
  final Map<String, String> esewaParams;
  final String paymentUrl;
  const _EsewaWebView({
    required this.esewaParams,
    required this.paymentUrl,
    Key? key,
  }) : super(key: key);

  @override
  State<_EsewaWebView> createState() => _EsewaWebViewState();
}

class _EsewaWebViewState extends State<_EsewaWebView> {
  late final WebViewController _controller;
  bool _htmlLoaded = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final url = req.url;
          if (_popped) return NavigationDecision.prevent;
          // Detect eSewa redirect to our backend callback.
          // Success URL contains "esewa/callback" (and may include ?data= base64)
          // Failure URL contains "status=failed" query.
          if (url.contains('/api/payments/esewa/callback')) {
            _popped = true;
            final isFailed = url.contains('status=failed') ||
                url.toLowerCase().contains('failure');
            Navigator.of(context).pop(EsewaPaymentResult(
              completed: !isFailed,
              pid: widget.esewaParams['pid'],
              status: isFailed ? 'failed' : 'paid',
              message: isFailed ? 'Payment failed at eSewa' : 'Payment successful',
            ));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (err) {
          // Network errors etc. — keep the WebView open so the user can retry.
        },
      ));
  }

  String _buildAutoPostHtml() {
    final buffer = StringBuffer();
    buffer.writeln(
        '<html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body>');
    buffer.writeln(
        '<form id="esewaForm" method="post" action="${widget.paymentUrl}">');
    widget.esewaParams.forEach((k, v) {
      final safeVal = v
          .replaceAll('&', '&')
          .replaceAll('<', '<')
          .replaceAll('"', '"');
      buffer.writeln('<input type="hidden" name="$k" value="$safeVal"/>');
    });
    buffer.writeln('</form>');
    buffer.writeln(
        '<script>document.getElementById("esewaForm").submit();</script>');
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  void _loadHtmlOnce() {
    if (_htmlLoaded) return;
    _htmlLoaded = true;
    _controller.loadHtmlString(_buildAutoPostHtml(), baseUrl: widget.paymentUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHtmlOnce();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSewa Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (_popped) return;
              _popped = true;
              Navigator.of(context).pop(const EsewaPaymentResult(
                completed: false,
                status: 'cancelled',
                message: 'Payment cancelled by user',
              ));
            },
          ),
        ],
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
