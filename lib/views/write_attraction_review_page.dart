import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import '../services/profanity_filter_service.dart';

/// Form for submitting a new [AttractionReview]. Runs
/// [ProfanityFilterService.check] on the text before saving - if flagged, a
/// warning dialog shows instead of posting.
class WriteAttractionReviewPage extends StatefulWidget {
  const WriteAttractionReviewPage({super.key, required this.attraction});

  final AttractionModel attraction;

  @override
  State<WriteAttractionReviewPage> createState() =>
      _WriteAttractionReviewPageState();
}

class _WriteAttractionReviewPageState
    extends State<WriteAttractionReviewPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE7F5E5);

  final TextEditingController _textController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    final result = await ProfanityFilterService.check(text);
    if (!mounted) return;

    if (result.errorMessage != null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
      return;
    }

    if (result.isFlagged) {
      setState(() => _submitting = false);
      _showResultDialog(success: false);
      return;
    }

    try {
      await AttractionReviewsService.instance.addReview(
        attractionId: widget.attraction.id,
        authorName: 'You',
        rating: _rating,
        text: text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _showResultDialog(success: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to save your review. Please try again.',
          ),
        ),
      );
    }
  }

  void _showResultDialog({required bool success}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        if (success) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (Navigator.canPop(dialogContext)) {
              Navigator.pop(dialogContext);
            }
            if (mounted) Navigator.pop(context);
          });
        }
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            height: success ? 150 : 190,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      success ? paleGreen : const Color(0xFFFCEFC7),
                  child: Icon(
                    success ? Icons.check : Icons.warning_amber_rounded,
                    color: success ? green : const Color(0xFFB8860B),
                    size: 28,
                  ),
                ),
                if (!success) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Sensitive Content Detected',
                    style: TextStyle(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please remove inappropriate language before posting.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Review ${widget.attraction.name}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Rating',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starIndex),
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Review',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your experience at ${widget.attraction.name}...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E5DF)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Checking...' : 'Post Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
