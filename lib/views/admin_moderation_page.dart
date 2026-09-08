import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_moderation_service.dart';
import 'admin_home_page.dart';
import 'admin_login_page.dart';
import 'admin_sidebar.dart';
import 'attraction_management_page.dart';
import 'category_management_page.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFE5E7EB);

  final AdminModerationService _service = AdminModerationService();
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'All content';
  String _statusFilter = 'All statuses';

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _service.start();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.removeListener(_refresh);
    _service.dispose();
    super.dispose();
  }

  List<AdminModerationItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return _service.items.where((item) {
      final matchesType = _typeFilter == 'All content' ||
          (_typeFilter == 'Community posts' &&
              item.type == ModerationContentType.communityPost) ||
          (_typeFilter == 'Attraction reviews' &&
              item.type == ModerationContentType.attractionReview);
      final matchesStatus = _statusFilter == 'All statuses' ||
          (_statusFilter == 'Visible' && !item.isHidden) ||
          (_statusFilter == 'Hidden' && item.isHidden);
      final matchesQuery = query.isEmpty ||
          item.authorName.toLowerCase().contains(query) ||
          item.text.toLowerCase().contains(query);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'moderation',
            onDashboardTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminHomePage()),
            ),
            onAttractionTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const AttractionManagementPage(),
              ),
            ),
            onCategoryTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const CategoryManagementPage(),
              ),
            ),
            onCulturalHeritageTap: () {},
            onModerationTap: () {},
            onStampTap: () {},
            onReportTap: () {},
            onLogoutTap: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const AdminLoginPage(),
                ),
                    (route) => false,
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 22),
                      _statistics(),
                      const SizedBox(height: 20),
                      _filters(),
                      _contentTable(),
                    ],
                  ),
                ),
                if (_service.isProcessing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: mainGreen,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Moderation',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Review and manage user-submitted community posts and attraction reviews.',
          style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
        ),
      ],
    );
  }

  Widget _statistics() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _stat(Icons.forum_outlined, 'Community Posts',
              '${_service.communityPosts}', Colors.blue),
          _divider(),
          _stat(Icons.rate_review_outlined, 'Attraction Reviews',
              '${_service.attractionReviews}', Colors.purple),
          _divider(),
          _stat(Icons.visibility_outlined, 'Visible',
              '${_service.visibleItems}', mainGreen),
          _divider(),
          _stat(Icons.visibility_off_outlined, 'Hidden',
              '${_service.hiddenItems}', Colors.orange),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 65,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: borderColor,
      );

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by author or content...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borderColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _dropdown(
            value: _typeFilter,
            values: const [
              'All content',
              'Community posts',
              'Attraction reviews',
            ],
            onChanged: (value) => setState(() => _typeFilter = value!),
          ),
          const SizedBox(width: 12),
          _dropdown(
            value: _statusFilter,
            values: const ['All statuses', 'Visible', 'Hidden'],
            onChanged: (value) => setState(() => _statusFilter = value!),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 185,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: mainGreen, width: 1.5),
          ),
        ),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _contentTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border.all(color: borderColor),
      ),
      child: _service.isLoading
          ? const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator(color: mainGreen)),
            )
          : _service.errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(45),
                  child: Center(child: Text(_service.errorMessage!)),
                )
              : _filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(45),
                      child: Center(child: Text('No matching content found.')),
                    )
                  : Column(
                      children: [
                        _tableHeader(),
                        ..._filteredItems.map(_contentRow),
                      ],
                    ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      color: const Color(0xFFF9FAFB),
      child: const Row(
        children: [
          SizedBox(width: 150, child: Text('TYPE')),
          SizedBox(width: 150, child: Text('AUTHOR')),
          Expanded(child: Text('CONTENT')),
          SizedBox(width: 100, child: Text('STATUS')),
          SizedBox(width: 160, child: Text('ACTIONS')),
        ],
      ),
    );
  }

  Widget _contentRow(AdminModerationItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                Icon(
                  item.type == ModerationContentType.communityPost
                      ? Icons.forum_outlined
                      : Icons.rate_review_outlined,
                  size: 18,
                  color: mainGreen,
                ),
                const SizedBox(width: 7),
                Flexible(child: Text(item.typeLabel)),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              item.authorName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (item.rating != null)
                    Text(
                      '${item.rating}/5 rating',
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 100, child: _statusBadge(item)),
          SizedBox(
            width: 160,
            child: Row(
              children: [
                IconButton(
                  tooltip: item.isHidden ? 'Restore' : 'Hide',
                  onPressed: _service.isProcessing
                      ? null
                      : () => _changeVisibility(item),
                  icon: Icon(
                    item.isHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: item.isHidden ? mainGreen : Colors.orange,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete permanently',
                  onPressed: _service.isProcessing
                      ? null
                      : () => _confirmDelete(item),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(AdminModerationItem item) {
    final color = item.isHidden ? Colors.orange : mainGreen;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.isHidden ? 'Hidden' : 'Visible',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _changeVisibility(AdminModerationItem item) async {
    try {
      await _service.setHidden(item, !item.isHidden);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.isHidden ? 'Content restored.' : 'Content hidden.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update this content.')),
      );
    }
  }

  Future<void> _confirmDelete(AdminModerationItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.typeLabel.toLowerCase()}?'),
        content: const Text(
          'This content will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this content.')),
      );
    }
  }
}
