import 'package:flutter/material.dart';
import 'package:tedlist_flutter/services/vision_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublishItemScreen extends ConsumerStatefulWidget {
  const PublishItemScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PublishItemScreen> createState() => _PublishItemScreenState();
}

class _PublishItemScreenState extends ConsumerState<PublishItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  
  File? _selectedImage;
  String _category = 'Other';
  String _condition = 'Good';
  List<String> _keywords = [];
  bool _isAnalyzing = false;
  String _loadingMessage = "Teaching AI to appreciate your item's beauty...";
  Timer? _loadingMessageTimer;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _estimatedValueController.dispose();
    _loadingMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    final visionService = ref.read(visionServiceProvider);
    debugPrint('Starting image analysis...');
    
    setState(() {
      _isAnalyzing = true;
      _loadingMessage = visionService.getNextLoadingMessage();
    });
    debugPrint('Initial loading message: $_loadingMessage');

    // Start a timer to update the loading message every 2 seconds
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isAnalyzing && mounted) {
        setState(() {
          _loadingMessage = visionService.getNextLoadingMessage();
        });
        debugPrint('Updated loading message: $_loadingMessage');
      } else {
        timer.cancel();
      }
    });

    try {
      final result = await visionService.analyzeImage(_selectedImage!);
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _category = data['category'] ?? 'Other';
          _condition = data['condition'] ?? 'Good';
          _brandController.text = data['brand'] ?? '';
          _estimatedValueController.text = data['estimatedValue'] ?? '';
          if (data['keywords'] != null) {
            _keywords = List<String>.from(data['keywords']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        debugPrint('Analysis complete, isAnalyzing: $_isAnalyzing');
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.all(32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _loadingMessage,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building screen, isAnalyzing: $_isAnalyzing, message: $_loadingMessage');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Item'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Selection
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Icon(Icons.add_photo_alternate, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Auto-Generate Button
                  if (_selectedImage != null)
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeImage,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Auto-Generate Details with AI'),
                    ),
                  const SizedBox(height: 16),

                  // Form Fields
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a description' : null,
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Electronics',
                      'Clothing',
                      'Furniture',
                      'Kitchen',
                      'Books',
                      'Toys',
                      'Sports',
                      'Home Decor',
                      'Other'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _category = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Condition Dropdown
                  DropdownButtonFormField<String>(
                    value: _condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'New',
                      'Like New',
                      'Good',
                      'Fair',
                      'Poor'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _condition = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _estimatedValueController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Value (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // TODO: Implement item submission
                      }
                    },
                    child: const Text('Publish Item'),
                  ),
                ],
              ),
            ),
          ),
          if (_isAnalyzing) _buildLoadingOverlay(),
        ],
      ),
    );
  }
} 