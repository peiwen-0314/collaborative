import 'package:flutter/material.dart';

// Pushed from ProfilePage's ABOUT section - a real page (not a popup),
// so it gets its own back-button AppBar like TripPlansPage/SavedListPage
// already use for their own pushed sub-pages.
class AboutEcoTravelPage extends StatelessWidget {
  const AboutEcoTravelPage({super.key});

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'About EcoTravel',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: mainGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: mainGreen,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EcoTravel',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Our Mission',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'EcoTravel helps you plan greener journeys - comparing '
                'routes by cost, time and CO2 impact, surfacing '
                'eco-friendly transport options, and pointing out '
                'cultural and heritage attractions worth a detour along '
                'the way.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'What EcoTravel Offers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 10),

              _bullet('Compare ride options by cost, duration and CO2 emissions'),
              _bullet('Plan multi-stop trips and save your favourite routes'),
              _bullet('Discover cultural and heritage attractions nearby'),
              _bullet('Personalised recommendations based on your interests'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: mainGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
