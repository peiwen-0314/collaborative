import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/saved_trip.dart';
import '../widgets/location_row.dart';
import '../widgets/trip_widgets.dart';
import 'navigation_page.dart';

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({
    super.key,
    required this.from,
    required this.to,
    required this.option,
  });

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final TransportController _controller = TransportController();

  bool _saved = false;

  SavedTrip get _asSavedTrip => SavedTrip(
    from: widget.from,
    to: widget.to,
    option: widget.option,
    savedAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final saved = await _controller.isTripSaved(_asSavedTrip.id);
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _toggleSave() async {
    final nowSaved = await _controller.toggleSavedTrip(_asSavedTrip);
    if (!mounted) return;
    setState(() => _saved = nowSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(nowSaved ? 'Trip saved' : 'Removed from saved list'),
      ),
    );
  }

  void _edit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Adjust the From/To/date on the search screen to edit this trip.',
        ),
      ),
    );
    Navigator.of(context).maybePop();
  }

  void _startNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          from: widget.from,
          to: widget.to,
          option: widget.option,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _DetailsBackground(),
          _TripContent(from: widget.from, to: widget.to, option: widget.option),
          _BackButton(onPressed: () => Navigator.of(context).pop()),
          _DetailsActions(
            saved: _saved,
            onSave: _toggleSave,
            onEdit: _edit,
            onStartNavigation: _startNavigation,
          ),
        ],
      ),
    );
  }
}

class _DetailsBackground extends StatelessWidget {
  const _DetailsBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Column(
        children: [
          SizedBox(
            height: 230,
            width: double.infinity,
            child: Image.asset(AppAssets.temple, fit: BoxFit.cover),
          ),
          const Expanded(child: ColoredBox(color: Colors.white)),
        ],
      ),
    );
  }
}

class _TripContent extends StatelessWidget {
  const _TripContent({required this.from, required this.to, required this.option});

  final LocationPoint from;
  final LocationPoint to;
  final RideOption option;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 170, 14, 150),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Departs ${formatFriendlyDateTime(option.departTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              LocationRow(label: 'From', value: from.name, color: AppColors.green),
              const Divider(height: 18),
              LocationRow(
                label: 'To',
                value: to.name,
                color: AppColors.orange,
                outlined: true,
              ),
              const SizedBox(height: 10),
              TripSummary(option: option),
              const SizedBox(height: 22),
              for (final leg in option.legs)
                TimelineItem(
                  start: formatClockTime(leg.start),
                  end: formatClockTime(leg.end),
                  title: leg.title,
                  subtitle: leg.subtitle,
                  duration: formatDuration(leg.duration),
                  mode: leg.isTransfer ? null : leg.mode,
                  transfer: leg.isTransfer,
                ),
              DestinationRow(
                arrivalTimeLabel: formatClockTime(option.arriveTime),
                destinationLabel: to.name,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: Colors.white70),
          onPressed: onPressed,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DetailsActions extends StatelessWidget {
  const _DetailsActions({
    required this.saved,
    required this.onSave,
    required this.onEdit,
    required this.onStartNavigation,
  });

  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    // Anchored full-width with a solid background (rather than a floating,
    // background-less bar) so the scrollable trip timeline behind it is
    // fully hidden instead of showing through around/behind the buttons.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 43,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: onStartNavigation,
                  icon: const Icon(Icons.navigation_outlined, size: 19),
                  label: const Text(
                    'Start Navigation',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSave,
                      icon: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                      ),
                      label: Text(saved ? 'Saved' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
