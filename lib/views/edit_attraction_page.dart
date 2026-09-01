import 'package:flutter/material.dart';

import '../models/attraction.dart';
import 'attraction_form_page.dart';

class EditAttractionPage extends StatelessWidget {
  final AttractionModel attraction;

  const EditAttractionPage({
    super.key,
    required this.attraction,
  });

  @override
  Widget build(BuildContext context) {
    return AttractionFormPage(attraction: attraction);
  }
}
