import 'package:flutter/material.dart';
import '../models/attraction.dart';

class AttractionDetailPage extends StatelessWidget {
  final AttractionModel attraction;
  final double estimatedFee;
  const AttractionDetailPage({super.key, required this.attraction, required this.estimatedFee});

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color secondaryText = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    final hero = attraction.coverImageUrl.trim().isNotEmpty ? attraction.coverImageUrl : (attraction.imageUrls.isNotEmpty ? attraction.imageUrls.first : '');
    final second = attraction.imageUrls.length > 1 ? attraction.imageUrls[1] : hero;
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [SizedBox(width: double.infinity, height: 225, child: hero.isEmpty ? Container(color: lightGreen, child: const Icon(Icons.landscape_outlined, size: 70, color: mainGreen)) : Image.network(hero, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: lightGreen, child: const Icon(Icons.landscape_outlined, size: 70, color: mainGreen)))), Positioned(left: 10, top: 10, child: CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.9), child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17))))]),
      Transform.translate(offset: const Offset(0, -18), child: Container(margin: const EdgeInsets.symmetric(horizontal: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(attraction.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [_pill(attraction.categoryName), Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_outlined, color: mainGreen, size: 13), const SizedBox(width: 3), Text('${attraction.area}, ${attraction.state}', style: const TextStyle(color: mainGreen, fontSize: 9))])]),
        const SizedBox(height: 14), const Divider(), const SizedBox(height: 8),
        Row(children: [Expanded(child: _info(Icons.payments_outlined, 'Entry Fee', attraction.isFreeEntry ? 'Free' : 'MYR ${estimatedFee.toStringAsFixed(0)}')), Expanded(child: _info(Icons.schedule_outlined, 'Opening Hours', '${attraction.openingTime}\n${attraction.closingTime}')), Expanded(child: _info(Icons.hourglass_bottom_rounded, 'Visit Duration', attraction.recommendedDuration.trim().isEmpty ? '-' : attraction.recommendedDuration)), Expanded(child: _info(Icons.phone_outlined, 'Contact', attraction.phoneNumber.trim().isEmpty ? '-' : attraction.phoneNumber))]),
        const SizedBox(height: 18),
        const Text('About This Attraction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(attraction.description, style: const TextStyle(fontSize: 10, color: secondaryText, height: 1.4))), const SizedBox(width: 10), ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 112, height: 78, child: second.isEmpty ? Container(color: lightGreen, child: const Icon(Icons.image_outlined, color: mainGreen)) : Image.network(second, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: lightGreen, child: const Icon(Icons.image_outlined, color: mainGreen)))))]),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _list('Highlights', Icons.eco_outlined, attraction.highlights)), const SizedBox(width: 12), Expanded(child: _facilities(attraction.facilities))]),
        const SizedBox(height: 18), const Divider(), const SizedBox(height: 12),
        const Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 7),
        Text('${attraction.area}, ${attraction.state}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(height: 3),
        Text(attraction.address.trim().isEmpty ? 'Address not provided' : attraction.address, style: const TextStyle(fontSize: 9, color: secondaryText)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps integration can be connected here.'))), icon: const Icon(Icons.navigation_outlined, size: 17), label: const Text('Get Directions'), style: OutlinedButton.styleFrom(foregroundColor: mainGreen, side: const BorderSide(color: mainGreen), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
      ])))
    ]))));
  }

  Widget _pill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(16)), child: Text(text, style: const TextStyle(color: mainGreen, fontSize: 8, fontWeight: FontWeight.w600)));

  Widget _info(IconData icon, String title, String value) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [Icon(icon, size: 19, color: mainGreen), const SizedBox(height: 4), Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.2, fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text(value, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 6.8, color: secondaryText))]));

  Widget _list(String title, IconData icon, List<String> values) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: mainGreen, size: 15), const SizedBox(width: 5), Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]), const SizedBox(height: 7), if (values.isEmpty) const Text('No information available.', style: TextStyle(fontSize: 8, color: secondaryText)) else ...values.take(6).map((v) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline_rounded, size: 12, color: mainGreen), const SizedBox(width: 4), Expanded(child: Text(v, style: const TextStyle(fontSize: 8, height: 1.2)))]))) ]);

  Widget _facilities(List<String> values) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.grid_view_rounded, color: mainGreen, size: 15), SizedBox(width: 5), Text('Facilities', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]), const SizedBox(height: 7), if (values.isEmpty) const Text('No information available.', style: TextStyle(fontSize: 8, color: secondaryText)) else Wrap(spacing: 5, runSpacing: 5, children: values.take(8).map((v) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(6)), child: Text(v, style: const TextStyle(fontSize: 7, color: mainGreen)))).toList())]);
}
