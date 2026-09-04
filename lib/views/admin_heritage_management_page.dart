import 'package:flutter/material.dart';

import '../services/admin_heritage_service.dart';
import 'admin_heritage_form_page.dart';
import 'admin_heritage_view_page.dart';
import 'admin_sidebar.dart';
import 'attraction_management_page.dart';
import 'category_management_page.dart';

class AdminCulturalHeritageManagementPage
    extends StatefulWidget {
  const AdminCulturalHeritageManagementPage({
    super.key,
  });

  @override
  State<AdminCulturalHeritageManagementPage>
  createState() =>
      _AdminCulturalHeritageManagementPageState();
}

class _AdminCulturalHeritageManagementPageState
    extends State<AdminCulturalHeritageManagementPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFF5F7F5);

  final AdminHeritageService _service =
  AdminHeritageService();

  final TextEditingController _searchController =
  TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goDashboard() {
    Navigator.pop(context);
  }

  void _goAttractionManagement() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AttractionManagementPage(),
      ),
    );
  }

  void _goCategoryManagement() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const CategoryManagementPage(),
      ),
    );
  }

  void _showNotAvailableYet(
      String moduleName,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$moduleName is not connected yet.',
        ),
      ),
    );
  }

  void _logout() {
    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AdminCulturalHeritageFormPage(),
      ),
    );
  }

  Future<void> _openView(
      AdminHeritageRecord record,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminCulturalHeritageViewPage(
              record: record,
            ),
      ),
    );
  }

  Future<void> _openEdit(
      AdminHeritageRecord record,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminCulturalHeritageFormPage(
              record: record,
            ),
      ),
    );
  }

  Future<void> _delete(
      AdminHeritageRecord record,
      ) async {
    final heritage = record.attraction;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete heritage place?',
          ),
          content: Text(
            'Delete "${heritage.name}" and all of its '
                'cultural and historical information?\n\n'
                'This heritage place will no longer appear '
                'in the Cultural & Heritage module.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteHeritagePlace(
        heritage.heritageDocumentId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${heritage.name} deleted successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Delete failed: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'culturalHeritage',

            onDashboardTap: _goDashboard,

            onAttractionTap:
            _goAttractionManagement,

            onCategoryTap:
            _goCategoryManagement,

            onCulturalHeritageTap: () {
              // Already on Cultural & Heritage Management.
            },

            onStampTap: () {
              _showNotAvailableYet(
                'Stamp Management',
              );
            },

            onReportTap: () {
              _showNotAvailableYet(
                'Reports & Booking',
              );
            },

            onLogoutTap: _logout,
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 26),

                  _buildToolbar(),

                  const SizedBox(height: 18),

                  Expanded(
                    child: StreamBuilder<
                        List<AdminHeritageRecord>>(
                      stream:
                      _service.watchHeritagePlaces(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(
                              color: mainGreen,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Unable to load cultural & heritage information.\n\n'
                                  '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final records =
                        (snapshot.data ??
                            const <
                                AdminHeritageRecord>[])
                            .where((record) {
                          if (_query.isEmpty) {
                            return true;
                          }

                          final heritage =
                              record.attraction;

                          final searchable = [
                            heritage.heritageDocumentId,
                            heritage.id,
                            heritage.name,
                            heritage.city,
                            heritage.state,
                            heritage.category,
                            heritage.heritageStatus,
                            record.status,
                          ].join(' ').toLowerCase();

                          return searchable
                              .contains(_query);
                        }).toList();

                        if (records.isEmpty) {
                          return _emptyState();
                        }

                        return _buildTable(records);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cultural & Heritage Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Manage heritage places, historical information and cultural content.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.person,
                  color: mainGreen,
                  size: 19,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Administrator',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 460),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query =
                      value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText:
                'Search heritage place, city, state...',
                prefixIcon:
                const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                    mainGreen.withOpacity(0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(
                    color: mainGreen,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 18),

        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _openAdd,
            style: FilledButton.styleFrom(
              backgroundColor: mainGreen,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Heritage Place',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
      List<AdminHeritageRecord> records,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor:
          WidgetStateProperty.all(
            const Color(0xFFF4F8F4),
          ),
          columnSpacing: 28,
          dataRowMinHeight: 74,
          dataRowMaxHeight: 88,
          columns: const [
            DataColumn(
              label: Text(
                'Heritage Place',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Last Updated',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: records.map((record) {
            final heritage = record.attraction;

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      _thumbnail(
                        heritage.imageUrl,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              heritage.name,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              heritage.heritageDocumentId,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                DataCell(
                  Text(heritage.locationText),
                ),

                DataCell(
                  _statusBadge(record.status),
                ),

                DataCell(
                  Text(
                    _formatDate(
                      record.lastUpdated,
                    ),
                  ),
                ),

                DataCell(
                  Row(
                    children: [
                      _actionButton(
                        tooltip: 'View',
                        icon:
                        Icons.visibility_outlined,
                        color: Colors.blue,
                        onTap: () =>
                            _openView(record),
                      ),
                      const SizedBox(width: 6),
                      _actionButton(
                        tooltip: 'Edit',
                        icon: Icons.edit_outlined,
                        color: mainGreen,
                        onTap: () =>
                            _openEdit(record),
                      ),
                      const SizedBox(width: 6),
                      _actionButton(
                        tooltip: 'Delete',
                        icon:
                        Icons.delete_outline,
                        color: Colors.red,
                        onTap: () =>
                            _delete(record),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _thumbnail(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 58,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.account_balance_outlined,
          color: mainGreen,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 58,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return Container(
            width: 58,
            height: 48,
            color: const Color(0xFFE8F5E9),
            child: const Icon(
              Icons.broken_image_outlined,
              color: mainGreen,
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();

    Color bg;
    Color text;

    if (normalized == 'draft') {
      bg = const Color(0xFFFFF3E0);
      text = Colors.orange.shade800;
    } else if (normalized == 'inactive') {
      bg = const Color(0xFFF0F0F0);
      text = Colors.grey.shade700;
    } else {
      bg = const Color(0xFFE8F5E9);
      text = mainGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.25),
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_outlined,
            size: 56,
            color: mainGreen,
          ),
          const SizedBox(height: 12),
          const Text(
            'No heritage place found.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add a heritage place or change your search.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openAdd,
            style: FilledButton.styleFrom(
              backgroundColor: mainGreen,
            ),
            icon: const Icon(Icons.add),
            label:
            const Text('Add Heritage Place'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year}\n'
        '${two(date.hour)}:${two(date.minute)}';
  }
}