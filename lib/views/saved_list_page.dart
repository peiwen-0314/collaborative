import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../models/saved_trip.dart';
import '../widgets/ride_card.dart';
import 'trip_details_page.dart';

class SavedListPage extends StatefulWidget {
  const SavedListPage({super.key});

  @override
  State<SavedListPage> createState() => _SavedListPageState();
}

class _SavedListPageState extends State<SavedListPage> {
  final TransportController _controller = TransportController();

  List<SavedTrip>? _trips;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await _controller.getSavedTrips();
    if (!mounted) return;
    setState(() => _trips = trips);
  }

  Future<void> _remove(SavedTrip trip) async {
    await _controller.removeSavedTrip(trip.id);
    if (!mounted) return;
    setState(() => _trips?.removeWhere((existing) => existing.id == trip.id));
  }

  void _openTrip(SavedTrip trip) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TripDetailsPage(
              from: trip.from,
              to: trip.to,
              option: trip.option,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final trips = _trips;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Saved List',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(trips),
    );
  }

  Widget _buildBody(List<SavedTrip>? trips) {
    if (trips == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (trips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saved trips yet.\nSave a trip from its details page to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Dismissible(
          key: ValueKey(trip.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _remove(trip),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            margin: const EdgeInsets.only(top: 19),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 7),
                child: Text(
                  '${trip.from.name}  --->  ${trip.to.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              RideCard(option: trip.option, onTap: () => _openTrip(trip)),
            ],
          ),
        );
      },
    );
  }
}
