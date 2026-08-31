import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class LocationRow extends StatelessWidget {
  const LocationRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final String value;
  final Color color;
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
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
