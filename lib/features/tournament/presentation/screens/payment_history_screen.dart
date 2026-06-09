import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:chess_app/features/auth/data/services/auth_service.dart';
import 'package:intl/intl.dart';

/// Screen showing the authenticated user's payment history.
class PaymentHistoryScreen extends StatefulWidget {
  final String backendBaseUrl; // e.g. https://api.yourdomain.com (no trailing /api)
  const PaymentHistoryScreen({super.key, required this.backendBaseUrl});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _payments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.accessToken;
    final base = widget.backendBaseUrl.endsWith('/api')
        ? widget.backendBaseUrl
        : '${widget.backendBaseUrl}/api';
    try {
      final res = await http.get(
        Uri.parse('$base/payments/esewa/history'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          _payments = (body['payments'] as List?) ?? const [];
          _loading = false;
        });
      } else if (res.statusCode == 401) {
        setState(() {
          _error = 'Please sign in to view your payment history';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load history (HTTP ${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green.shade700;
      case 'failed':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 56, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _payments.isEmpty
                  ? const Center(child: Text('No payments yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _payments[i] as Map<String, dynamic>;
                          final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                          final currency = p['currency'] as String? ?? 'NPR';
                          final status = p['status'] as String? ?? 'pending';
                          final created = p['created_at']?.toString();
                          final verified = p['verified_at']?.toString();
                          final refId = p['esewa_ref_id'] as String?;
                          final tournamentId = p['tournament_id'] as String?;
                          final tournamentTitle =
                              p['tournament_title'] as String?;

                          return Card(
                            elevation: 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(status).withOpacity(0.15),
                                child: Icon(
                                  status == 'paid'
                                      ? Icons.check_circle
                                      : status == 'failed'
                                          ? Icons.cancel
                                          : Icons.hourglass_top,
                                  color: _statusColor(status),
                                ),
                              ),
                              title: Text(
                                tournamentTitle != null && tournamentTitle.isNotEmpty
                                    ? tournamentTitle
                                    : (tournamentId != null
                                        ? 'Tournament $tournamentId'
                                        : 'Top-up'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '$currency ${amount.toStringAsFixed(2)}  •  ${status.toUpperCase()}',
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (created != null)
                                    Text(
                                      'Created: ${_formatDate(created)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  if (verified != null)
                                    Text(
                                      'Verified: ${_formatDate(verified)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  if (refId != null && refId.isNotEmpty)
                                    Text(
                                      'eSewa ref: $refId',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }
}
