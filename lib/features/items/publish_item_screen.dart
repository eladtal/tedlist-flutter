import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/vision_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublishItemScreen extends ConsumerStatefulWidget {
  const PublishItemScreen({super.key});

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) return;
    setState(() => _isAnalyzing = true);
    try {
      // 1. Upload image to backend (which uploads to S3)
      final url = await ApiService().uploadImage(_selectedImage!);
      // 2. Submit item details to backend
      await ApiService().createItem({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'condition': _condition,
        'images': [url],
        'brand': _brandController.text.trim(),
        'estimatedValue': _estimatedValueController.text.trim(),
        'keywords': _keywords,
      });
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item published!')),
      );
      
      // Use GoRouter to navigate back to home
      if (!mounted) return;
      context.go('/');
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publish Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _estimatedValueController,
                decoration: const InputDecoration(labelText: 'Estimated Value'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  DropdownMenuItem<String>(value: 'Electronics', child: Text('Electronics')),
                  DropdownMenuItem<String>(value: 'Furniture', child: Text('Furniture')),
                  DropdownMenuItem<String>(value: 'Clothing', child: Text('Clothing')),
                  DropdownMenuItem<String>(value: 'Books', child: Text('Books')),
                  DropdownMenuItem<String>(value: 'Sports', child: Text('Sports')),
                  DropdownMenuItem<String>(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _condition,
                items: const [
                  DropdownMenuItem<String>(value: 'New', child: Text('New')),
                  DropdownMenuItem<String>(value: 'Like New', child: Text('Like New')),
                  DropdownMenuItem<String>(value: 'Good', child: Text('Good')),
                  DropdownMenuItem<String>(value: 'Fair', child: Text('Fair')),
                  DropdownMenuItem<String>(value: 'Poor', child: Text('Poor')),
                ],
                onChanged: (v) => setState(() => _condition = v ?? 'Good'),
                decoration: const InputDecoration(labelText: 'Condition'),
                validator: (v) => v == null ? 'Select a condition' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Image'),
              ),
              const SizedBox(height: 12),
              if (_selectedImage != null)
                Image.file(_selectedImage!, height: 200, fit: BoxFit.cover),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeImage,
                child: _isAnalyzing 
                    ? const CircularProgressIndicator()
                    : const Text('Analyze Image'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isAnalyzing ? null : _submit,
                child: _isAnalyzing ? const CircularProgressIndicator() : const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 