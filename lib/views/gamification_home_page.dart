import 'package:flutter/material.dart';
import 'leaderboard_page.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../models/gamification_summary.dart';
import '../services/gamification_service.dart';
import '../widgets/eco_bottom_navigation.dart';
import 'challenges_page.dart';
import 'point_history_page.dart';
import 'digital_passport_page.dart';
import 'my_badges_page.dart';
import 'ai_trip_planner_page.dart';
import 'ride_home_page.dart';
import 'community_feed_page.dart';
import 'profile_page.dart';
import 'home_page.dart';
import '../services/carbon_saving_service.dart';

class GamificationHomePage extends StatefulWidget {
  const GamificationHomePage({super.key});

  @override
  State<GamificationHomePage> createState() => _GamificationHomePageState();
}

class _GamificationHomePageState extends State<GamificationHomePage> {
  final ScrollController _shortcutController = ScrollController();
  final GamificationService _gamificationService = GamificationService();
  bool _processingLevelUp = false;

  @override
  void dispose() {
    _shortcutController.dispose();
    super.dispose();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature page will be connected next.')),
    );
  }

  void _scrollShortcuts(double offset) {
    if (!_shortcutController.hasClients) return;
    final target = (_shortcutController.offset + offset).clamp(
      0.0,
      _shortcutController.position.maxScrollExtent,
    );
    _shortcutController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _handleBottomNavigation(int index) {
    if (index == 3) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This module is managed by another page.')),
    );
  }

  void _checkForLevelUp(GamificationSummary summary) {
    if (_processingLevelUp || summary.requiredXp <= 0) return;
    if (summary.currentXp < summary.requiredXp) return;
    _processingLevelUp = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final result =
        await _gamificationService.processPendingLevelUp(summary);
        if (result != null && mounted) {
          await _showLevelUpDialog(result);
        }
      } finally {
        _processingLevelUp = false;
      }
    });
  }

  Future<void> _showLevelUpDialog(LevelUpResult result) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Level up',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelUpDialog(result: result);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<GamificationSummary>(
          stream: _gamificationService.watchCurrentUserSummary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final summary = snapshot.data;
            if (summary == null) {
              return _buildError('No gamification data is available.');
            }

            _checkForLevelUp(summary);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(summary)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  // sliver: SliverList.list(
                  //   children: [
                  //     const SizedBox(height: 16),
                  //     _buildLevelCard(summary),
                  //     const SizedBox(height: 16),
                  //     _buildStatistics(summary),
                  //     const SizedBox(height: 14),
                  //     _buildTreeCard(summary),
                  //     const SizedBox(height: 14),
                  //     _buildShortcuts(),
                  //   ],
                  // ),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: 16),
                      _buildLevelCard(summary),
                      const SizedBox(height: 16),
                      _buildStatistics(summary),

                      const SizedBox(height: 14),
                      _buildTreeCard(summary),
                      const SizedBox(height: 14),
                      _buildShortcuts(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message.replaceFirst('Bad state: ', ''), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GamificationSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================================================
        // LOGO - SAME STYLE AS HOME PAGE
        // =====================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            0,
          ),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(-7, 0),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 55,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),

        // =====================================================
        // GAMIFICATION BANNER
        // =====================================================
        SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GamificationAsset(
                path: AppAssets.gameBackground,
                fit: BoxFit.cover,
                fallback: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF7FCFF),
                        Color(0xFFB9CF91),
                      ],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Icon(
                        Icons.hiking,
                        size: 85,
                        color: Color(0xFF3F7E3B),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  18,
                  18,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${summary.userName}! 👋',
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Keep exploring, keep the planet green!',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(GamificationSummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF407F3A),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0x1FFFFFFF)),
            child: _GamificationAsset(
              path: AppAssets.gameAchievement,
              fallback: const CircleAvatar(
                backgroundColor: Color(0xFFF4F8E9),
                child: Icon(Icons.eco, color: AppColors.green, size: 36),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${summary.level}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  summary.levelTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: summary.requiredXp <= 0
                        ? 0
                        : (summary.currentXp / summary.requiredXp)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    backgroundColor: const Color(0xFFD9D9D9),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7956B5)),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${summary.currentXp}/${summary.requiredXp} XP',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(GamificationSummary summary) {
    final stats = [
      _StatData(
        AppAssets.gameAchievement,
        _formatNumber(summary.totalPoints),
        'Total Points',
        Icons.workspace_premium,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PointHistoryPage(),
          ),
        ),
      ),
      _StatData(
        AppAssets.gameStamp,
        '${summary.collectedStamps}/${summary.totalStamps}',
        'Stamp Completed',
        Icons.approval,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DigitalPassportPage(),
          ),
        ),
      ),
      _StatData(
        AppAssets.gameFlag,
        '${summary.completedChallenges}/${summary.totalChallenges}',
        'Challenges\nCompleted',
        Icons.flag,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChallengesPage()),
        ),
      ),
      _StatData(AppAssets.gameCarbon, '${summary.carbonSaved.toStringAsFixed(1)} kg', 'CO₂ Saved', Icons.cloud),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 92,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
      ),
      itemBuilder: (context, index) => _StatCard(data: stats[index]),
    );
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );
  }

  String _treeAsset(double growth) {
    final safeGrowth = growth.clamp(0.0, 1.0);

    final index = safeGrowth >= 1
        ? AppAssets.treeStages.length - 1
        : (safeGrowth * AppAssets.treeStages.length).floor();

    return AppAssets.treeStages[index];
  }

  Widget _buildTreeCard(GamificationSummary summary) {
    return Container(
      height: 182,
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        14,
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 210,
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 700,
                  ),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (
                      child,
                      animation,
                      ) =>
                      FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      ),
                  child: Image.asset(
                    _treeAsset(
                      summary.treeGrowth,
                    ),
                    key: ValueKey(
                      _treeAsset(
                        summary.treeGrowth,
                      ),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Virtual Tree',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Your tree is growing!',
                style: TextStyle(
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Text(
                'Growth',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(summary.treeGrowth * 100).round()}%',
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: 145,
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(20),
                  child:
                  LinearProgressIndicator(
                    minHeight: 10,
                    value: summary.treeGrowth,
                    backgroundColor:
                    const Color(0xFFD8DDDA),
                    valueColor:
                    const AlwaysStoppedAnimation(
                      Color(0xFF507D36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts() {
    final shortcuts = [
      _ShortcutData(
        AppAssets.gamePassport,
        'Passport',
            () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DigitalPassportPage()),
        ),
        Icons.badge,
      ),
      _ShortcutData(
        AppAssets.gameChallenge,
        'Challenges',
            () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChallengesPage()),
        ),
        Icons.track_changes,
      ),
      _ShortcutData(
        AppAssets.gameBadge,
        'My Badges',
            () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MyBadgesPage(),
          ),
        ),
        Icons.workspace_premium,
      ),
      _ShortcutData(
        AppAssets.gameLeaderboard,
        'Leaderboard',
            () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LeaderboardPage(),
          ),
        ),
        Icons.emoji_events,
      ),
    ];

    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _ShortcutCard(
            data: shortcuts[index],
          );
        },
      ),
    );
  }
}

