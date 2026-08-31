import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';

/// Opens a bottom sheet where the user types a place name (any real-world
/// address or landmark - not just a fixed list of choices) and confirms it.
/// The typed keyword is resolved to a [LocationPoint] via free reverse/
/// forward geocoding. Resolves with the picked point, or `null` if the
/// user dismissed the sheet without confirming anything.
Future<LocationPoint?> showLocationPicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<LocationPoint>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _LocationPickerSheet(title: title),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.title});

  final String title;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _controller = TextEditingController();
  final _locationService = const LocationService();

  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      setState(() => _error = 'Type a place name first.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    final result = await _locationService.searchPlace(keyword);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _searching = false;
        _error = "Couldn't find that place. Try a different keyword.";
      });
      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                'Type any place name or address.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                enabled: !_searching,
                decoration: InputDecoration(
                  hintText: 'e.g. Cyberjaya, or 1 Utama Shopping Centre',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.chip,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _searching ? null : _submit,
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
