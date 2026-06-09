import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _titleCtrl = TextEditingController();
  String _gameType = 'chess';
  final _entryCtrl = TextEditingController(text: '10');
  final _maxCtrl = TextEditingController(text: '2');
  bool _loading = false;

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final body = {
        'title': _titleCtrl.text.trim(),
        'game_type': _gameType,
        'entry_fee': double.tryParse(_entryCtrl.text) ?? 0.0,
        'max_players':
            int.tryParse(_maxCtrl.text) ?? (_gameType == 'ludo' ? 4 : 2),
      };
      final auth = context.read<AuthService>();
      final token = auth.accessToken ?? '';
      final res = await http.post(
          Uri.parse('${ApiService.baseUrl}/tournaments/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body));
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tournament created')));
        Navigator.of(context).pop();
      } else {
        final body = res.body;
        final snippet =
            body.length > 300 ? '${body.substring(0, 300)}...' : body;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${res.statusCode} — $snippet')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: _gameType,
                items: const [
                  DropdownMenuItem(value: 'chess', child: Text('Chess')),
                  DropdownMenuItem(value: 'ludo', child: Text('Ludo'))
                ],
                onChanged: (v) => setState(() => _gameType = v ?? 'chess')),
            const SizedBox(height: 12),
            TextField(
                controller: _entryCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Entry fee (NPR)')),
            const SizedBox(height: 12),
            TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max players')),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'))
          ],
        ),
      ),
    );
  }
}