class _StatData {
  const _StatData(
      this.asset,
      this.value,
      this.label,
      this.fallbackIcon, {
        this.onTap,
      });
  final String asset;
  final String value;
  final String label;
  final IconData fallbackIcon;
  final VoidCallback? onTap;
}

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.result});

  final LevelUpResult result;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.result.rewardPoints;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width * .82,
                margin: const EdgeInsets.only(top: 52),
                padding: const EdgeInsets.fromLTRB(22, 70, 22, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF397B35), Color(0xFF174E25)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Congratulations!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You've reached Level ${widget.result.newLevel}",
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.result.newTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Level ${widget.result.previousLevel}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Color(0xFFA9DD7B),
                            ),
                          ),
                          Text(
                            'Level ${widget.result.newLevel}',
                            style: const TextStyle(
                              color: Color(0xFFA9DD7B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reward > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: Color(0xFFE1B52C),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '+$reward Points',
                              style: const TextStyle(
                                color: Color(0xFF2E6E32),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4C9446),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Awesome!',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = 1 + (_controller.value * .08);
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF6F8E9),
                    border: Border.all(color: const Color(0xFFE3C65B), width: 7),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99E3C65B), blurRadius: 24),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Color(0xFF2E8235),
                    size: 56,
                  ),
                ),
              ),
              const Positioned(
                left: 6,
                top: 32,
                child: Icon(Icons.auto_awesome, color: Color(0xFFFFD65C)),
              ),
              const Positioned(
                right: 8,
                top: 86,
                child: Icon(Icons.auto_awesome, color: Color(0xFFA9DD7B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD5D5D5)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(color: Color(0xFFE5F4E4), shape: BoxShape.circle),
                child: _GamificationAsset(
                  path: data.asset,
                  fallback: Icon(data.fallbackIcon, size: 32, color: const Color(0xFF438342)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
                    Text(data.label, style: const TextStyle(fontSize: 11, height: 1.15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutData {
  const _ShortcutData(this.asset, this.label, this.onTap, this.fallbackIcon);
  final String asset;
  final String label;
  final VoidCallback onTap;
  final IconData fallbackIcon;
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.data});
  final _ShortcutData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 82,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD6D6D6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: _GamificationAsset(
                path: data.asset,
                fallback: Icon(data.fallbackIcon, color: AppColors.green, size: 34),
              ),
            ),
            const Spacer(),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(color: Color(0xFFE5F4E4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _GamificationAsset extends StatelessWidget {
  const _GamificationAsset({required this.path, required this.fallback, this.fit = BoxFit.contain});
  final String path;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
