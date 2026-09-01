import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';

enum _ActiveField { none, from, to }

/// The From/To card. Both fields are editable in place - typing shows a
/// live list of matching Malaysian places (via free Nominatim search)
/// floating just underneath the card, instead of opening a separate picker
/// screen. The list is a floating overlay (via [CompositedTransformFollower])
/// rather than an inline widget, so it never pushes the date chip /
/// recommendations / saved list further down the page while it's open.
class JourneyCard extends StatefulWidget {
  const JourneyCard({
    super.key,
    required this.from,
    required this.to,
    required this.onFromSelected,
    required this.onToSelected,
    required this.onSwap,
    this.fromPlaceholder = 'Detecting your location…',
  });

  /// Null while the user's location is still being detected (or blank
  /// because they denied location permission).
  final LocationPoint? from;

  /// Null until the user picks a destination.
  final LocationPoint? to;

  /// Called once the user taps a suggestion for "From". Not called if the
  /// picked place is the same as the current "To" - the card shows its own
  /// inline warning and leaves the field as-is in that case.
  final ValueChanged<LocationPoint> onFromSelected;

  /// Same as [onFromSelected] but for "To".
  final ValueChanged<LocationPoint> onToSelected;

  final VoidCallback onSwap;

  /// Shown in place of [from]'s name while it's null. Lets the caller
  /// distinguish "still detecting" from "detection failed, tap to pick".
  final String fromPlaceholder;

