import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/friend_service.dart';
import '../../../../services/auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final svc = context.read<FriendService>();
      final token = auth.accessToken ?? '';
      svc.fetchContacts(token);
      svc.fetchRequests(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FriendService>();
    final auth = context.watch<AuthService>();
    final token = auth.accessToken ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Username to add',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final username = _searchController.text.trim();
                    if (username.isEmpty) return;
                    final ok = await svc.sendRequest(token, username);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Request sent' : 'Failed: ${svc.error}',
                        ),
                      ),
                    );
                    if (ok) _searchController.clear();
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await svc.fetchContacts(token);
                  await svc.fetchRequests(token);
                },
                child: ListView(
                  children: [
                    const Text(
                      'Requests',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (svc.requests.isEmpty) const Text('No pending requests'),
                    ...svc.requests.map(
                      (r) => ListTile(
                        title: Text(r),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                final ok = await svc.respondRequest(
                                  token,
                                  r,
                                  true,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Accepted' : 'Failed'),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                final ok = await svc.respondRequest(
                                  token,
                                  r,
                                  false,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Declined' : 'Failed'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    const Text(
                      'Contacts',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (svc.contacts.isEmpty) const Text('No friends yet'),
                    ...svc.contacts.map(
                      (c) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: c['profile_image'] != null
                              ? NetworkImage(c['profile_image'])
                              : null,
                          child: c['profile_image'] == null
                              ? Text(
                                  (c['first_name'] ?? '').isNotEmpty
                                      ? (c['first_name'][0])
                                      : (c['username'] ?? '')[0],
                                )
                              : null,
                        ),
                        title: Text(c['username'] ?? ''),
                        subtitle: Text(c['first_name'] ?? ''),
                        trailing: c['is_online'] == true
                            ? const Icon(
                                Icons.circle,
                                color: Colors.green,
                                size: 12,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
