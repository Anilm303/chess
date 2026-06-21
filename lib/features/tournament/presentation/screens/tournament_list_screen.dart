import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/socket_service.dart';
import 'create_tournament_screen.dart';
import '../screens/tournament_join_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  List<dynamic> _tournaments = [];
  bool _loading = true;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _load();
    // Setup socket subscription for tournament updates
    final auth = context.read<AuthService>();
    final token = auth.accessToken ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socketService.connect(
        token: token,
        onMessage: (_) {},
        onConnected: () {},
        onDisconnected: () {},
        eventHandlers: {
          'tournament_update': (data) {
            // refresh list when tournament changes
            _load();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final token = auth.accessToken ?? '';
      final res =
          await http.get(Uri.parse('${ApiService.baseUrl}/tournaments'),
          headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() => _tournaments = json['tournaments'] ?? []);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _confirmDelete(String tid) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tournament?'),
        content: const Text('Are you sure you want to remove this tournament?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      _deleteTournament(tid);
    }
  }

  Future<void> _deleteTournament(String tid) async {
    try {
      final auth = context.read<AuthService>();
      final token = auth.accessToken ?? '';
      final res = await http.delete(
        Uri.parse('${ApiService.baseUrl}/tournaments/$tid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament deleted')));
        _load(); // refresh list
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['message'] ?? 'Failed to delete')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tournaments.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const CreateTournamentScreen()))
                            .then((_) => _load()),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Tournament'),
                      ),
                    );
                  }

                  final t = _tournaments[index - 1];
                  final int paid = (t['paid_players'] as num?)?.toInt() ?? 0;
                  final int max = (t['max_players'] as num?)?.toInt() ?? 2;
                  final auth = context.read<AuthService>();
                  final bool isOwner = t['owner'] == auth.currentUser?.username;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(t['title'] ?? 'Untitled')),
                          if (isOwner)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDelete(t['id']),
                            ),
                        ],
                      ),
                      subtitle: Text(
                          '${t['game_type'] ?? ''} · Entry: NPR ${t['entry_fee'] ?? 0} · Paid: $paid/$max'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final tid = t['id'];
                          final entry = (t['entry_fee'] ?? 0).toDouble();
                          final auth = context.read<AuthService>();
                          final userId = auth.currentUser?.username ?? '';

                          if (entry > 0) {
                            // create participant first
                            try {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final res = await http.post(
                                  Uri.parse(
                                      '${ApiService.baseUrl}/tournaments/$tid/join'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': 'Bearer ${auth.accessToken ?? ''}'
                                  },
                                  body: jsonEncode({'user_id': userId}));
                              if (res.statusCode == 200) {
                                navigator.push(MaterialPageRoute(
                                    builder: (_) => TournamentJoinScreen(
                                        userId: userId,
                                        tournamentId: tid,
                                        entryFee: entry,
                                        backendBaseUrl: ApiService.baseUrl)));
                              } else {
                                String errorMsg = 'Failed to join';
                                try {
                                  final body = jsonDecode(res.body);
                                  errorMsg = body['message'] ?? errorMsg;
                                } catch (_) {}
                                messenger.showSnackBar(SnackBar(
                                    content: Text(errorMsg)));
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          } else {
                            // free join: call join endpoint directly
                            try {
                              final messenger = ScaffoldMessenger.of(context);
                              final auth = context.read<AuthService>();
                              final res = await http.post(
                                  Uri.parse(
                                      '${ApiService.baseUrl}/tournaments/$tid/join'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': 'Bearer ${auth.accessToken ?? ''}'
                                  },
                                  body: jsonEncode({'user_id': userId}));
                              if (res.statusCode == 200) {
                                messenger.showSnackBar(const SnackBar(
                                    content: Text('Joined tournament')));
                                _load();
                              } else {
                                messenger.showSnackBar(const SnackBar(
                                    content: Text('Failed to join')));
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        child: const Text('Join'),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
