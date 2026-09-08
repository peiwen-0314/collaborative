import 'package:flutter/foundation.dart';

import '../models/google_place.dart';
import '../services/google_places_service.dart';

class GooglePlacesController extends ChangeNotifier {
  final GooglePlacesService _service = GooglePlacesService();

  List<GooglePlace> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<GooglePlace> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> searchPlaces(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _results = [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _service.searchPlaces(
        '$trimmed Malaysia',
      );
    } catch (e) {
      _results = [];
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _results = [];
    _errorMessage = null;
    notifyListeners();
  }
}