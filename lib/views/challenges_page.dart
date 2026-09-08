import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../widgets/eco_bottom_navigation.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final ChallengeService _service = ChallengeService();
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: const Text(
          'Challenges',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF202020)),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const EcoBottomNavigation(
        currentIndex: -1,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            color: const Color(0xFFF0F7ED),
            child: const Row(
              children: [
                Icon(Icons.location_on, color: AppColors.green),
                SizedBox(width: 10),
                Text(
                  'Challenges are tracked automatically',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: _ChallengeTabs(
              completedSelected: _showCompleted,
              onChanged: (value) => setState(() => _showCompleted = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserChallenge>>(
              stream: _service.watchCurrentUserChallenges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snapshot.error.toString().replaceFirst('Bad state: ', ''),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final challenges = (snapshot.data ?? const <UserChallenge>[])
                    .where((item) => item.isCompleted == _showCompleted)
                    .toList();
                if (challenges.isEmpty) {
                  return Center(
                    child: Text(
                      _showCompleted
                          ? 'No completed challenges yet.'
                          : 'No active challenges available.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  itemCount: challenges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) =>
                      _ChallengeCard(challenge: challenges[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeTabs extends StatelessWidget {
  const _ChallengeTabs({
    required this.completedSelected,
    required this.onChanged,
  });

  final bool completedSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5D5D5)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          _tab('Active', !completedSelected, () => onChanged(false)),
          _tab('Completed', completedSelected, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF333333),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});

  final UserChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final definition = challenge.definition;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(color: Color(0x13000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            height: 122,
            child: _ChallengeImage(definition: definition),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(definition.description, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 7),
                Text(
                  _progressText(challenge),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RewardChip(
                      icon: Icons.stars,
                      text: '+${definition.rewardPoints} Points',
                    ),
                    const SizedBox(width: 6),
                    _RewardChip(
                      icon: Icons.bolt,
                      text: '+${definition.rewardXp} XP',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: challenge.progress,
                          backgroundColor: const Color(0xFFE1E1E1),
                          valueColor: const AlwaysStoppedAnimation(AppColors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text('${(challenge.progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      challenge.isCompleted ? Icons.check_circle : Icons.sensors,
                      color: AppColors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      challenge.isCompleted
                          ? 'Completed automatically'
                          : definition.trackingSource == 'transport'
                          ? 'Tracking your trips'
                          : 'Auto-tracking active',
                      style: const TextStyle(fontSize: 11, color: AppColors.green),
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

  String _progressText(UserChallenge item) {
    final target = item.definition.targetValue;
    final current = item.currentValue.clamp(0.0, target);
    if (item.definition.challengeType == 'carbon_saved') {
      return '${current.toStringAsFixed(1)} of ${target.toStringAsFixed(0)} kg saved';
    }
    return '${current.round()} of ${target.round()} visited';
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF7EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.green),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeImage extends StatelessWidget {
  const _ChallengeImage({required this.definition});
  final ChallengeDefinition definition;

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      final icon = switch (definition.iconType) {
        'carbon' => Icons.co2,
        'location' => Icons.location_on,
        _ => Icons.account_balance,
      };
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4E7),
          borderRadius: BorderRadius.circular(45),
        ),
        child: Icon(icon, size: 46, color: AppColors.green),
      );
    }

    if (definition.imageUrl.isNotEmpty) {
      return Image.network(
        definition.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    if (definition.imageName.isNotEmpty) {
      return Image.asset(
        'assets/images/${definition.imageName}',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    return fallback();
  }
}
