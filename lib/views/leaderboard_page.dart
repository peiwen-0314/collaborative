import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final LeaderboardService _leaderboardService = LeaderboardService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
          ),
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Color(0xFF202020),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<LeaderboardEntry>>(
        stream: _leaderboardService.watchLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                  ),
                ),
              ),
            );
          }

          final entries =
              snapshot.data ?? const <LeaderboardEntry>[];

          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No leaderboard data available yet.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF777777),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
            children: [
              _TopThreeSection(entries: entries),

              const SizedBox(height: 24),

              const Text(
                'All Rankings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),

              const SizedBox(height: 12),

              for (int i = 0; i < entries.length; i++)
                _LeaderboardCard(
                  rank: i + 1,
                  entry: entries[i],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopThreeSection extends StatelessWidget {
  const _TopThreeSection({
    required this.entries,
  });

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF407F3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _TopUser(
              rank: 2,
              entry: second,
              height: 110,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TopUser(
              rank: 1,
              entry: first,
              height: 140,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TopUser(
              rank: 3,
              entry: third,
              height: 95,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUser extends StatelessWidget {
  const _TopUser({
    required this.rank,
    required this.entry,
    required this.height,
  });

  final int rank;
  final LeaderboardEntry? entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return const SizedBox();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1)
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD65C),
            size: 34,
          ),

        const SizedBox(height: 6),

        CircleAvatar(
          radius: rank == 1 ? 31 : 27,
          backgroundColor: Colors.white,
          child: Text(
            _initial(entry!.name),
            style: TextStyle(
              fontSize: rank == 1 ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF407F3A),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          entry!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          '${_formatNumber(entry!.totalPoints)} pts',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          height: height * 0.32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
          ),
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed[0].toUpperCase();
  }

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.rank,
    required this.entry,
  });

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E2E2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF407F3A),
              ),
            ),
          ),

          const SizedBox(width: 10),

          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFE5F4E4),
            child: Text(
              _initial(entry.name),
              style: const TextStyle(
                color: Color(0xFF407F3A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Level ${entry.level}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${_formatNumber(entry.totalPoints)} pts',
            style: const TextStyle(
              color: Color(0xFF407F3A),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed[0].toUpperCase();
  }

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );
  }
}