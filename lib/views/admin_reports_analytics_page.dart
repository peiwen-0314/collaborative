import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:collaborative_asg/views/attraction_management_page.dart';
import 'package:collaborative_asg/views/category_management_page.dart';

import 'admin_challenge_management_page.dart';
import 'admin_home_page.dart';
import 'admin_login_page.dart';
import 'admin_moderation_page.dart';
import 'admin_sidebar.dart';
import 'admin_stamp_management_page.dart';

class AdminReportsAnalyticsPage extends StatefulWidget {
  const AdminReportsAnalyticsPage({super.key});

  @override
  State<AdminReportsAnalyticsPage> createState() =>
      _AdminReportsAnalyticsPageState();
}

class _AdminReportsAnalyticsPageState
    extends State<AdminReportsAnalyticsPage> {
  static const Color mainGreen = Color(0xFF2E7D32);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String _periodType = 'monthly';

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  late Future<_GamificationReportData> _reportFuture;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  // ============================================================
  // PERIOD
  // ============================================================

  DateTime? get _periodStart {
    if (_periodType == 'all') {
      return null;
    }

    if (_periodType == 'yearly') {
      return DateTime(
        _selectedYear,
        1,
        1,
      );
    }

    return DateTime(
      _selectedYear,
      _selectedMonth,
      1,
    );
  }

  DateTime? get _periodEnd {
    if (_periodType == 'all') {
      return null;
    }

    if (_periodType == 'yearly') {
      return DateTime(
        _selectedYear + 1,
        1,
        1,
      );
    }

    if (_selectedMonth == 12) {
      return DateTime(
        _selectedYear + 1,
        1,
        1,
      );
    }

    return DateTime(
      _selectedYear,
      _selectedMonth + 1,
      1,
    );
  }

  String get _periodLabel {
    if (_periodType == 'all') {
      return 'All Time';
    }

    if (_periodType == 'yearly') {
      return '$_selectedYear';
    }

    return '${_monthName(_selectedMonth)} $_selectedYear';
  }

  // ============================================================
  // COLLECTION GROUP QUERY
  // ============================================================

  Future<QuerySnapshot<Map<String, dynamic>>> _queryGroup(
      String groupName,
      String timestampField,
      ) async {
    Query<Map<String, dynamic>> query =
    _firestore.collectionGroup(groupName);

    final start = _periodStart;
    final end = _periodEnd;

    if (start != null && end != null) {
      query = query
          .where(
        timestampField,
        isGreaterThanOrEqualTo:
        Timestamp.fromDate(start),
      )
          .where(
        timestampField,
        isLessThan:
        Timestamp.fromDate(end),
      );
    }

    return query.get();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<_GamificationReportData> _loadReport() async {
    // ----------------------------------------------------------
    // MASTER ATTRACTION NAME MAP
    // ----------------------------------------------------------

    final attractionSnapshot =
    await _firestore
        .collection('attractions')
        .get();

    final attractionNames =
    <String, String>{};

    for (final doc in attractionSnapshot.docs) {
      final name =
      (doc.data()['name'] ?? '')
          .toString()
          .trim();

      if (name.isNotEmpty) {
        attractionNames[doc.id] = name;
      }
    }

    // ----------------------------------------------------------
    // LOAD ACTIVITY
    // ----------------------------------------------------------

    final results = await Future.wait([
      _queryGroup(
        'stamps',
        'collectedAt',
      ),
      _queryGroup(
        'challengeProgress',
        'completedAt',
      ),
      _queryGroup(
        'pointTransactions',
        'createdAt',
      ),
      _queryGroup(
        'carbonSavings',
        'createdAt',
      ),
    ]);

    final stampSnapshot = results[0];
    final challengeProgressSnapshot =
    results[1];
    final pointSnapshot = results[2];
    final carbonSnapshot = results[3];

    // ----------------------------------------------------------
    // PARTICIPANTS
    // ----------------------------------------------------------

    final activeUserIds = <String>{};

    void collectUserId(
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
        ) {
      final userDoc =
          doc.reference.parent.parent;

      if (userDoc != null &&
          userDoc.id.isNotEmpty) {
        activeUserIds.add(userDoc.id);
      }
    }

    for (final doc in stampSnapshot.docs) {
      collectUserId(doc);
    }

    for (final doc
    in challengeProgressSnapshot.docs) {
      collectUserId(doc);
    }

    for (final doc in pointSnapshot.docs) {
      collectUserId(doc);
    }

    for (final doc in carbonSnapshot.docs) {
      collectUserId(doc);
    }

    int totalParticipants;

    if (_periodType == 'all') {
      final gamificationSnapshot =
      await _firestore
          .collection('gamification')
          .get();

      totalParticipants =
          gamificationSnapshot.docs.length;
    } else {
      totalParticipants =
          activeUserIds.length;
    }

    // ----------------------------------------------------------
    // STAMPS
    // ----------------------------------------------------------

    final totalStamps =
        stampSnapshot.docs.length;

    final stampCounts =
    <String, _StampCount>{};

    for (final doc in stampSnapshot.docs) {
      final data = doc.data();

      final attractionId =
      (data['attractionId'] ?? '')
          .toString()
          .trim();

      if (attractionId.isEmpty) {
        continue;
      }

      final storedName =
      (data['attractionName'] ?? '')
          .toString()
          .trim();

      final resolvedName =
      storedName.isNotEmpty
          ? storedName
          : attractionNames[
      attractionId] ??
          'Unknown Attraction';

      final existing =
      stampCounts[attractionId];

      if (existing == null) {
        stampCounts[attractionId] =
            _StampCount(
              attractionId:
              attractionId,
              attractionName:
              resolvedName,
              count: 1,
            );
      } else {
        stampCounts[attractionId] =
            existing.copyWith(
              count:
              existing.count + 1,
            );
      }
    }

    final topStamps =
    stampCounts.values.toList()
      ..sort(
            (a, b) =>
            b.count.compareTo(
              a.count,
            ),
      );

    // ----------------------------------------------------------
    // CHALLENGES
    // ----------------------------------------------------------

    final completedProgress =
    challengeProgressSnapshot.docs
        .where(
          (doc) =>
      doc.data()['rewarded'] ==
          true,
    ).toList();

    final totalChallengesCompleted =
        completedProgress.length;

    final challengeCounts =
    <String, int>{};

    for (final doc
    in completedProgress) {
      final challengeId =
      (doc.data()['challengeId'] ?? '')
          .toString()
          .trim();

      if (challengeId.isEmpty) {
        continue;
      }

      challengeCounts.update(
        challengeId,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final challengeSnapshot =
    await _firestore
        .collection('challenges')
        .get();

    final challengeTitles =
    <String, String>{};

    for (final doc in challengeSnapshot.docs) {
      challengeTitles[doc.id] =
          (doc.data()['title'] ??
              'Unknown Challenge')
              .toString()
              .trim();
    }

    final topChallenges =
    challengeCounts.entries
        .map(
          (entry) =>
          _ChallengeCount(
            challengeId:
            entry.key,
            challengeTitle:
            challengeTitles[
            entry.key] ??
                'Unknown Challenge',
            count:
            entry.value,
          ),
    )
        .toList()
      ..sort(
            (a, b) =>
            b.count.compareTo(
              a.count,
            ),
      );

    // ----------------------------------------------------------
    // POINTS
    // ----------------------------------------------------------

    int totalPointsAwarded = 0;

    for (final doc in pointSnapshot.docs) {
      final points =
          (doc.data()['points'] as num?)
              ?.toInt() ??
              0;

      if (points > 0) {
        totalPointsAwarded +=
            points;
      }
    }

    // ----------------------------------------------------------
    // CARBON
    // ----------------------------------------------------------

    double totalCarbonSaved = 0;

    for (final doc
    in carbonSnapshot.docs) {
      totalCarbonSaved +=
          (doc.data()['carbonSavedKg']
          as num?)
              ?.toDouble() ??
              0;
    }

    // ----------------------------------------------------------
    // AVERAGES
    // ----------------------------------------------------------

    final averageStamps =
    totalParticipants == 0
        ? 0.0
        : totalStamps /
        totalParticipants;

    final averageChallenges =
    totalParticipants == 0
        ? 0.0
        : totalChallengesCompleted /
        totalParticipants;

    // ----------------------------------------------------------
    // TREND
    // ----------------------------------------------------------

    final trend =
    _buildTrend(
      stampSnapshot.docs,
      completedProgress,
    );

    return _GamificationReportData(
      totalParticipants:
      totalParticipants,
      totalStamps:
      totalStamps,
      totalChallengesCompleted:
      totalChallengesCompleted,
      totalPointsAwarded:
      totalPointsAwarded,
      totalCarbonSaved:
      totalCarbonSaved,
      averageStampsPerUser:
      averageStamps,
      averageChallengesPerUser:
      averageChallenges,
      topStamps:
      topStamps.take(5).toList(),
      topChallenges:
      topChallenges
          .take(5)
          .toList(),
      trend:
      trend,
    );
  }

  // ============================================================
  // BUILD TREND
  // ============================================================

  List<_TrendPoint> _buildTrend(
      List<QueryDocumentSnapshot<
          Map<String, dynamic>>>
      stampDocs,
      List<QueryDocumentSnapshot<
          Map<String, dynamic>>>
      challengeDocs,
      ) {
    final counts =
    <String, _MutableTrend>{};

    void addEvent({
      required DateTime date,
      required bool isStamp,
    }) {
      late String key;
      late String label;

      if (_periodType == 'monthly') {
        key =
        '${date.year}-${date.month}-${date.day}';

        label =
        '${date.day}';
      } else if (_periodType ==
          'yearly') {
        key =
        '${date.year}-${date.month}';

        label =
            _shortMonthName(
              date.month,
            );
      } else {
        key =
        '${date.year}';

        label =
        '${date.year}';
      }

      final bucket =
      counts.putIfAbsent(
        key,
            () => _MutableTrend(
          label: label,
          sortDate: date,
        ),
      );

      if (isStamp) {
        bucket.stamps++;
      } else {
        bucket.challenges++;
      }
    }

    for (final doc in stampDocs) {
      final timestamp =
      doc.data()['collectedAt'];

      if (timestamp is Timestamp) {
        addEvent(
          date:
          timestamp.toDate(),
          isStamp:
          true,
        );
      }
    }

    for (final doc in challengeDocs) {
      final timestamp =
      doc.data()['completedAt'];

      if (timestamp is Timestamp) {
        addEvent(
          date:
          timestamp.toDate(),
          isStamp:
          false,
        );
      }
    }

    // Fill empty periods for selected month/year.
    if (_periodType == 'monthly') {
      final days =
          DateTime(
            _selectedYear,
            _selectedMonth + 1,
            0,
          ).day;

      for (int day = 1;
      day <= days;
      day++) {
        final date =
        DateTime(
          _selectedYear,
          _selectedMonth,
          day,
        );

        final key =
            '${date.year}-${date.month}-${date.day}';

        counts.putIfAbsent(
          key,
              () => _MutableTrend(
            label:
            '$day',
            sortDate:
            date,
          ),
        );
      }
    }

    if (_periodType == 'yearly') {
      for (int month = 1;
      month <= 12;
      month++) {
        final date =
        DateTime(
          _selectedYear,
          month,
          1,
        );

        final key =
            '${date.year}-${date.month}';

        counts.putIfAbsent(
          key,
              () => _MutableTrend(
            label:
            _shortMonthName(
              month,
            ),
            sortDate:
            date,
          ),
        );
      }
    }

    final sorted =
    counts.values.toList()
      ..sort(
            (a, b) =>
            a.sortDate.compareTo(
              b.sortDate,
            ),
      );

    return sorted
        .map(
          (item) =>
          _TrendPoint(
            label:
            item.label,
            stamps:
            item.stamps,
            challenges:
            item.challenges,
          ),
    )
        .toList();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  void _refreshReport() {
    setState(() {
      _reportFuture =
          _loadReport();
    });
  }

  // ============================================================
  // CHANGE FILTER
  // ============================================================

  void _reloadAfterFilter() {
    setState(() {
      _reportFuture =
          _loadReport();
    });
  }

  // ============================================================
  // EXPORT PDF
  // ============================================================

  Future<void> _exportPdf(
      _GamificationReportData data,
      ) async {
    try {
      final pdf =
      pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
          PdfPageFormat.a4,
          margin:
          const pw.EdgeInsets.all(
            32,
          ),
          build: (
              pdfContext,
              ) {
            return [
              pw.Text(
                'EcoTravel Gamification Report',
                style:
                pw.TextStyle(
                  fontSize: 22,
                  fontWeight:
                  pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: 4,
              ),

              pw.Text(
                'Reporting Period: $_periodLabel',
                style:
                const pw.TextStyle(
                  fontSize: 11,
                  color:
                  PdfColors.grey700,
                ),
              ),

              pw.SizedBox(
                height: 20,
              ),

              pw.Text(
                'Performance Summary',
                style:
                pw.TextStyle(
                  fontSize: 15,
                  fontWeight:
                  pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: 8,
              ),

              pw.TableHelper.fromTextArray(
                headers: const [
                  'Metric',
                  'Value',
                ],
                data: [
                  [
                    'Active Participants',
                    '${data.totalParticipants}',
                  ],
                  [
                    'Stamps Collected',
                    '${data.totalStamps}',
                  ],
                  [
                    'Challenges Completed',
                    '${data.totalChallengesCompleted}',
                  ],
                  [
                    'Points Awarded',
                    '${data.totalPointsAwarded}',
                  ],
                  [
                    'CO2 Saved',
                    '${data.totalCarbonSaved.toStringAsFixed(2)} kg',
                  ],
                  [
                    'Average Stamps / User',
                    data.averageStampsPerUser
                        .toStringAsFixed(
                      1,
                    ),
                  ],
                  [
                    'Average Challenges / User',
                    data.averageChallengesPerUser
                        .toStringAsFixed(
                      1,
                    ),
                  ],
                ],
                headerStyle:
                pw.TextStyle(
                  fontWeight:
                  pw.FontWeight.bold,
                ),
                headerDecoration:
                const pw.BoxDecoration(
                  color:
                  PdfColors.grey300,
                ),
                cellPadding:
                const pw.EdgeInsets.all(
                  7,
                ),
              ),

              pw.SizedBox(
                height: 24,
              ),

              pw.Text(
                'Top Collected Stamps',
                style:
                pw.TextStyle(
                  fontSize: 15,
                  fontWeight:
                  pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: 8,
              ),

              if (data.topStamps.isEmpty)
                pw.Text(
                  'No stamp collection data available for this period.',
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Rank',
                    'Attraction',
                    'Collected',
                  ],
                  data:
                  data.topStamps
                      .asMap()
                      .entries
                      .map(
                        (entry) {
                      return [
                        '${entry.key + 1}',
                        entry.value
                            .attractionName,
                        '${entry.value.count}',
                      ];
                    },
                  ).toList(),
                ),

              pw.SizedBox(
                height: 24,
              ),

              pw.Text(
                'Top Completed Challenges',
                style:
                pw.TextStyle(
                  fontSize: 15,
                  fontWeight:
                  pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: 8,
              ),

              if (data
                  .topChallenges.isEmpty)
                pw.Text(
                  'No challenge completion data available for this period.',
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Rank',
                    'Challenge',
                    'Completed',
                  ],
                  data:
                  data.topChallenges
                      .asMap()
                      .entries
                      .map(
                        (entry) {
                      return [
                        '${entry.key + 1}',
                        entry.value
                            .challengeTitle,
                        '${entry.value.count}',
                      ];
                    },
                  ).toList(),
                ),

              pw.SizedBox(
                height: 26,
              ),

              pw.Divider(),

              pw.Text(
                'Generated by EcoTravel Admin Portal',
                style:
                const pw.TextStyle(
                  fontSize: 9,
                  color:
                  PdfColors.grey600,
                ),
              ),
            ];
          },
        ),
      );

      final Uint8List bytes =
      await pdf.save();

      final safePeriod =
      _periodLabel
          .replaceAll(
        ' ',
        '_',
      )
          .replaceAll(
        '/',
        '-',
      );

      final savedUri =
      await fp.FilePicker.saveFile(
        fileName:
        'EcoTravel_Report_$safePeriod.pdf',
        bytes:
        bytes,
        mimeType:
        'application/pdf',
        type:
        fp.FileType.custom,
        allowedExtensions:
        const [
          'pdf',
        ],
        dialogTitle:
        'Save EcoTravel Report',
      );

      if (!mounted) return;

      if (savedUri != null) {
        _showMessage(
          'PDF report exported successfully.',
        );
      }
    } catch (e) {
      _showMessage(
        'Unable to export PDF: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
        ),
      );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AdminLoginPage(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF4F6F4),
      body: Row(
        children: [
          // ====================================================
          // SIDEBAR
          // ====================================================

          AdminSidebar(
            selectedPage:
            'report',

            onDashboardTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminHomePage(),
                ),
              );
            },

            onAttractionTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AttractionManagementPage(),
                ),
              );
            },

            onCategoryTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const CategoryManagementPage(),
                ),
              );
            },

            onCulturalHeritageTap:
                () {},

            onModerationTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminModerationPage(),
                ),
              );
            },

            onStampTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminStampManagementPage(),
                ),
              );
            },

            onChallengeTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminChallengeManagementPage(),
                ),
              );
            },

            onReportTap: () {},

            onLogoutTap:
            _logout,
          ),

          // ====================================================
          // MAIN CONTENT
          // ====================================================

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(
                28,
                25,
                28,
                28,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  // ============================================
                  // HEADER
                  // ============================================

                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              'Reports & Analytics',
                              style:
                              TextStyle(
                                fontSize:
                                30,
                                fontWeight:
                                FontWeight
                                    .w700,
                                color:
                                Color(
                                  0xFF1E241E,
                                ),
                              ),
                            ),

                            SizedBox(
                              height:
                              4,
                            ),

                            Text(
                              'Monitor visitor engagement and gamification performance.',
                              style:
                              TextStyle(
                                fontSize:
                                14,
                                color:
                                Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      OutlinedButton.icon(
                        onPressed: () {
                          final future =
                              _reportFuture;

                          future.then(
                                (data) {
                              if (mounted) {
                                _exportPdf(
                                  data,
                                );
                              }
                            },
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .picture_as_pdf_outlined,
                        ),
                        label:
                        const Text(
                          'Export PDF',
                        ),
                        style:
                        OutlinedButton
                            .styleFrom(
                          foregroundColor:
                          mainGreen,
                          side:
                          BorderSide(
                            color:
                            mainGreen.withOpacity(
                              0.5,
                            ),
                          ),
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal:
                            18,
                            vertical:
                            15,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                        10,
                      ),

                      ElevatedButton.icon(
                        onPressed:
                        _refreshReport,
                        icon:
                        const Icon(
                          Icons.refresh,
                        ),
                        label:
                        const Text(
                          'Refresh',
                        ),
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          mainGreen,
                          foregroundColor:
                          Colors.white,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal:
                            18,
                            vertical:
                            15,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    20,
                  ),

                  // ============================================
                  // FILTER BAR
                  // ============================================

                  _filterBar(),

                  const SizedBox(
                    height:
                    18,
                  ),

                  // ============================================
                  // DATA
                  // ============================================

                  Expanded(
                    child: FutureBuilder<
                        _GamificationReportData>(
                      future:
                      _reportFuture,
                      builder: (
                          context,
                          snapshot,
                          ) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot
                            .hasError) {
                          return _errorView(
                            snapshot.error,
                          );
                        }

                        final data =
                        snapshot.data!;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              // =================================
                              // FIVE KPI CARDS
                              // =================================

                              LayoutBuilder(
                                builder: (
                                    context,
                                    constraints,
                                    ) {
                                  final width =
                                      (constraints.maxWidth -
                                          48) /
                                          5;

                                  return Wrap(
                                    spacing:
                                    12,
                                    runSpacing:
                                    12,
                                    children: [
                                      _summaryCard(
                                        width:
                                        width,
                                        icon:
                                        Icons
                                            .people_alt_outlined,
                                        title:
                                        'Participants',
                                        value:
                                        '${data.totalParticipants}',
                                        subtitle:
                                        _periodType ==
                                            'all'
                                            ? 'Gamification users'
                                            : 'Active in period',
                                      ),

                                      _summaryCard(
                                        width:
                                        width,
                                        icon:
                                        Icons
                                            .card_giftcard_outlined,
                                        title:
                                        'Stamps',
                                        value:
                                        '${data.totalStamps}',
                                        subtitle:
                                        'Collected',
                                      ),

                                      _summaryCard(
                                        width:
                                        width,
                                        icon:
                                        Icons
                                            .emoji_events_outlined,
                                        title:
                                        'Challenges',
                                        value:
                                        '${data.totalChallengesCompleted}',
                                        subtitle:
                                        'Completed',
                                      ),

                                      _summaryCard(
                                        width:
                                        width,
                                        icon:
                                        Icons
                                            .stars_outlined,
                                        title:
                                        'Points',
                                        value:
                                        '${data.totalPointsAwarded}',
                                        subtitle:
                                        'Awarded',
                                      ),

                                      _summaryCard(
                                        width:
                                        width,
                                        icon:
                                        Icons
                                            .eco_outlined,
                                        title:
                                        'CO₂ Saved',
                                        value:
                                        '${data.totalCarbonSaved.toStringAsFixed(2)} kg',
                                        subtitle:
                                        'Estimated saving',
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(
                                height:
                                18,
                              ),

                              // =================================
                              // ENGAGEMENT TREND
                              // =================================

                              _chartPanel(
                                title:
                                'Visitor Engagement Trend',
                                subtitle:
                                _trendSubtitle(),
                                child:
                                SizedBox(
                                  height:
                                  280,
                                  child:
                                  _engagementTrendChart(
                                    data.trend,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height:
                                18,
                              ),

                              // =================================
                              // TWO BAR CHARTS
                              // =================================

                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Expanded(
                                    child:
                                    _chartPanel(
                                      title:
                                      'Top Collected Stamps',
                                      subtitle:
                                      'Most collected stamps during $_periodLabel',
                                      child:
                                      SizedBox(
                                        height:
                                        280,
                                        child:
                                        _topStampChart(
                                          data.topStamps,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    width:
                                    18,
                                  ),

                                  Expanded(
                                    child:
                                    _chartPanel(
                                      title:
                                      'Challenge Performance',
                                      subtitle:
                                      'Most completed challenges during $_periodLabel',
                                      child:
                                      SizedBox(
                                        height:
                                        280,
                                        child:
                                        _challengeChart(
                                          data.topChallenges,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height:
                                18,
                              ),

                              // =================================
                              // DETAIL SUMMARY
                              // =================================

                              Row(
                                children: [
                                  Expanded(
                                    child:
                                    _detailCard(
                                      icon:
                                      Icons
                                          .collections_bookmark_outlined,
                                      title:
                                      'Average Stamps per User',
                                      value:
                                      data.averageStampsPerUser
                                          .toStringAsFixed(
                                        1,
                                      ),
                                      description:
                                      'Average number of heritage stamps collected by each active participant.',
                                    ),
                                  ),

                                  const SizedBox(
                                    width:
                                    16,
                                  ),

                                  Expanded(
                                    child:
                                    _detailCard(
                                      icon:
                                      Icons
                                          .task_alt_outlined,
                                      title:
                                      'Average Challenges per User',
                                      value:
                                      data.averageChallengesPerUser
                                          .toStringAsFixed(
                                        1,
                                      ),
                                      description:
                                      'Average number of challenges completed by each active participant.',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height:
                                30,
                              ),
                            ],
                          ),
                        );
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

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _filterBar() {
    final years =
    List.generate(
      5,
          (index) =>
      DateTime.now().year -
          index,
    );

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        18,
        vertical:
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons
                .calendar_month_outlined,
            color:
            mainGreen,
          ),

          const SizedBox(
            width:
            10,
          ),

          const Text(
            'Reporting Period',
            style:
            TextStyle(
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            width:
            20,
          ),

          SizedBox(
            width:
            130,
            child:
            DropdownButtonFormField<
                String>(
              initialValue:
              _periodType,
              decoration:
              _compactDropdownDecoration(),
              items:
              const [
                DropdownMenuItem(
                  value:
                  'monthly',
                  child:
                  Text(
                    'Monthly',
                  ),
                ),
                DropdownMenuItem(
                  value:
                  'yearly',
                  child:
                  Text(
                    'Yearly',
                  ),
                ),
                DropdownMenuItem(
                  value:
                  'all',
                  child:
                  Text(
                    'All Time',
                  ),
                ),
              ],
              onChanged:
                  (value) {
                if (value == null) {
                  return;
                }

                _periodType =
                    value;

                _reloadAfterFilter();
              },
            ),
          ),

          if (_periodType ==
              'monthly') ...[
            const SizedBox(
              width:
              12,
            ),

            SizedBox(
              width:
              145,
              child:
              DropdownButtonFormField<
                  int>(
                initialValue:
                _selectedMonth,
                decoration:
                _compactDropdownDecoration(),
                items:
                List.generate(
                  12,
                      (index) {
                    final month =
                        index + 1;

                    return DropdownMenuItem(
                      value:
                      month,
                      child:
                      Text(
                        _monthName(
                          month,
                        ),
                      ),
                    );
                  },
                ),
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  _selectedMonth =
                      value;

                  _reloadAfterFilter();
                },
              ),
            ),
          ],

          if (_periodType !=
              'all') ...[
            const SizedBox(
              width:
              12,
            ),

            SizedBox(
              width:
              105,
              child:
              DropdownButtonFormField<
                  int>(
                initialValue:
                _selectedYear,
                decoration:
                _compactDropdownDecoration(),
                items:
                years
                    .map(
                      (year) =>
                      DropdownMenuItem(
                        value:
                        year,
                        child:
                        Text(
                          '$year',
                        ),
                      ),
                )
                    .toList(),
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  _selectedYear =
                      value;

                  _reloadAfterFilter();
                },
              ),
            ),
          ],

          const Spacer(),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal:
              14,
              vertical:
              9,
            ),
            decoration:
            BoxDecoration(
              color:
              mainGreen.withOpacity(
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                8,
              ),
            ),
            child: Text(
              _periodLabel,
              style:
              const TextStyle(
                color:
                mainGreen,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ENGAGEMENT LINE CHART
  // ============================================================

  Widget _engagementTrendChart(
      List<_TrendPoint> data,
      ) {
    if (data.isEmpty) {
      return _emptyChart(
        'No engagement data for this period.',
      );
    }

    double maxY = 1;

    for (final item in data) {
      maxY = math.max(
        maxY,
        math.max(
          item.stamps.toDouble(),
          item.challenges.toDouble(),
        ),
      );
    }

    maxY += 1;

    return LineChart(
      LineChartData(
        minY:
        0,
        maxY:
        maxY,
        borderData:
        FlBorderData(
          show:
          false,
        ),
        gridData:
        FlGridData(
          show:
          true,
          drawVerticalLine:
          false,
          getDrawingHorizontalLine:
              (value) =>
              FlLine(
                color:
                Colors.grey.shade200,
                strokeWidth:
                1,
              ),
        ),
        titlesData:
        FlTitlesData(
          topTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          rightTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          leftTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              32,
            ),
          ),
          bottomTitles:
          AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              28,
              interval:
              _trendInterval(
                data.length,
              ),
              getTitlesWidget:
                  (
                  value,
                  meta,
                  ) {
                final index =
                value.toInt();

                if (index < 0 ||
                    index >=
                        data.length) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta:
                  meta,
                  space:
                  8,
                  child:
                  Text(
                    data[index]
                        .label,
                    style:
                    TextStyle(
                      fontSize:
                      10,
                      color:
                      Colors.grey.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData:
        const LineTouchData(
          enabled:
          true,
        ),
        lineBarsData: [
          LineChartBarData(
            spots:
            List.generate(
              data.length,
                  (index) =>
                  FlSpot(
                    index.toDouble(),
                    data[index]
                        .stamps
                        .toDouble(),
                  ),
            ),
            isCurved:
            true,
            color:
            mainGreen,
            barWidth:
            3,
            dotData:
            const FlDotData(
              show:
              true,
            ),
            belowBarData:
            BarAreaData(
              show:
              true,
              color:
              mainGreen.withOpacity(
                0.08,
              ),
            ),
          ),

          LineChartBarData(
            spots:
            List.generate(
              data.length,
                  (index) =>
                  FlSpot(
                    index.toDouble(),
                    data[index]
                        .challenges
                        .toDouble(),
                  ),
            ),
            isCurved:
            true,
            color:
            Colors.orange,
            barWidth:
            3,
            dotData:
            const FlDotData(
              show:
              true,
            ),
          ),
        ],
      ),
    );
  }

  double _trendInterval(
      int length,
      ) {
    if (length <= 12) {
      return 1;
    }

    if (length <= 20) {
      return 2;
    }

    return 5;
  }

  // ============================================================
  // STAMP BAR CHART
  // ============================================================

  Widget _topStampChart(
      List<_StampCount> stamps,
      ) {
    if (stamps.isEmpty) {
      return _emptyChart(
        'No stamp data available.',
      );
    }

    final maxValue =
    stamps
        .map(
          (e) =>
      e.count,
    )
        .reduce(
      math.max,
    )
        .toDouble();

    return BarChart(
      BarChartData(
        minY:
        0,
        maxY:
        maxValue + 1,
        alignment:
        BarChartAlignment
            .spaceAround,
        borderData:
        FlBorderData(
          show:
          false,
        ),
        gridData:
        FlGridData(
          show:
          true,
          drawVerticalLine:
          false,
          getDrawingHorizontalLine:
              (value) =>
              FlLine(
                color:
                Colors.grey.shade200,
                strokeWidth:
                1,
              ),
        ),
        titlesData:
        FlTitlesData(
          topTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          rightTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          leftTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              30,
            ),
          ),
          bottomTitles:
          AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              45,
              getTitlesWidget:
                  (
                  value,
                  meta,
                  ) {
                final index =
                value.toInt();

                if (index < 0 ||
                    index >=
                        stamps.length) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta:
                  meta,
                  space:
                  7,
                  child:
                  SizedBox(
                    width:
                    70,
                    child:
                    Text(
                      _shorten(
                        stamps[index]
                            .attractionName,
                        12,
                      ),
                      textAlign:
                      TextAlign.center,
                      maxLines:
                      2,
                      style:
                      const TextStyle(
                        fontSize:
                        9,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups:
        List.generate(
          stamps.length,
              (index) =>
              BarChartGroupData(
                x:
                index,
                barRods: [
                  BarChartRodData(
                    toY:
                    stamps[index]
                        .count
                        .toDouble(),
                    width:
                    30,
                    color:
                    mainGreen,
                    borderRadius:
                    const BorderRadius
                        .vertical(
                      top:
                      Radius.circular(
                        6,
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  // ============================================================
  // CHALLENGE BAR CHART
  // ============================================================

  Widget _challengeChart(
      List<_ChallengeCount> challenges,
      ) {
    if (challenges.isEmpty) {
      return _emptyChart(
        'No challenge data available.',
      );
    }

    final maxValue =
    challenges
        .map(
          (e) =>
      e.count,
    )
        .reduce(
      math.max,
    )
        .toDouble();

    return BarChart(
      BarChartData(
        minY:
        0,
        maxY:
        maxValue + 1,
        alignment:
        BarChartAlignment
            .spaceAround,
        borderData:
        FlBorderData(
          show:
          false,
        ),
        gridData:
        FlGridData(
          show:
          true,
          drawVerticalLine:
          false,
          getDrawingHorizontalLine:
              (value) =>
              FlLine(
                color:
                Colors.grey.shade200,
                strokeWidth:
                1,
              ),
        ),
        titlesData:
        FlTitlesData(
          topTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          rightTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              false,
            ),
          ),
          leftTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              30,
            ),
          ),
          bottomTitles:
          AxisTitles(
            sideTitles:
            SideTitles(
              showTitles:
              true,
              reservedSize:
              45,
              getTitlesWidget:
                  (
                  value,
                  meta,
                  ) {
                final index =
                value.toInt();

                if (index < 0 ||
                    index >=
                        challenges.length) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta:
                  meta,
                  space:
                  7,
                  child:
                  SizedBox(
                    width:
                    70,
                    child:
                    Text(
                      _shorten(
                        challenges[index]
                            .challengeTitle,
                        12,
                      ),
                      textAlign:
                      TextAlign.center,
                      maxLines:
                      2,
                      style:
                      const TextStyle(
                        fontSize:
                        9,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups:
        List.generate(
          challenges.length,
              (index) =>
              BarChartGroupData(
                x:
                index,
                barRods: [
                  BarChartRodData(
                    toY:
                    challenges[
                    index]
                        .count
                        .toDouble(),
                    width:
                    30,
                    color:
                    Colors.orange,
                    borderRadius:
                    const BorderRadius
                        .vertical(
                      top:
                      Radius.circular(
                        6,
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  // ============================================================
  // KPI CARD
  // ============================================================

  Widget _summaryCard({
    required double width,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width:
      width,
      constraints:
      const BoxConstraints(
        minWidth:
        170,
      ),
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:
            48,
            height:
            48,
            decoration:
            BoxDecoration(
              color:
              mainGreen.withOpacity(
                0.09,
              ),
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color:
              mainGreen,
              size:
              24,
            ),
          ),

          const SizedBox(
            width:
            12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  value,
                  style:
                  const TextStyle(
                    fontSize:
                    20,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                  1,
                ),

                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize:
                    12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                Text(
                  subtitle,
                  style:
                  TextStyle(
                    fontSize:
                    10,
                    color:
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHART PANEL
  // ============================================================

  Widget _chartPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Text(
            title,
            style:
            const TextStyle(
              fontSize:
              17,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(
            subtitle,
            style:
            TextStyle(
              fontSize:
              12,
              color:
              Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height:
            18,
          ),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL CARD
  // ============================================================

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:
            50,
            height:
            50,
            decoration:
            BoxDecoration(
              color:
              mainGreen.withOpacity(
                0.09,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
              mainGreen,
            ),
          ),

          const SizedBox(
            width:
            14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                  3,
                ),

                Text(
                  description,
                  style:
                  TextStyle(
                    fontSize:
                    11,
                    color:
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width:
            15,
          ),

          Text(
            value,
            style:
            const TextStyle(
              fontSize:
              25,
              fontWeight:
              FontWeight.w700,
              color:
              mainGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CHART
  // ============================================================

  Widget _emptyChart(
      String text,
      ) {
    return Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .bar_chart_outlined,
            size:
            46,
            color:
            Colors.grey.shade300,
          ),

          const SizedBox(
            height:
            8,
          ),

          Text(
            text,
            style:
            TextStyle(
              color:
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorView(
      Object? error,
      ) {
    return Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size:
            50,
            color:
            Colors.red,
          ),

          const SizedBox(
            height:
            12,
          ),

          const Text(
            'Unable to load report',
            style:
            TextStyle(
              fontSize:
              18,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
            6,
          ),

          Text(
            '$error',
            textAlign:
            TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DECORATION
  // ============================================================

  InputDecoration
  _compactDropdownDecoration() {
    return InputDecoration(
      isDense:
      true,
      filled:
      true,
      fillColor:
      const Color(
        0xFFF7F9F7,
      ),
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        12,
        vertical:
        11,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        borderSide:
        BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        borderSide:
        BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _trendSubtitle() {
    if (_periodType ==
        'monthly') {
      return 'Daily stamp collections and challenge completions in $_periodLabel';
    }

    if (_periodType ==
        'yearly') {
      return 'Monthly stamp collections and challenge completions in $_periodLabel';
    }

    return 'Yearly stamp collections and challenge completions';
  }

  String _shorten(
      String value,
      int maxLength,
      ) {
    if (value.length <=
        maxLength) {
      return value;
    }

    return '${value.substring(0, maxLength)}…';
  }

  String _monthName(
      int month,
      ) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return names[
    month - 1];
  }

  String _shortMonthName(
      int month,
      ) {
    const names = [
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

    return names[
    month - 1];
  }
}

// ============================================================
// REPORT MODEL
// ============================================================

class _GamificationReportData {
  const _GamificationReportData({
    required this.totalParticipants,
    required this.totalStamps,
    required this.totalChallengesCompleted,
    required this.totalPointsAwarded,
    required this.totalCarbonSaved,
    required this.averageStampsPerUser,
    required this.averageChallengesPerUser,
    required this.topStamps,
    required this.topChallenges,
    required this.trend,
  });

  final int totalParticipants;
  final int totalStamps;
  final int totalChallengesCompleted;
  final int totalPointsAwarded;

  final double totalCarbonSaved;
  final double averageStampsPerUser;
  final double averageChallengesPerUser;

  final List<_StampCount>
  topStamps;

  final List<_ChallengeCount>
  topChallenges;

  final List<_TrendPoint>
  trend;
}

// ============================================================
// STAMP COUNT
// ============================================================

class _StampCount {
  const _StampCount({
    required this.attractionId,
    required this.attractionName,
    required this.count,
  });

  final String attractionId;
  final String attractionName;
  final int count;

  _StampCount copyWith({
    int? count,
  }) {
    return _StampCount(
      attractionId:
      attractionId,
      attractionName:
      attractionName,
      count:
      count ?? this.count,
    );
  }
}

// ============================================================
// CHALLENGE COUNT
// ============================================================

class _ChallengeCount {
  const _ChallengeCount({
    required this.challengeId,
    required this.challengeTitle,
    required this.count,
  });

  final String challengeId;
  final String challengeTitle;
  final int count;
}

// ============================================================
// TREND
// ============================================================

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.stamps,
    required this.challenges,
  });

  final String label;
  final int stamps;
  final int challenges;
}

class _MutableTrend {
  _MutableTrend({
    required this.label,
    required this.sortDate,
  });

  final String label;
  final DateTime sortDate;

  int stamps = 0;
  int challenges = 0;
}