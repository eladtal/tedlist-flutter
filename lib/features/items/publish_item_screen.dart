import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class PublishItemScreen extends StatefulWidget {
  const PublishItemScreen({super.key});

  @override
  State<PublishItemScreen> createState() => _PublishItemScreenState();
}

class _PublishItemScreenState extends State<PublishItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _category;
  String? _condition;
  List<XFile> _images = [];
  bool _isLoading = false;
  final _picker = ImagePicker();

  final List<String> _categories = [
    'Electronics', 'Furniture', 'Clothing', 'Books', 'Sports', 'Other'
  ];
  final List<String> _conditions = [
    'New', 'Like New', 'Good', 'Fair', 'Poor'
  ];

  Future<void> _pickImage() async {
    if (_images.length >= 3) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _images.add(picked));
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 3) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      setState(() => _images.add(picked));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _images.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // TODO(elad) – Integrate OpenAI for image recognition and description [2025-05-04]
      // 1. Upload images to backend (which uploads to S3)
      List<String> imageUrls = [];
      for (final img in _images) {
        final url = await ApiService().uploadImage(File(img.path));
        imageUrls.add(url);
      }
      // 2. Submit item details to backend
      await ApiService().createItem({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _category,
        'condition': _condition,
        'images': imageUrls,
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
      if (mounted) setState(() => _isLoading = false);
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
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v),
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _condition,
                items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _condition = v),
                decoration: const InputDecoration(labelText: 'Condition'),
                validator: (v) => v == null ? 'Select a condition' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, i) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Image.file(File(_images[i].path), width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: const CircleAvatar(radius: 12, child: Icon(Icons.close, size: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 