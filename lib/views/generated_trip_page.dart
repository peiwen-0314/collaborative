import 'package:flutter/material.dart';
import '../controllers/ai_trip_planner_controller.dart';
import '../models/attraction.dart';
import 'attraction_detail_page.dart';

class GeneratedTripPage extends StatefulWidget {
  final AiTripPlannerController controller;
  const GeneratedTripPage({super.key, required this.controller});
  @override
  State<GeneratedTripPage> createState() => _GeneratedTripPageState();
}

class _GeneratedTripPageState extends State<GeneratedTripPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  int selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final days = widget.controller.preferences.totalDays <= 0 ? 1 : widget.controller.preferences.totalDays;
    final list = widget.controller.attractionsForDay(selectedDay);
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: Column(children: [
      _appBar(),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 22, backgroundColor: lightGreen, child: Icon(Icons.check_circle_rounded, color: mainGreen, size: 30)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your trip is ready!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('We’ve crafted a personalized, sustainable itinerary just for you.', style: TextStyle(fontSize: 11, color: Color(0xFF777777), height: 1.3))]))]),
        const SizedBox(height: 18),
        _summary(),
        const SizedBox(height: 18),
        SizedBox(height: 34, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: days, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (context, i) { final s = selectedDay == i; return InkWell(onTap: () => setState(() => selectedDay = i), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 13), alignment: Alignment.center, decoration: BoxDecoration(color: s ? mainGreen : Colors.white, border: Border.all(color: s ? mainGreen : const Color(0xFFE1E1E1)), borderRadius: BorderRadius.circular(20)), child: Text('Day ${i + 1}', style: TextStyle(color: s ? Colors.white : const Color(0xFF555555), fontSize: 10, fontWeight: FontWeight.w600)))); })),
        const SizedBox(height: 14),
        if (list.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No attractions for this day.'))) else ...List.generate(list.length, (i) => _item(list[i], i, i == list.length - 1)),
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 18), child: SizedBox(width: double.infinity, height: 46, child: ElevatedButton(onPressed: () async { await widget.controller.generateTrip(); if (mounted) setState(() => selectedDay = 0); }, style: ElevatedButton.styleFrom(backgroundColor: mainGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))), child: const Text('Regenerate Plan')))),
    ])));
  }

  Widget _appBar() => SizedBox(height: 50, child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)), const Expanded(child: Text('AI Trip Planner', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), const SizedBox(width: 48)]));

  Widget _summary() => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14), decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: _sum(Icons.calendar_today_outlined, '${widget.controller.preferences.totalDays} Days', 'Total Days')), Expanded(child: _sum(Icons.access_time_rounded, 'MYR ${widget.controller.estimatedTotalAttractionCost.toStringAsFixed(0)}', 'Attraction Cost')), Expanded(child: _sum(Icons.location_on_outlined, '${widget.controller.generatedAttractions.length} Places', 'Total Attraction'))]));

  Widget _sum(IconData icon, String value, String label) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: mainGreen), const SizedBox(width: 5), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7, color: Color(0xFF666666)))]))]);

  Widget _item(AttractionModel a, int index, bool last) {
    final image = a.coverImageUrl.trim().isNotEmpty ? a.coverImageUrl : (a.imageUrls.isNotEmpty ? a.imageUrls.first : '');
    final hour = 8 + index * 3;
    final time = '${hour > 12 ? hour - 12 : hour}:30 ${hour >= 12 ? 'pm' : 'am'}';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 52, child: Text(time, style: const TextStyle(fontSize: 8, color: Color(0xFF555555)))),
      SizedBox(width: 18, child: Column(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: mainGreen, width: 2), shape: BoxShape.circle)), if (!last) Container(width: 1, height: 95, color: const Color(0xFF888888))])),
      const SizedBox(width: 6),
      Expanded(child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttractionDetailPage(attraction: a, estimatedFee: widget.controller.estimateAttractionFee(a)))), borderRadius: BorderRadius.circular(9), child: Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 72, height: 82, child: image.isEmpty ? Container(color: lightGreen, child: const Icon(Icons.image_outlined, color: mainGreen)) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: lightGreen, child: const Icon(Icons.image_outlined, color: mainGreen))))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Row(children: [const Icon(Icons.location_on_outlined, color: mainGreen, size: 12), const SizedBox(width: 2), Expanded(child: Text('${a.area}, ${a.state}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: mainGreen, fontSize: 8)))]), const SizedBox(height: 5), Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: Color(0xFF666666), height: 1.25)), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(15)), child: Text(a.categoryName, style: const TextStyle(color: mainGreen, fontSize: 7, fontWeight: FontWeight.w600))) ]))
      ]))))
    ]);
  }
}
