import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/point_transaction.dart';
import '../services/gamification_service.dart';
import '../services/point_transaction_service.dart';
import '../models/gamification_summary.dart';

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  final PointTransactionService _transactionService =
  PointTransactionService();

  final GamificationService _gamificationService =
  GamificationService();

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
          'Point History',
          style: TextStyle(
            color: Color(0xFF202020),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<GamificationSummary>(
        stream: _gamificationService.watchCurrentUserSummary(),
        builder: (context, summarySnapshot) {
          if (summarySnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (summarySnapshot.hasError ||
              summarySnapshot.data == null) {
            return _buildError(
              summarySnapshot.error?.toString() ??
                  'Unable to load total points.',
            );
          }

          final summary = summarySnapshot.data!;

          return StreamBuilder<List<PointTransaction>>(
            stream: _transactionService
                .watchCurrentUserTransactions(),
            builder: (context, transactionSnapshot) {
              if (transactionSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (transactionSnapshot.hasError) {
                return _buildError(
                  transactionSnapshot.error.toString(),
                );
              }

              final transactions =
                  transactionSnapshot.data ??
                      const <PointTransaction>[];

              return ListView(
                padding:
                const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _TotalPointsCard(
                    totalPoints: summary.totalPoints,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Point Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (transactions.isEmpty)
                    const _EmptyHistory()
                  else
                    ...transactions.map(
                          (transaction) =>
                          _TransactionCard(
                            transaction: transaction,
                          ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message.replaceFirst('Bad state: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}

class _TotalPointsCard extends StatelessWidget {
  const _TotalPointsCard({
    required this.totalPoints,
  });

  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF407F3A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.stars_rounded,
            color: Color(0xFFFFD65C),
            size: 42,
          ),
          const SizedBox(height: 8),
          Text(
            _formatNumber(totalPoints),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total Points',
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

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
  });

  final PointTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F3E6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(transaction.type),
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (transaction.description.isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 3),
                    child: Text(
                      transaction.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            transaction.points >= 0
                ? '+${transaction.points}'
                : '${transaction.points}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: transaction.points >= 0
                  ? AppColors.green
                  : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'stamp':
        return Icons.approval;
      case 'challenge':
        return Icons.flag;
      case 'level_up':
        return Icons.workspace_premium;
      default:
        return Icons.stars_rounded;
    }
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

    final hour =
    date.hour.toString().padLeft(2, '0');
    final minute =
    date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 42,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.history,
            size: 46,
            color: Color(0xFFAAAAAA),
          ),
          SizedBox(height: 12),
          Text(
            'No point history yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'New rewards will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}