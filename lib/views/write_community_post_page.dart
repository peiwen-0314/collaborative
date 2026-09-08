import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/community_feed_service.dart';
import '../services/review_moderation_service.dart';

/// Form for creating a new community post. Runs the same
/// API moderation used by attraction reviews before saving.
class WriteCommunityPostPage extends StatefulWidget {
  const WriteCommunityPostPage({
    super.key,
    required this.availableTags,
  });

  final List<String> availableTags;

  @override
  State<WriteCommunityPostPage> createState() => _WriteCommunityPostPageState();
}

class _WriteCommunityPostPageState extends State<WriteCommunityPostPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE7F5E5);

  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<Uint8List> _images = [];
  final List<String> _selectedTags = [];
  bool _submitting = false;
  bool _pickingImages = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pickingImages || _images.length >= 5) return;

    setState(() => _pickingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted || picked.isEmpty) return;

      final remaining = 5 - _images.length;
      final selected = picked.take(remaining);
      final bytes = <Uint8List>[];
      for (final image in selected) {
        bytes.add(await image.readAsBytes());
      }
      if (mounted) setState(() => _images.addAll(bytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the photo gallery.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();

    if (text.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);

    try {
      // =====================================================
      // 1. API CONTENT MODERATION
      // Uses the same Firebase Cloud Function / Google
      // moderation service as attraction reviews.
      // =====================================================
      final moderationResult =
      await ReviewModerationService.instance.moderate(text);

      if (!mounted) return;

      if (!moderationResult.allowed) {
        setState(() => _submitting = false);

        final isContentRejected =
            moderationResult.source == 'google-moderation';

        if (isContentRejected) {
          _showResultDialog(success: false);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  moderationResult.message.isNotEmpty
                      ? moderationResult.message
                      : 'Unable to check the post right now. Please try again.',
                ),
              ),
            );
        }

        return;
      }

      // =====================================================
      // 2. MODERATION PASSED -> SAVE POST
      // =====================================================
      await CommunityFeedService.instance.addPost(
        authorName: 'You',
        text: text,
        images: List.unmodifiable(_images),
        tags: List.unmodifiable(_selectedTags),
      );

      if (!mounted) return;

      setState(() => _submitting = false);
      _showResultDialog(success: true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Unable to upload your post. Please try again.',
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
                  backgroundColor: success ? paleGreen : const Color(0xFFFCEFC7),
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
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE1E5DF)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${_images.length}/5',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + (_images.length < 5 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
                      return InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 92,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: green),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_pickingImages)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: green,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: green,
                                  size: 28,
                                ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add photos',
                                style: TextStyle(
                                  color: green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _images[index],
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() => _images.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Post topics',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedTags.length}/3',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    selectedColor: const Color(0xFFE8F5E9),
                    checkmarkColor: green,
                    side: const BorderSide(color: green),
                    labelStyle: const TextStyle(color: green, fontSize: 12),
                    onSelected: (value) {
                      if (value && _selectedTags.length >= 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You can select up to 3 topics.'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        if (value) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Checking...' : 'Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