  @override
  State<JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<JourneyCard> {
  late final TextEditingController _fromController = TextEditingController(
    text: widget.from?.name ?? '',
  );
  late final TextEditingController _toController = TextEditingController(
    text: widget.to?.name ?? '',
  );
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  final _locationService = const LocationService();

  final _layerLink = LayerLink();
  final _cardKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  _ActiveField _activeField = _ActiveField.none;
  List<LocationPoint> _suggestions = const [];
  bool _loadingSuggestions = false;
  String? _inlineError;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(_handleFocusChange);
    _toFocus.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant JourneyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the text in sync with externally-driven changes (auto location
    // detection landing, a swap) - but never while the user is actively
    // typing in that field, or we'd yank the cursor out from under them.
    if (widget.from?.name != oldWidget.from?.name && !_fromFocus.hasFocus) {
      _fromController.text = widget.from?.name ?? '';
    }
    if (widget.to?.name != oldWidget.to?.name && !_toFocus.hasFocus) {
      _toController.text = widget.to?.name ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _overlayEntry?.remove();
    _fromFocus.removeListener(_handleFocusChange);
    _toFocus.removeListener(_handleFocusChange);
    _fromFocus.dispose();
    _toFocus.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_fromFocus.hasFocus) {
      setState(() {
        _activeField = _ActiveField.from;
        _inlineError = null;
      });
      _syncOverlay();
      return;
    }
    if (_toFocus.hasFocus) {
      setState(() {
        _activeField = _ActiveField.to;
        _inlineError = null;
      });
      _syncOverlay();
      return;
    }
    // Neither field has focus. Give a tap on a suggestion tile a moment to
    // register (tapping the overlay briefly steals focus) before tearing
    // the suggestions panel down.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || _fromFocus.hasFocus || _toFocus.hasFocus) return;
      setState(() {
        _activeField = _ActiveField.none;
        _suggestions = const [];
        _loadingSuggestions = false;
      });
      _syncOverlay();
    });
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _inlineError = null;
        _suggestions = const [];
        _loadingSuggestions = false;
      });
      _syncOverlay();
      return;
    }
    setState(() {
      _inlineError = null;
      _loadingSuggestions = true;
    });
    _syncOverlay();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(trimmed),
    );
  }

  /// Runs a search immediately for [field], bypassing the debounce - used
  /// by the search button/keyboard-submit so tapping it always feels
  /// responsive, instead of only reacting after the user pauses typing.
  void _searchNow(String query, _ActiveField field) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    setState(() {
      _activeField = field;
      _inlineError = null;
      _loadingSuggestions = true;
      _suggestions = const [];
    });
    _syncOverlay();
    _runSearch(trimmed);
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_requestId;
    // Rank POIs around the trip origin/current location, like a maps search
    // box, instead of returning equally named malls or restaurants in an
    // arbitrary nationwide order.
    final results = await _locationService.searchPlaces(
      query,
      bias: widget.from,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _suggestions = results;
      _loadingSuggestions = false;
    });
    _syncOverlay();
  }

  void _selectSuggestion(LocationPoint point) {
    final field = _activeField;
    if (field == _ActiveField.from) {
      if (point == widget.to) {
        setState(() => _inlineError = "That's already your destination.");
        _syncOverlay();
        return;
      }
      _fromController.text = point.name;
      widget.onFromSelected(point);
      _fromFocus.unfocus();
    } else if (field == _ActiveField.to) {
      if (point == widget.from) {
        setState(() => _inlineError = "That's already your starting point.");
        _syncOverlay();
        return;
      }
      _toController.text = point.name;
      widget.onToSelected(point);
      _toFocus.unfocus();
    }
    setState(() {
      _suggestions = const [];
      _loadingSuggestions = false;
    });
    _syncOverlay();
  }

  bool get _shouldShowPanel =>
      _activeField != _ActiveField.none &&
      (_loadingSuggestions || _suggestions.isNotEmpty || _inlineError != null);

  /// Inserts, rebuilds, or removes the floating suggestions overlay so it
  /// always reflects the latest state - without ever taking up space in
  /// this widget's own layout (see the class doc comment).
  void _syncOverlay() {
    if (!_shouldShowPanel) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      return;
    }
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 300.0;
    final height = renderBox?.size.height ?? 90.0;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, height + 6),
        child: Material(
          color: Colors.transparent,
          child: _SuggestionsPanel(
            loading: _loadingSuggestions,
            error: _inlineError,
            suggestions: _suggestions,
            onSelect: _selectSuggestion,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _cardKey,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _EditableLocationRow(
                    label: 'From',
                    color: AppColors.green,
                    controller: _fromController,
                    focusNode: _fromFocus,
                    hintText: widget.fromPlaceholder,
                    onChanged: _onQueryChanged,
                    onSearchPressed: () {
                      _fromFocus.requestFocus();
                      _searchNow(_fromController.text, _ActiveField.from);
                    },
                  ),
                  const Divider(height: 18, indent: 1, endIndent: 1),
                  _EditableLocationRow(
                    label: 'To',
                    color: AppColors.orange,
                    outlined: true,
                    controller: _toController,
                    focusNode: _toFocus,
                    hintText: 'Enter your destination',
                    onSearchPressed: () {
                      _toFocus.requestFocus();
                      _searchNow(_toController.text, _ActiveField.to);
                    },
                    onChanged: _onQueryChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: widget.onSwap,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.green,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableLocationRow extends StatelessWidget {
  const _EditableLocationRow({
    required this.label,
    required this.color,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onSearchPressed,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Runs a search for whatever is currently typed, right away - the
  /// button next to the field, and pressing the keyboard's search/enter
  /// key, both call this instead of waiting for the auto-search debounce.
  final VoidCallback onSearchPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          outlined ? Icons.location_on_outlined : Icons.circle,
          size: outlined ? 18 : 15,
          color: color,
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: (_) => onSearchPressed(),
            textInputAction: TextInputAction.search,
            onTap: () {
              // Select-all on tap, so starting to type replaces the whole
              // value rather than fiddling with a cursor mid-string.
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            maxLines: 1,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 20,
              ),
              suffixIcon: GestureDetector(
                onTap: onSearchPressed,
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.search,
                  size: 17,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The floating suggestions panel itself - styled to match the app's
/// existing "Recommended For You" tiles (pale-green rounded rows) rather
/// than a generic list, per the app's own design.
class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.loading,
    required this.error,
    required this.suggestions,
    required this.onSelect,
  });

  final bool loading;
  final String? error;
  final List<LocationPoint> suggestions;
  final ValueChanged<LocationPoint> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.green,
            ),
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: Text(
          'No matching places in Malaysia.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final place = suggestions[index];
        return _SuggestionTile(place: place, onTap: () => onSelect(place));
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.place, required this.onTap});

  final LocationPoint place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.paleGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.green,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.dateTime, required this.onTap});

  final DateTime dateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              formatFriendlyDateTime(dateTime),
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
