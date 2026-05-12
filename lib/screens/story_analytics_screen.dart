import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/story_model.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';

class StoryAnalyticsScreen extends StatefulWidget {
  final Story story;

  const StoryAnalyticsScreen({super.key, required this.story});

  @override
  State<StoryAnalyticsScreen> createState() => _StoryAnalyticsScreenState();
}

class _StoryAnalyticsScreenState extends State<StoryAnalyticsScreen> {
  Map<String, dynamic>? analytics;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final authService = context.read<AuthService>();
    final storyService = context.read<StoryService>();

    if (authService.accessToken == null) {
      setState(() => isLoading = false);
      return;
    }

    final data = await storyService.fetchStoryAnalytics(
      widget.story.id,
      authService.accessToken!,
    );

    if (mounted) {
      setState(() {
        analytics = data;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: MessengerColors.messengerGradient,
          ),
        ),
        title: const Text(
          'Story Views & Reactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  MessengerColors.messengerBlue,
                ),
              ),
            )
          : analytics == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: MessengerColors.messengerBlue.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Stats overview
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.visibility,
                            label: 'Views',
                            count: analytics!['views_count'] ?? 0,
                            color: MessengerColors.messengerBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.emoji_emotions,
                            label: 'Reactions',
                            count: analytics!['reactions_count'] ?? 0,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Viewers section
                  if ((analytics!['viewers'] as List?)?.isNotEmpty ?? false)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Viewed by (${(analytics!['viewers'] as List).length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF8A8D91),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (analytics!['viewers'] as List).length,
                          itemBuilder: (context, index) {
                            final viewer =
                                (analytics!['viewers'] as List)[index]
                                    as Map<String, dynamic>;
                            return _buildViewerTile(viewer);
                          },
                        ),
                      ],
                    ),

                  const Divider(height: 1),

                  // Reactions section
                  if ((analytics!['reaction_details'] as Map?)?.isNotEmpty ??
                      false)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Reactions (${(analytics!['reaction_details'] as Map).length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF8A8D91),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              (analytics!['reaction_details'] as Map).length,
                          itemBuilder: (context, index) {
                            final entries =
                                (analytics!['reaction_details'] as Map).entries
                                    .toList();
                            final username = entries[index].key;
                            final reaction =
                                entries[index].value as Map<String, dynamic>;
                            return _buildReactionTile(
                              username: username,
                              emoji: reaction['emoji'] ?? '?',
                              timestamp: reaction['timestamp'],
                            );
                          },
                        ),
                      ],
                    ),

                  if (((analytics!['viewers'] as List?) ?? []).isEmpty &&
                      ((analytics!['reaction_details'] as Map?) ?? {}).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 64,
                              color: MessengerColors.messengerBlue.withOpacity(
                                0.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No views or reactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8A8D91),
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8D91)),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerTile(Map<String, dynamic> viewer) {
    final username = viewer['username'] ?? 'Unknown';
    final timestamp = viewer['timestamp'];
    final viewTime = timestamp != null ? DateTime.tryParse(timestamp) : null;
    final timeAgo = viewTime != null ? _getTimeAgo(viewTime) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MessengerColors.messengerBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MessengerColors.messengerBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8D91),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.visibility,
            size: 18,
            color: MessengerColors.messengerBlue.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionTile({
    required String username,
    required String emoji,
    String? timestamp,
  }) {
    final reactionTime = timestamp != null
        ? DateTime.tryParse(timestamp)
        : null;
    final timeAgo = reactionTime != null ? _getTimeAgo(reactionTime) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8D91),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else {
      final days = difference.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }
}
