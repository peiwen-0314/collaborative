import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/passport_stamp.dart';
import '../services/passport_service.dart';

class AllStampsPage extends StatelessWidget {
  const AllStampsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: const Text(
          'My Stamps',
          style: TextStyle(
            color: Color(0xFF202020),
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PassportStamp>>(
        stream: PassportService().watchAllStamps(),
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

          final stamps = snapshot.data ?? const <PassportStamp>[];
          if (stamps.isEmpty) return const _EmptyStamps();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4E7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 23,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.approval, color: AppColors.green),
                      ),
                      const SizedBox(width: 13),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stamp Collection',
                            style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                          ),
                          Text(
                            '${stamps.length} stamps collected',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF276D34),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 35),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .74,
                    crossAxisSpacing: 13,
                    mainAxisSpacing: 13,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _StampCollectionCard(stamp: stamps[index]),
                    childCount: stamps.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StampCollectionCard extends StatelessWidget {
  const _StampCollectionCard({required this.stamp});

  final PassportStamp stamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E5DE)),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox.expand(child: _stampImage()),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stamp.attractionName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.green),
              const SizedBox(width: 4),
              Text(
                _date(stamp.collectedAt),
                style: const TextStyle(fontSize: 10, color: Color(0xFF8B8B8B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stampImage() {
    Widget placeholder() => Container(
      color: const Color(0xFFEAF4E7),
      child: const Icon(Icons.account_balance, size: 48, color: AppColors.green),
    );

    Widget localFallback() {
      if (stamp.imageName.isEmpty) return placeholder();
      return Image.asset(
        'assets/images/${stamp.imageName}',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    if (stamp.stampImageUrl.isEmpty) return localFallback();
    return Image.network(
      stamp.stampImageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
      progress == null ? child : placeholder(),
      errorBuilder: (_, __, ___) => localFallback(),
    );
  }

  String _date(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _EmptyStamps extends StatelessWidget {
  const _EmptyStamps();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFFEAF4E7),
              child: Icon(Icons.approval_outlined, size: 44, color: AppColors.green),
            ),
            SizedBox(height: 16),
            Text('No stamps collected yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Visit a heritage attraction to collect your first stamp.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
