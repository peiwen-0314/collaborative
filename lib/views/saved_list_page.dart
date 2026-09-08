import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/saved_trip.dart';
import '../services/location_service.dart';
import '../widgets/ride_card.dart';
import 'trip_details_page.dart';

class SavedListPage extends StatefulWidget {
  const SavedListPage({super.key});

  @override
  State<SavedListPage> createState() => _SavedListPageState();
}

class _SavedListPageState extends State<SavedListPage> {
  final TransportController _controller = TransportController();
  final LocationService _locationService = const LocationService();

  List<SavedTrip>? _trips;
  String? _error;

  LocationPoint? _currentLocation;

  @override
  void initState() {
    super.initState();
    _load().then((_) => _checkRainAndPrompt());
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final result = await _locationService.detectCurrentLocation();
    if (!mounted || result.point == null) return;
    setState(() => _currentLocation = result.point);
  }

  Future<void> _load() async {
    try {
      final trips = await _controller.getSavedTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _remove(SavedTrip trip) async {
    try {
      await _controller.removeSavedTrip(trip.id);
      if (!mounted) return;
      setState(
        () => _trips?.removeWhere((existing) => existing.id == trip.id),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not remove trip: $error'),
        ),
      );
      _load();
    }
  }

  Future<void> _checkRainAndPrompt() async {
    final trips = _trips;
    if (trips == null || trips.isEmpty || !mounted) return;

    List<RainyBikeAlert> alerts;
    try {
      alerts = await _controller.checkSavedTripsForRain(trips);
    } catch (_) {
      return;
    }
    if (alerts.isEmpty || !mounted) return;

    for (final alert in alerts) {
      if (!mounted) return;
      if (!(_trips?.any((t) => t.id == alert.trip.id) ?? false)) continue;

      final wantsSwap = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rain near a saved bike leg'),
          content: Text(
            "It's currently raining near the bike leg of your saved "
            '${alert.trip.from.name} -> ${alert.trip.to.name} trip. '
            'Swap it for a real alternative?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Swap it'),
            ),
          ],
        ),
      );
      if (wantsSwap != true || !mounted) continue;
      await _swapBikeLeg(alert);
    }
  }

  Future<void> _swapBikeLeg(RainyBikeAlert alert) async {
    try {
      final updated = await _controller.swapRainyBikeLeg(alert);
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No real alternative found for that bike leg.'),
          ),
        );
        return;
      }
      setState(() {
        final idx = _trips?.indexWhere((t) => t.id == alert.trip.id) ?? -1;
        if (idx != -1) _trips![idx] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Swapped the bike leg for a real alternative.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not update saved trip: $error'),
        ),
      );
    }
  }

  void _openTrip(SavedTrip trip) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TripDetailsPage(
              from: trip.from,
              to: trip.to,
              option: trip.option,
              allowTimeChange: true,
              // See TripDetailsPage.isSavedTrip's doc comment - hides
              // the "Wait ..." text here too, matching the card above.
              isSavedTrip: true,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.orange,
                size: 32,
              ),
              const SizedBox(height: 10),
              const Text(
                'Could not load your saved trips.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final trips = _trips;
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

    final groups = groupSavedTrips(trips, currentLocation: _currentLocation);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 22),
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 7),
              child: Tooltip(
                message: '${group.from.name}  →  ${group.to.name}',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                child: Text(
                  '${shortPlaceName(group.from.name)}  →  ${shortPlaceName(group.to.name)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
            for (final trip in group.trips) ...[
              Dismissible(
                key: ValueKey(trip.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _remove(trip),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
                child: RideCard(
                  option: trip.option,
                  onTap: () => _openTrip(trip),
                  showWaitWarning: false,
                ),
              ),
              if (trip != group.trips.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
