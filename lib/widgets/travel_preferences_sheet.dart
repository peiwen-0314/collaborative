import 'package:flutter/material.dart';

import '../controllers/transport_controller.dart';
import '../core/app_theme.dart';
import '../services/travel_preferences_service.dart';

class TravelPreferencesSheet extends StatefulWidget {
  const TravelPreferencesSheet({super.key, required this.controller});

  final TransportController controller;

  /// Convenience wrapper so callers don't need to repeat the
  /// showModalBottomSheet boilerplate - see RideHomePage._openTravelPreferences.
  static Future<void> show(
    BuildContext context,
    TransportController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TravelPreferencesSheet(controller: controller),
    );
  }

  @override
  State<TravelPreferencesSheet> createState() =>
      _TravelPreferencesSheetState();
}

class _TravelPreferencesSheetState extends State<TravelPreferencesSheet> {
  bool _loading = true;
  bool _saving = false;
  RoutePriority _priority = RoutePriority.balanced;
  final _budgetController = TextEditingController();
  final _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await widget.controller.loadTravelPreferences();
    if (!mounted) return;
    setState(() {
      _priority = preferences.priority;
      _budgetController.text = preferences.budgetCapRm == null
          ? ''
          : _formatBudget(preferences.budgetCapRm!);
      _maxDurationController.text = preferences.maxDurationMinutes == null
          ? ''
          : preferences.maxDurationMinutes!.toString();
      _loading = false;
    });
  }

  String _formatBudget(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _save() async {
    final budgetText = _budgetController.text.trim();
    final parsed = budgetText.isEmpty ? null : double.tryParse(budgetText);
    final budgetCapRm = (parsed != null && parsed > 0) ? parsed : null;
    final durationText = _maxDurationController.text.trim();
    final parsedDuration = durationText.isEmpty
        ? null
        : int.tryParse(durationText);
    final maxDurationMinutes = (parsedDuration != null && parsedDuration > 0)
        ? parsedDuration
        : null;
    setState(() => _saving = true);
    await widget.controller.saveTravelPreferences(
      TravelPreferences(
        priority: _priority,
        budgetCapRm: budgetCapRm,
        maxDurationMinutes: maxDurationMinutes,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _priorityTile(RoutePriority priority) {
    final selected = _priority == priority;
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.paleGreen : Colors.white,
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? AppColors.green : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? AppColors.green : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Travel Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tell us what matters most and we'll weight AI recommendations "
            'toward it.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final priority in RoutePriority.values)
                _priorityTile(priority),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _priority.description,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          const Text(
            'Budget cap per trip (RM, optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "We'll flag and deprioritise (never hide) options that cost "
            'more than this.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. 15',
              prefixText: 'RM ',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Max travel duration (minutes, optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "We'll flag and deprioritise (never hide) options that take "
            'longer than this, including any wait for a scheduled service.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _maxDurationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 45',
              suffixText: 'min',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
