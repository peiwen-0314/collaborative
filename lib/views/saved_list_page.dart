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
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rain check only runs once the initial load has actually finished
    // (not chained onto every subsequent _load(), e.g. after returning
    // from a trip's details page - re-prompting about the same rain on
    // every navigation back to this page would get old fast; "every
    // time the page is opened" means this initState, not every reload).
    _load().then((_) => _checkRainAndPrompt());
  }

  Future<void> _load() async {
    // No setState before the first `await` here on purpose - this runs
    // synchronously from initState the first time, and calling
    // setState() on that same call stack (i.e. before Flutter's first
    // build for this page has happened) throws. _error only gets
    // cleared as part of the same setState as a successful `_trips`
    // update below, so a Retry after a failure still clears the old
    // error message once it succeeds.
    try {
      final trips = await _controller.getSavedTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
      });
    } catch (error) {
      // Without this, a failure here (no signed-in user, a missing
      // Firestore rule, no network...) left the page spinning forever
      // instead of saying why - showing the real error is what makes
      // "my saved trips aren't showing up" diagnosable from the app
      // itself instead of guessing.
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
      // The Dismissible already animated itself away optimistically -
      // reload from Firestore so the list reflects what's actually
      // saved there instead of staying out of sync.
      _load();
    }
  }

  /// Best-effort rain check across every saved trip with a real bike
  /// leg (see TransportController.checkSavedTripsForRain), then prompts
  /// about each rainy one in turn - one dialog at a time, not all at
  /// once, so a person with several rainy saved bike trips isn't hit
  /// with a stack of overlapping dialogs.
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
      // The trip this alert was computed for may have been removed
      // (swiped away) while an earlier alert in this same batch was
      // still being decided - skip it rather than prompting about
      // something no longer in the list.
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
              // Opened from the Saved List specifically - see
              // TripDetailsPage.allowTimeChange's doc comment for why
              // this differs from opening straight out of a fresh
              // search (ride_home_page.dart's _openDetails), which
              // leaves this false.
              allowTimeChange: true,
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
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
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
