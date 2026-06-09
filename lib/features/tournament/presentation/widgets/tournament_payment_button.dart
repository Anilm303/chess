import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:chess_app/features/auth/data/services/auth_service.dart';
import '../../../../services/esewa_service.dart';

class TournamentPaymentButton extends StatefulWidget {
  final String userId;
  final String? tournamentId;
  final double amount;
  final String backendBaseUrl; // e.g. https://api.yourdomain.com (no trailing /api)

  /// Called when the payment reaches a terminal state (paid/failed/cancelled).
  /// Useful for refreshing the tournament list / page.
  final VoidCallback? onPaymentCompleted;

  const TournamentPaymentButton({
    super.key,
    required this.userId,
    this.tournamentId,
    required this.amount,
    required this.backendBaseUrl,
    this.onPaymentCompleted,
  });

  @override
  State<TournamentPaymentButton> createState() =>
      _TournamentPaymentButtonState();
}

class _TournamentPaymentButtonState extends State<TournamentPaymentButton> {
  bool _loading = false;

  Future<void> _startPayment() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.accessToken;
    final baseUrl = widget.backendBaseUrl.endsWith('/api')
        ? widget.backendBaseUrl
        : '${widget.backendBaseUrl}/api';
    final statusBase = widget.backendBaseUrl.endsWith('/api')
        ? widget.backendBaseUrl.substring(0, widget.backendBaseUrl.length - 4)
        : widget.backendBaseUrl;

    try {
      final uri = Uri.parse('$baseUrl/payments/esewa/create');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_id': widget.userId,
          'tournament_id': widget.tournamentId,
          'amount': widget.amount,
        }),
      );

      if (res.statusCode != 200) {
        _showError(messenger, 'Failed to create payment (HTTP ${res.statusCode})');
        return;
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        _showError(messenger, body['detail']?.toString() ?? 'Payment init failed');
        return;
      }

      final rawEsewa = body['esewa'] as Map;
      final esewa =
          rawEsewa.map((k, v) => MapEntry(k.toString(), v.toString()));
      final paymentUrl = body['payment_url'] as String? ??
          'https://uat.esewa.com.np/epay/main';
      final reused = body['reused'] == true;

      if (reused) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Resuming your previous pending payment…'),
          duration: Duration(seconds: 2),
        ));
      }

      if (!mounted) return;
      final result = await EsewaService.openPayment(
        context: context,
        esewaParams: esewa,
        paymentUrl: paymentUrl,
        backendBaseUrl: statusBase,
        bearerToken: token,
      );

      if (!mounted) return;
      _handleResult(result, messenger);
    } catch (e) {
      if (!mounted) return;
      _showError(messenger, 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleResult(EsewaPaymentResult result, ScaffoldMessengerState messenger) {
    if (result.isPaid) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.message ?? 'Payment successful'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
    } else if (result.isFailed) {
      _showError(messenger, result.message ?? 'Payment failed');
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(result.message ?? 'Payment cancelled'),
        duration: const Duration(seconds: 2),
      ));
    }
    widget.onPaymentCompleted?.call();
  }

  void _showError(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _startPayment,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.payment),
      label: Text(_loading ? 'Processing…' : 'Pay NPR ${widget.amount.toStringAsFixed(2)}'),
    );
  }
}
