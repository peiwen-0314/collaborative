import 'package:flutter/material.dart';

import '../services/badge_service.dart';

class MyBadgesPage extends StatefulWidget {
  const MyBadgesPage({super.key});

  @override
  State<MyBadgesPage> createState() => _MyBadgesPageState();
}

class _MyBadgesPageState extends State<MyBadgesPage> {
  final BadgeService _badgeService = BadgeService();

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
          'My Badges',
          style: TextStyle(
            color: Color(0xFF202020),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<UserBadge>>(
        stream: _badgeService.watchCurrentUserBadges(),
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
                  snapshot.error
                      .toString()
                      .replaceFirst('Bad state: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                  ),
                ),
              ),
            );
          }

          final badges = snapshot.data ?? const <UserBadge>[];

          if (badges.isEmpty) {
            return const Center(
              child: Text(
                'No badges available yet.',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                ),
              ),
            );
          }

          final unlocked =
              badges.where((badge) => badge.isUnlocked).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
            children: [
              _BadgeSummaryCard(
                unlocked: unlocked,
                total: badges.length,
              ),
              const SizedBox(height: 24),

              const Text(
                'Badge Collection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),

              const SizedBox(height: 14),

              ...badges.map(
                    (badge) => _BadgeCard(
                  badge: badge,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeSummaryCard extends StatelessWidget {
  const _BadgeSummaryCard({
    required this.unlocked,
    required this.total,
  });

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF407F3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 48,
            color: Color(0xFFFFD65C),
          ),
          const SizedBox(height: 10),
          Text(
            '$unlocked / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Badges Earned',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
  });

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    final challenge = badge.challenge;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.isUnlocked
              ? const Color(0xFFB8D7B4)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          _BadgeImage(
            imageUrl: challenge.badgeImageUrl,
            unlocked: badge.isUnlocked,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.badgeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: badge.isUnlocked
                        ? const Color(0xFF333333)
                        : const Color(0xFF888888),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  challenge.badgeDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF777777),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 8),

                if (badge.isUnlocked)
                  Text(
                    badge.unlockedAt == null
                        ? 'Unlocked'
                        : 'Unlocked • ${_formatDate(badge.unlockedAt!)}',
                    style: const TextStyle(
                      color: Color(0xFF407F3A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Color(0xFF999999),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Complete the challenge to unlock',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({
    required this.imageUrl,
    required this.unlocked,
  });

  final String imageUrl;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.35,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFFFFF6D8)
              : const Color(0xFFF0F0F0),
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.trim().isNotEmpty
            ? Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _fallbackIcon(),
        )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return const Icon(
      Icons.workspace_premium_rounded,
      size: 42,
      color: Color(0xFFD5A928),
    );
  }
}