import 'package:flutter/material.dart';
import '../controllers/ai_trip_planner_controller.dart';
import 'generated_trip_page.dart';

class TripTravelStylePage extends StatefulWidget {
  final AiTripPlannerController controller;
  const TripTravelStylePage({super.key, required this.controller});
  @override
  State<TripTravelStylePage> createState() => _TripTravelStylePageState();
}

class _TripTravelStylePageState extends State<TripTravelStylePage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  final Map<String, IconData> icons = const {
    'Sustainable Explorer': Icons.eco_outlined,
    'Culture Seeker': Icons.account_balance_outlined,
    'Nature Lover': Icons.landscape_outlined,
    'Relax & Unwind': Icons.beach_access_outlined,
    'Adventure Enthusiast': Icons.hiking_outlined,
    'Foodie': Icons.restaurant_outlined,
  };
  final Map<String, String> desc = const {
    'Sustainable Explorer': 'Eco-conscious travel, support local communities and protect nature.',
    'Culture Seeker': 'Immerse in local culture, history, and authentic experiences.',
    'Nature Lover': 'Explore nature, scenery and outdoor experiences.',
    'Relax & Unwind': 'Take it slow and enjoy relaxing places and beautiful scenery.',
    'Adventure Enthusiast': 'Thrill-seeking activities, hiking, trekking and adventure.',
    'Foodie': 'Discover local cuisines, food markets and unique dining experiences.',
  };

  Future<void> _generate() async {
    if (widget.controller.preferences.travelStyle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a travel style.')));
      return;
    }
    final ok = await widget.controller.generateTrip();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.controller.errorMessage ?? 'Unable to generate trip.'), backgroundColor: Colors.red.shade700));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => GeneratedTripPage(controller: widget.controller)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.preferences.travelStyle;
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: Column(children: [
      _appBar(),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [CircleAvatar(radius: 21, backgroundColor: lightGreen, child: Icon(Icons.eco_rounded, color: mainGreen)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('What’s your travel style?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Help our AI craft the perfect itinerary for you.', style: TextStyle(fontSize: 11, color: Color(0xFF777777))) ]))]),
        const SizedBox(height: 22),
        const Text('Choose your travel style', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Select the style that best represents how you like to travel.', style: TextStyle(fontSize: 10, color: Color(0xFF777777))),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: AiTripPlannerController.travelStyles.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: 1.05), itemBuilder: (context, index) {
          final style = AiTripPlannerController.travelStyles[index];
          final isSelected = selected == style;
          return InkWell(onTap: () { widget.controller.setTravelStyle(style); setState(() {}); }, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isSelected ? lightGreen : Colors.white, border: Border.all(color: isSelected ? mainGreen : const Color(0xFFE1E1E1), width: isSelected ? 1.5 : 1), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 20, backgroundColor: lightGreen, child: Icon(icons[style], color: mainGreen)), const Spacer(), if (isSelected) const Icon(Icons.check_circle_rounded, color: mainGreen, size: 20)]), const SizedBox(height: 9), Text(style, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Expanded(child: Text(desc[style]!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, height: 1.25, color: Color(0xFF777777))))])));
        })
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 18), child: SizedBox(width: double.infinity, height: 47, child: ElevatedButton(onPressed: widget.controller.isLoading ? null : _generate, style: ElevatedButton.styleFrom(backgroundColor: mainGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))), child: widget.controller.isLoading ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Next: Generate My Trip  ›')))),
    ])));
  }

  Widget _appBar() => SizedBox(height: 52, child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)), const Expanded(child: Text('AI Trip Planner', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), const SizedBox(width: 48)]));
}
