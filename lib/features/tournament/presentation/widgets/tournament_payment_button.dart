import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../services/esewa_service.dart';

class TournamentPaymentButton extends StatefulWidget {
  final String userId;
  final String? tournamentId;
  final double amount;
  final String backendBaseUrl; // e.g. https://api.yourdomain.com

  const TournamentPaymentButton({
    super.key,
    required this.userId,
    this.tournamentId,
    required this.amount,
    required this.backendBaseUrl,
  });

  @override
  State<TournamentPaymentButton> createState() =>
      _TournamentPaymentButtonState();
}

class _TournamentPaymentButtonState extends State<TournamentPaymentButton> {
  bool _loading = false;

  Future<void> _startPayment() async {
    setState(() => _loading = true);
    try {
      final uri =
          Uri.parse('${widget.backendBaseUrl}/api/payments/esewa/create');
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': widget.userId,
            'tournament_id': widget.tournamentId,
            'amount': widget.amount,
          }));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final esewa = Map<String, String>.from(body['esewa'] as Map);
        final paymentUrl =
            body['payment_url'] as String? ?? 'https://esewa.com.np/epay/main';
        final messenger = ScaffoldMessenger.of(context);
        final success = await EsewaService.openPayment(context, esewa,
            paymentUrl: paymentUrl);
        // After WebView closes, call verify to confirm status
        if (!mounted) return;
        if (success) {
          // optional: call verify endpoint
          final verifyUri =
              Uri.parse('${widget.backendBaseUrl}/api/payments/esewa/verify');
          await http.post(verifyUri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'pid': esewa['pid']}));
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  'Payment flow completed; check your tournament status.')));
        } else {
          messenger.showSnackBar(
              const SnackBar(content: Text('Payment cancelled or failed')));
        }
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
            const SnackBar(content: Text('Failed to create payment')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _startPayment,
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Pay to Join'),
    );
  }
}
