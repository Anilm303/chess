import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:chess_app/features/auth/data/services/auth_service.dart';

/// Polls the backend's tournament endpoint and shows what's happening:
///  * 'open'     - first slot, waiting for someone else
///  * 'waiting'  - you paid, waiting for opponent
///  * 'in_progress' - both paid, game can start
///  * 'finished' - someone won
class TournamentWaitingScreen extends StatefulWidget {
  final String tournamentId;
  final String backendBaseUrl; // no trailing /api
  /// Where to navigate when the tournament status becomes 'in_progress' or 'finished'.
  /// The caller decides what screen to show (e.g. a chess board).
  final void Function(TournamentState state) onStateChanged;

  const TournamentWaitingScreen({
    super.key,
    required this.tournamentId,
    required this.backendBaseUrl,
    required this.onStateChanged,
  });

  @override
  State<TournamentWaitingScreen> createState() => _TournamentWaitingScreenState();
}

class TournamentState {
  final String status; // open | waiting | in_progress | finished
  final String? winnerUserId;
  final double prizePool;
  final int paidPlayers;
  final int maxPlayers;
  final String title;
  final double entryFee;
  final List<dynamic> participants;

  const TournamentState({
    required this.status,
    required this.winnerUserId,
    required this.prizePool,
    required this.paidPlayers,
    required this.maxPlayers,
    required this.title,
    required this.entryFee,
    required this.participants,
  });

  factory TournamentState.fromJson(Map<String, dynamic> json) {
    final t = json['tournament'] as Map<String, dynamic>;
    return TournamentState(
      status: (t['status'] as String?) ?? 'open',
      winnerUserId: t['winner_user_id'] as String?,
      prizePool: double.tryParse('${t['prize_pool']}') ?? 0.0,
      paidPlayers: (t['paid_players'] as num?)?.toInt() ?? 0,
      maxPlayers: (t['max_players'] as num?)?.toInt() ?? 2,
      title: (t['title'] as String?) ?? 'Tournament',
      entryFee: double.tryParse('${t['entry_fee']}') ?? 0.0,
      participants: (json['participants'] as List?) ?? const [],
    );
  }
}

class _TournamentWaitingScreenState extends State<TournamentWaitingScreen> {
  Timer? _poll;
  TournamentState? _state;
  String? _error;
  String? _myUserId;
  double? _myWalletBalance;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _myUserId = auth.currentUser?.username;
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    _refresh();
    // also check the wallet after a short delay (winner detection)
    _pollBalance();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String get _apiBase => widget.backendBaseUrl.endsWith('/api')
      ? widget.backendBaseUrl
      : '${widget.backendBaseUrl}/api';

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = auth.accessToken;
      final res = await http
          .get(
            Uri.parse('${_apiBase}/tournaments/${widget.tournamentId}'),
            headers: {
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final s = TournamentState.fromJson(body);
        if (!mounted) return;
        setState(() {
          _state = s;
          _error = null;
        });
        if (!_navigated && (s.status == 'in_progress' || s.status == 'finished')) {
          _navigated = true;
          widget.onStateChanged(s);
        }
        if (s.status == 'finished') {
          _pollBalance();
        }
      } else {
        if (!mounted) return;
        setState(() => _error = 'Failed to load (HTTP ${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      // Don't show full-screen error if we already have a state (just a temporary glitch)
      if (_state == null) {
        setState(() => _error = 'Connecting to tournament... (Network error: $e)');
      }
    }
  }

  Future<void> _pollBalance() async {
    if (_myUserId == null) return;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = auth.accessToken;
      final res = await http.get(
        Uri.parse('${_apiBase}/users/$_myUserId/wallet'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _myWalletBalance = (body['wallet_balance'] as num?)?.toDouble());
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connecting...')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  )
                else
                  const Text('Initializing tournament state...'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final youWon = s.status == 'finished' && s.winnerUserId == _myUserId;
    final isFinished = s.status == 'finished';

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(s),
            const SizedBox(height: 24),
            _prizePoolCard(s),
            const SizedBox(height: 24),
            _playersCard(s),
            const Spacer(),
            if (isFinished && youWon && _myWalletBalance != null)
              _winnerCard(s, _myWalletBalance!),
            if (isFinished && !youWon)
              _loserCard(s),
            if (!isFinished)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () async {
                    // Manual verification call to backend
                    try {
                      final auth = context.read<AuthService>();
                      final token = auth.accessToken;
                      // Find current user's PID for this tournament from participants if possible
                      // or just have backend find latest pending payment for this user/tournament
                      // For now, let's look for a participant with 'joined' status
                      final myPart = s.participants.firstWhere((p) => p['user_id'] == _myUserId, orElse: () => null);
                      final pid = myPart != null ? myPart['payment_pid'] : null;

                      final res = await http.post(
                        Uri.parse('${_apiBase}/payments/esewa/verify'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: jsonEncode({'pid': pid}), // pid might be null, backend should handle it or use latest
                      );
                      
                      _refresh(); // refresh screen after verification
                      
                      if (res.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment status updated!'))
                        );
                      }
                    } catch (e) {
                      debugPrint('Verification error: $e');
                    }
                  },
                  child: const Text('I have paid (Refresh Status)'),
                ),
              ),
            if (!isFinished)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Waiting for opponent to pay...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(TournamentState s) {
    Color color;
    String label;
    IconData icon;
    switch (s.status) {
      case 'open':
        color = Colors.blue.shade100;
        label = 'Open — waiting for players';
        icon = Icons.hourglass_empty;
        break;
      case 'waiting':
        color = Colors.orange.shade100;
        label = 'Waiting for opponent to pay';
        icon = Icons.hourglass_top;
        break;
      case 'in_progress':
        color = Colors.green.shade100;
        label = 'Game in progress!';
        icon = Icons.sports_esports;
        break;
      case 'finished':
        color = Colors.purple.shade100;
        label = 'Tournament finished';
        icon = Icons.emoji_events;
        break;
      default:
        color = Colors.grey.shade200;
        label = s.status;
        icon = Icons.info_outline;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizePoolCard(TournamentState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Prize Pool', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'NPR ${s.prizePool.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (s.entryFee > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Entry fee: NPR ${s.entryFee.toStringAsFixed(2)} per player',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playersCard(TournamentState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Players (${s.paidPlayers}/${s.maxPlayers} paid)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...s.participants.map<Widget>((p) {
              final status = (p['status'] as String?) ?? 'pending';
              final userId = p['user_id']?.toString() ?? '?';
              IconData icon;
              Color color;
              switch (status) {
                case 'paid':
                  icon = Icons.check_circle;
                  color = Colors.green;
                  break;
                case 'pending':
                  icon = Icons.access_time;
                  color = Colors.orange;
                  break;
                default:
                  icon = Icons.help_outline;
                  color = Colors.grey;
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(icon, color: color),
                title: Text(userId == _myUserId ? '$userId (you)' : userId),
                trailing: Text(status),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _winnerCard(TournamentState s, double balance) {
    final prize = s.prizePool * 0.9; // 10% platform fee
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            const Text(
              'You won!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'NPR ${prize.toStringAsFixed(2)} credited to your wallet',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Wallet balance: NPR ${balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loserCard(TournamentState s) {
    return Card(
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.flag, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'Tournament won by ${s.winnerUserId ?? "opponent"}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Better luck next time!',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
