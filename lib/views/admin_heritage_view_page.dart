/*import 'package:flutter/material.dart';

import '../services/admin_heritage_service.dart';
import 'admin_heritage_form_page.dart';

class AdminCulturalHeritageViewPage
    extends StatelessWidget {
  const AdminCulturalHeritageViewPage({
    super.key,
    required this.record,
  });

  final AdminHeritageRecord record;

  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color background =
  Color(0xFFF5F7F5);

  @override
  Widget build(BuildContext context) {
    final heritage = record.attraction;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'View Cultural & Heritage Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding:
            const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: mainGreen,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminCulturalHeritageFormPage(
                          record: record,
                        ),
                  ),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon:
              const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 1000,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _hero(heritage),

                const SizedBox(height: 22),

                _section(
                  title: 'Basic Information',
                  icon:
                  Icons.info_outline_rounded,
                  children: [
                    _grid([
                      _item(
                        'Attraction ID',
                        heritage.id,
                      ),
                      _item(
                        'Heritage ID',
                        heritage.heritageDocumentId,
                      ),
                      _item(
                        'Status',
                        record.status,
                      ),
                      _item(
                        'Category',
                        heritage.category,
                      ),
                      _item(
                        'Location',
                        heritage.locationText,
                      ),
                      _item(
                        'Latitude',
                        heritage.latitude
                            .toString(),
                      ),
                      _item(
                        'Longitude',
                        heritage.longitude
                            .toString(),
                      ),
                      _item(
                        'Opening Hours',
                        heritage.openingHours,
                      ),
                      _item(
                        'Estimated Visit',
                        heritage.recommendedTime,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    _longItem(
                      'Short Description',
                      heritage.shortDescription,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _section(
                  title: 'Historical Information',
                  icon:
                  Icons.menu_book_outlined,
                  children: [
                    _grid([
                      _item(
                        'Year Built',
                        heritage.yearBuilt,
                      ),
                      _item(
                        'Architectural Style',
                        heritage.architecturalStyle,
                      ),
                      _item(
                        'Heritage Status',
                        heritage.heritageStatus,
                      ),
                      _item(
                        'Best Time',
                        heritage.bestTime,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    _longItem(
                      'Historical Background',
                      heritage.history,
                    ),

                    const SizedBox(height: 14),

                    _longItem(
                      'Cultural Significance',
                      heritage.culturalSignificance,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _section(
                  title:
                  'Visitor & Conservation Information',
                  icon: Icons.eco_outlined,
                  children: [
                    _listItem(
                      'Conservation Guidelines',
                      heritage
                          .conservationGuidelines,
                    ),
                    _listItem(
                      'Visitor Etiquette',
                      heritage
                          .visitorEtiquetteItems,
                    ),
                    _listItem(
                      'Dress Code',
                      heritage.dressCode,
                    ),
                    _listItem(
                      'Photography Restrictions',
                      heritage
                          .photographyRestrictions,
                    ),
                    _listItem(
                      'Preservation Practices',
                      heritage
                          .preservationPractices,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _section(
                  title:
                  'Multilingual Audio Guide Content',
                  icon:
                  Icons.headphones_outlined,
                  children: [
                    _longItem(
                      'English',
                      heritage.audioEnglish,
                    ),

                    const SizedBox(height: 14),

                    _longItem(
                      'Bahasa Melayu',
                      heritage.audioMalay,
                    ),

                    const SizedBox(height: 14),

                    _longItem(
                      '中文',
                      heritage.audioChinese,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(dynamic heritage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
            BorderRadius.circular(12),
            child:
            heritage.imageUrl
                .toString()
                .trim()
                .isEmpty
                ? Container(
              width: 180,
              height: 120,
              color: const Color(
                0xFFE8F5E9,
              ),
              child: const Icon(
                Icons
                    .account_balance_outlined,
                color: mainGreen,
                size: 48,
              ),
            )
                : Image.network(
              heritage.imageUrl,
              width: 180,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  width: 180,
                  height: 120,
                  color:
                  const Color(
                    0xFFE8F5E9,
                  ),
                  child: const Icon(
                    Icons
                        .broken_image_outlined,
                    color: mainGreen,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 22),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  heritage.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: mainGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        heritage.locationText,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  heritage.shortDescription,
                  style: TextStyle(
                    color:
                    Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFE8F5E9),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: mainGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ...children,
        ],
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }

  Widget _item(
      String label,
      String value,
      ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE1E8E1),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: mainGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _longItem(
      String label,
      String value,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE1E8E1),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: mainGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem(
      String label,
      List<String> values,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF8),
          borderRadius:
          BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE1E8E1),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: mainGreen,
                fontSize: 12,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            if (values.isEmpty)
              const Text('—')
            else
              ...values.map(
                    (value) => Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom: 5,
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                        EdgeInsets.only(
                          top: 5,
                        ),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: mainGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(value),
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
}*/
