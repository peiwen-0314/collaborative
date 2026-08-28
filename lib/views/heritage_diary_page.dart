import 'package:flutter/material.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_storage_service.dart';
import 'heritage_detail_page.dart';

class HeritageDiaryPage extends StatefulWidget {
  const HeritageDiaryPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<HeritageDiaryPage> createState() => _HeritageDiaryPageState();
}

class _HeritageDiaryPageState extends State<HeritageDiaryPage> {
  static const Color green = Color(0xFF2E7D32);

  final HeritageStorageService _storage = HeritageStorageService();
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  List<HeritageAttraction> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _storage.loadDiary();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _remove(HeritageAttraction attraction) async {
    await _storage.removeFromDiary(attraction.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = _items.where((item) {
      return query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.state.toLowerCase().contains(query);
    }).toList();

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!widget.embedded)
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Travel Diary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your Journey. Your Story.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    backgroundColor: Color(0xFFDDF4D8),
                    child: Icon(Icons.auto_stories_outlined, color: green),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search your saved heritage places...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFE7E7E7),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              color: Colors.white54,
                              size: 54,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No saved heritage places yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: green,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(9),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  item.imageAsset,
                                  width: 58,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${item.state}, Malaysia\n${item.category}',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                onPressed: () => _remove(item),
                                icon: const Icon(Icons.bookmark_remove_outlined),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        HeritageDetailPage(attraction: item),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (widget.embedded) return ColoredBox(color: Colors.black, child: content);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: content),
    );
  }
}
